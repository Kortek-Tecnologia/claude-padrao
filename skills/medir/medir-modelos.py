#!/usr/bin/env python3
"""Mede se a política de modelos (regras do plugin padrao) pegou na prática.

O hook só corrige Explore/Plan e recusa `model` fora da política; ele não vê o
agente principal deixar de delegar, que é a falha cara (coleta e execução pagando
preço de Opus). Isto lê os transcripts locais do Claude Code do projeto e conta:

- chamadas de subagent por tipo × modelo (haiku em zero = coleta não delegada);
- recusas do hook de modelo;
- turnos por modelo, do agente principal e dos subagents;
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


def pasta_do_projeto(raiz: Path) -> str:
    """Nome da pasta em ~/.claude/projects: todo caractere não alfanumérico do
    caminho vira "-" (C:/Users/x → C--Users-x; /home/x/meu.proj → -home-x-meu-proj)."""
    return re.sub(r"[^A-Za-z0-9]", "-", str(raiz))


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
    pasta = Path.home() / ".claude" / "projects" / pasta_do_projeto(raiz)
    if not pasta.is_dir():
        raise SystemExit(f"sem transcripts em {pasta}")

    chamadas: dict[str, Counter[str]] = defaultdict(Counter)
    turnos_principal: Counter[str] = Counter()
    turnos_sub: Counter[str] = Counter()
    recusas = sessoes = sem_delegar = 0

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
            if msg.get("model"):
                turnos_principal[msg["model"]] += 1
            for c in msg.get("content") or []:
                if (
                    isinstance(c, dict)
                    and c.get("type") == "tool_use"
                    and c.get("name") in ("Agent", "Task")
                ):
                    i = c.get("input") or {}
                    tipo = i.get("subagent_type", "general-purpose")
                    # Agente de plugin (padrao:coletor…) traz `model:` no frontmatter.
                    sem = "(frontmatter)" if ":" in tipo else "(sem model)"
                    chamadas[tipo][i.get("model") or sem] += 1
                    ids_agent.add(c.get("id"))
                    delegou = True
        sessoes += ativa
        sem_delegar += ativa and not delegou

    for arq in pasta.glob("*/subagents/*.jsonl"):
        for o, _ in linhas(arq, desde):
            msg = o.get("message")
            if o.get("type") == "assistant" and isinstance(msg, dict) and msg.get("model"):
                turnos_sub[msg["model"]] += 1

    print(f"últimos {dias} dias · {sessoes} sessão(ões) · {sem_delegar} sem nenhuma delegação")
    print(f"recusas do hook de modelo: {recusas}")
    total: Counter[str] = Counter()
    print("subagents (tipo: modelo × chamadas):")
    for tipo, por_modelo in sorted(chamadas.items()):
        total.update(por_modelo)
        print(f"  {tipo:<20} " + "  ".join(f"{m}={n}" for m, n in por_modelo.most_common()))
    print("  total                " + "  ".join(f"{m}={n}" for m, n in total.most_common()))
    print(
        "turnos do agente principal: "
        + "  ".join(f"{m}={n}" for m, n in turnos_principal.most_common())
    )
    print(
        "turnos dos subagents:       " + "  ".join(f"{m}={n}" for m, n in turnos_sub.most_common())
    )


if __name__ == "__main__":
    main()
