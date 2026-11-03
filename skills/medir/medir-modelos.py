#!/usr/bin/env python3
"""Mede se a política de modelos (regras do plugin padrao) pegou na prática.

O hook só corrige os agentes de papel fixo e recusa `model` fora da política;
ele não vê o agente principal deixar de delegar, que é a falha cara (coleta e
execução pagando preço de Opus). Isto lê os transcripts locais do Claude Code do
projeto e conta:

- chamadas de subagent por tipo × modelo em que rodou (haiku em zero = coleta
  não delegada);
- correções (papel fixo) e recusas do hook de modelo;
- tokens e turnos por modelo, do agente principal e dos subagents;
- sessões sem nenhuma delegação (preocupa só a sessão longa).

    sh <plugin>/scripts/py.sh <dir da skill>/medir-modelos.py [--dias N] [--projeto P]

O projeto é o diretório corrente, ou o dado em --projeto. Padrão: 14 dias (o
cleanupPeriodDays do padrão: transcripts mais velhos já foram apagados).

⚠️ Os transcripts moram em ~/.claude/projects/ da MÁQUINA onde as sessões
rodaram: o número é desta máquina, não do time.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path


# Textos de recusa do hook de modelo: os atuais e os de versões anteriores.
RECUSA = ("fora da politica", "roda em model=", "Subagent sem modelo", "e travado em model=")

# Papel fixo, como o hook de modelo aplica: Plan e Explore sempre vão para este
# modelo; os agentes do plugin, só quando a chamada traz outro `model` (sem ele
# vale o frontmatter, que já é este).
FIXO = {
    "Plan": "opus",
    "Explore": "haiku",
    "padrao:coletor": "haiku",
    "padrao:leitor": "haiku",
    "padrao:revisor": "sonnet",
    "padrao:executor": "sonnet",
}


def chave_projeto(caminho: str) -> str:
    """Nome da pasta em ~/.claude/projects: todo caractere não alfanumérico do
    caminho vira "-" (C:/Users/x → C--Users-x; /home/x/meu.proj → -home-x-meu-proj)."""
    return re.sub(r"[^A-Za-z0-9]", "-", caminho)


def modelo_efetivo(tipo: str, pedido: str) -> tuple[str, bool]:
    """(modelo em que o subagent rodou, se o hook corrigiu a chamada)."""
    exigido = FIXO.get(tipo)
    if exigido:
        return exigido, pedido != exigido and (bool(pedido) or ":" not in tipo)
    if tipo == "fork":
        return "(sessão)", False
    if pedido:
        return pedido, False
    # Sem `model`: o general-purpose cai no CLAUDE_CODE_SUBAGENT_MODEL do padrão;
    # agente de plugin usa o frontmatter; outro agente (embutido ou do projeto),
    # o modelo da própria definição, se ela fixar um.
    if tipo == "general-purpose":
        return "sonnet (env)", False
    return ("(frontmatter)" if ":" in tipo else "(sem model)"), False


def turno_novo(o: dict, vistos: set[str]) -> bool:
    """O transcript grava cada bloco da resposta (thinking, texto, tool_use) numa
    linha com o mesmo message.id: conta a resposta uma vez só."""
    mid = (o.get("message") or {}).get("id")
    if not mid:
        return True
    if mid in vistos:
        return False
    vistos.add(mid)
    return True


def guardar_uso(usos: dict, msg: dict) -> None:
    """Uso de tokens por resposta: as linhas de um mesmo message.id repetem o uso,
    e a última traz o final — guarda por id, sobrescrevendo."""
    uso = msg.get("usage")
    if isinstance(uso, dict) and msg.get("model"):
        usos[msg.get("id") or f"sem-id-{len(usos)}"] = (msg["model"], uso)


def somar_uso(usos: dict) -> dict[str, Counter[str]]:
    por_modelo: dict[str, Counter[str]] = defaultdict(Counter)
    for modelo, uso in usos.values():
        c = por_modelo[modelo]
        c["entrada"] += (uso.get("input_tokens") or 0) + (uso.get("cache_creation_input_tokens") or 0)
        c["cache lido"] += uso.get("cache_read_input_tokens") or 0
        c["saída"] += uso.get("output_tokens") or 0
    return por_modelo


def fmt(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    return f"{n / 1000:.0f}k" if n >= 1000 else str(n)


def linhas(arquivo: Path, desde: str):
    with arquivo.open(encoding="utf-8", errors="ignore") as f:
        for bruta in f:
            try:
                o = json.loads(bruta)
            except ValueError:
                continue
            if (o.get("timestamp") or "") >= desde:
                yield o, bruta


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dias", type=int, default=14)
    ap.add_argument("--projeto", type=Path, default=None)
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")  # console do Windows não é UTF-8
    dias = args.dias
    raiz = (args.projeto or Path.cwd()).resolve()
    desde = (datetime.now(timezone.utc) - timedelta(days=dias)).strftime("%Y-%m-%dT%H:%M:%S")
    pasta = Path.home() / ".claude" / "projects" / chave_projeto(str(raiz))
    if not pasta.is_dir():
        raise SystemExit(f"sem transcripts em {pasta}")

    chamadas: dict[str, Counter[str]] = defaultdict(Counter)
    corrigidas: Counter[str] = Counter()
    turnos_principal: Counter[str] = Counter()
    turnos_sub: Counter[str] = Counter()
    uso_principal: dict = {}
    uso_sub: dict = {}
    recusas = sessoes = sem_delegar = 0
    vistos: set[str] = set()

    for arq in pasta.glob("*.jsonl"):
        delegou = ativa = False
        ids_agent: set[str] = set()
        for o, _ in linhas(arq, desde):
            ativa = True
            msg = o.get("message")
            if o.get("type") == "user" and isinstance(msg, dict):
                # Recusa = resultado de uma chamada Agent com o texto do hook. Só o
                # resultado do Agent: o texto também aparece em leitura do script.
                for c in msg.get("content") or []:
                    if (
                        isinstance(c, dict)
                        and c.get("type") == "tool_result"
                        and c.get("tool_use_id") in ids_agent
                        and any(m in json.dumps(c.get("content"), ensure_ascii=False) for m in RECUSA)
                    ):
                        recusas += 1
            if o.get("type") != "assistant" or not isinstance(msg, dict):
                continue
            guardar_uso(uso_principal, msg)
            if msg.get("model") and turno_novo(o, vistos):
                turnos_principal[msg["model"]] += 1
            for c in msg.get("content") or []:
                if (
                    isinstance(c, dict)
                    and c.get("type") == "tool_use"
                    and c.get("name") in ("Agent", "Task")
                ):
                    i = c.get("input") or {}
                    tipo = i.get("subagent_type") or "general-purpose"
                    modelo, corrigida = modelo_efetivo(tipo, i.get("model") or "")
                    chamadas[tipo][modelo] += 1
                    corrigidas[tipo] += corrigida
                    ids_agent.add(c.get("id"))
                    delegou = True
        sessoes += ativa
        sem_delegar += ativa and not delegou

    for arq in pasta.glob("*/subagents/*.jsonl"):
        for o, _ in linhas(arq, desde):
            msg = o.get("message")
            if o.get("type") == "assistant" and isinstance(msg, dict):
                guardar_uso(uso_sub, msg)
                if msg.get("model") and turno_novo(o, vistos):
                    turnos_sub[msg["model"]] += 1

    print(f"últimos {dias} dias · {sessoes} sessão(ões) · {sem_delegar} sem nenhuma delegação")
    correcoes = "  ".join(f"{t}={n}" for t, n in corrigidas.most_common() if n)
    print(f"hook de modelo: {sum(corrigidas.values())} correção(ões) de papel fixo"
          + (f" ({correcoes})" if correcoes else "") + f" · {recusas} recusa(s)")
    total: Counter[str] = Counter()
    print("subagents (tipo: modelo em que rodou × chamadas):")
    for tipo, por_modelo in sorted(chamadas.items()):
        total.update(por_modelo)
        print(f"  {tipo:<20} " + "  ".join(f"{m}={n}" for m, n in por_modelo.most_common()))
    print("  total                " + "  ".join(f"{m}={n}" for m, n in total.most_common()))
    print("tokens por modelo (entrada · cache lido · saída):")
    for rotulo, usos in (("principal", uso_principal), ("subagents", uso_sub)):
        for modelo, c in sorted(somar_uso(usos).items(), key=lambda kv: -sum(kv[1].values())):
            print(f"  {rotulo:<10} {modelo:<22} {fmt(c['entrada'])} · {fmt(c['cache lido'])} · {fmt(c['saída'])}")
    print(
        "turnos do agente principal: "
        + "  ".join(f"{m}={n}" for m, n in turnos_principal.most_common())
    )
    print(
        "turnos dos subagents:       " + "  ".join(f"{m}={n}" for m, n in turnos_sub.most_common())
    )


if __name__ == "__main__":
    main()
