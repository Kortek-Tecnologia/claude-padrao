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
- sessões sem nenhuma delegação (preocupa só a sessão longa);
- commits da sessão principal: quantos tiveram verificação desde o commit anterior
  (teste ou build rodado na sessão, `padrao:revisor`, lote pelo `padrao:executor`) e
  quantos saíram sem nenhuma — só mede, não há hook cobrando;
- commits da sessão principal: quantos tiveram a `padrao:atualizar-docs` antes e
  quantas vezes o hook da documentação precisou lembrar;
- custo estimado a preço de lista por modelo, o contexto por requisição da
  sessão principal (o que mais pesa) e as requisições do Haiku acima de 100K;
- consultas ao advisor (/padrao:advisor) e o custo do modelo consultado, que
  não aparece no uso da mensagem do modelo da sessão;
- chamadas de subagent que trouxeram `effort` (o hook de modelo não olha esse
  campo: a linha só aparece se houve alguma).

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

# Recusa do hook da documentação (cobrar-docs.sh): o commit tentado sem a skill.
LEMBRETE = "antes deste commit, rode a skill"

# Comando que faz commit, pela regra do cobrar-docs.sh (lá em sh, por segmento; aqui
# aproximada): somem os heredocs fechados e o conteúdo das aspas (mensagem que cita o
# comando) e casa um segmento que começa por `git`, opções globais (`-C dir`, `-c k=v`,
# `--no-pager`) e `commit`.
HEREDOC = re.compile(r"<<-?\s*['\"]?(\w+)['\"]?.*?\n\t*\1\b", re.S)
ASPAS = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"", re.S)
ARG = r"(?:[^\s\"']|\"[^\"]*\"|'[^']*')+"
COMMIT = re.compile(
    r"(?:^|[;&|(){}\n`]|\$\()\s*(?:(?:then|do|else|time|command|exec|env|sudo)\s+|[A-Za-z_]\w*=\S*\s+)*"
    r"(?:[^\s\"']*[/\\])?git(?:\.exe)?"
    r"(?:\s+(?:-[Cc]\s+" + ARG + r"|--?[A-Za-z][A-Za-z-]*(?:=" + ARG + r")?))*\s+commit(?=[\s;&|)]|$)"
)
# Mensagem de lote do /padrao:arrumar: `-m "arrumar: lote …"` ou a 1ª linha do heredoc.
LOTE = re.compile(r"-m\s*[\"']arrumar: lote |-m\s*\"\$\(cat\s*<<[^\n]*\n\s*arrumar: lote ")


# Comando que verifica: roda teste, build, checagem de tipos ou lint. Heurística pelos
# nomes comuns, fora de aspas e de heredoc; script do projeto com outro nome não entra
# (a conta de "sem nenhuma" sai para mais).
VERIFICA = re.compile(
    # no começo de um segmento do comando (como no COMMIT): `echo npm test`, `cat testar.sh`
    # e `grep pytest` não contam. Na frente podem vir atribuições, um lançador e um caminho.
    r"(?:^|[;&|(){}\n`]|\$\()\s*"
    r"(?:(?:time|env|sudo|npx|bunx|uvx|bash|sh|uv\s+run|poetry\s+run|pipenv\s+run|py(?:thon[\d.]*)?\s+-m"
    r"|timeout(?:\s+-\S+)*\s+\S+)\s+"
    r"|[A-Za-z_]\w*=\S*\s+)*"
    r"(?:[^\s\"']*[/\\])?(?:"
    r"pytest|unittest|tox|nox|ruff|mypy|pyright|"
    r"jest|vitest|playwright|cypress|tsc|eslint|oxlint|biome|"
    r"(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?(?:test|build|lint|typecheck|check)[\w:-]*|deno\s+test|"
    r"go\s+(?:test|build|vet)|cargo\s+(?:test|build|check|clippy)|"
    r"(?:mvn|gradle|gradlew)\s+[\w:-]*(?:test|build|check|verify)|dotnet\s+(?:test|build)|"
    r"make\s+(?:test|check|build|lint)|phpunit|rspec|"
    r"testar\.sh|tests?\.sh|run-tests[\w.-]*|claude\s+plugin\s+(?:validate|test)"
    r")(?=[\s;&|)]|$)"
)


def verifica(comando: str) -> bool:
    """O comando roda teste, build, checagem de tipos ou lint."""
    return bool(VERIFICA.search(ASPAS.sub("''", HEREDOC.sub(" ", comando))))


def faz_commit(comando: str) -> bool:
    """Commit que o hook cobra: os lotes do /padrao:arrumar ficam fora, como lá."""
    commits = len(COMMIT.findall(ASPAS.sub("''", HEREDOC.sub(" ", comando))))
    return commits > len(LOTE.findall(comando))


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


# Preço de lista em US$ por milhão de tokens: (entrada, escrita de cache 5 min,
# escrita de cache 1 h, cache lido, saída). O modelo casa por prefixo do nome.
# Fonte: tabela de modelos da skill claude-api do Claude Code, com a data abaixo
# (entrada, saída, cache lido e a faixa do Haiku acima de 100K conferidos em
# 2026-11-17; a escrita de cache é 1,25× e 2× a entrada, não conferida ali).
# Mudou o preço: mude a tabela e a data — ela sai no cabeçalho do custo.
PRECO_EM = "2026-11-03"
PRECO = {
    "claude-opus-5-5": (4, 5, 8, 0.20, 20),
    "claude-sonnet-5-5": (2, 2.5, 4, 0.10, 10),
    "claude-fable-5-2": (8, 10, 16, 0.20, 40),
    "claude-mythos-5-2": (8, 10, 16, 0.20, 40),
    "claude-haiku-5-5": (0.10, 0.125, 0.20, 0.01, 0.50),
}
# Haiku: requisição com contexto acima disto paga toda ela o preço alto.
HAIKU = "claude-haiku-5-5"
HAIKU_LIMITE = 100_000
HAIKU_ALTO = (0.50, 0.625, 1.00, 0.05, 2.50)
# Faixas de contexto da sessão principal: (nome, limite superior inclusivo).
FAIXAS = (
    ("até 100K", 100_000),
    ("100–200K", 200_000),
    ("200–400K", 400_000),
    ("400–600K", 600_000),
    ("acima de 600K", float("inf")),
)


def prefixo_preco(modelo: str) -> str | None:
    return next((p for p in PRECO if modelo.startswith(p)), None)


def requisicao(uso: dict) -> tuple[int, tuple[int, int, int, int, int]]:
    """(contexto, tokens na ordem do PRECO) de uma resposta."""
    entrada = uso.get("input_tokens") or 0
    lido = uso.get("cache_read_input_tokens") or 0
    escrita = uso.get("cache_creation_input_tokens") or 0
    uma_hora = min(escrita, (uso.get("cache_creation") or {}).get("ephemeral_1h_input_tokens") or 0)
    saida = uso.get("output_tokens") or 0
    return entrada + lido + escrita, (entrada, escrita - uma_hora, uma_hora, lido, saida)


def valor(tokens: tuple, preco: tuple) -> float:
    return sum(t * p for t, p in zip(tokens, preco)) / 1_000_000


def chave_projeto(caminho: str) -> str:
    """Nome da pasta em ~/.claude/projects: todo caractere não alfanumérico do
    caminho vira "-" (C:/Users/x → C--Users-x; /home/x/meu.proj → -home-x-meu-proj)."""
    return re.sub(r"[^A-Za-z0-9]", "-", caminho)


def caminho_longo(p: Path) -> Path:
    """No Windows, caminho com mais de 260 caracteres só abre com o prefixo `\\\\?\\`
    (o `LongPathsEnabled` vem desligado). Os transcripts moram em
    ~/.claude/projects/<caminho do projeto>/<sessão>/subagents/: projeto em pasta
    funda passa do limite, e sem o prefixo a pasta "não existe"."""
    texto = str(p)
    if sys.platform != "win32" or texto.startswith("\\\\"):
        return p
    return Path("\\\\?\\" + texto)


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


# Mensagem que o próprio Claude Code grava, sem requisição a modelo: aviso de erro
# e, no Code Mode, cada chamada de ferramenta feita de dentro do código (o
# `tool_use` dela conta para commits e subagents; tokens e turnos, não).
SINTETICO = "<synthetic>"


def de_modelo(msg: dict) -> bool:
    return bool(msg.get("model")) and msg["model"] != SINTETICO


def guardar_uso(usos: dict, msg: dict) -> None:
    """Uso de tokens por resposta: as linhas de um mesmo message.id repetem o uso,
    e a última traz o final — guarda por id, sobrescrevendo."""
    uso = msg.get("usage")
    if isinstance(uso, dict) and de_modelo(msg):
        usos[msg.get("id") or f"sem-id-{len(usos)}"] = (msg["model"], uso)


def guardar_advisor(usos: dict, msg: dict) -> None:
    """Consultas ao advisor. Os tokens do modelo consultado ficam fora do uso de
    topo da mensagem: vêm em `usage.iterations`, uma entrada `advisor_message`
    por consulta, com o modelo dela (a leitura da conversa por ele não usa cache).
    Guarda por id da mensagem e posição: as linhas de um mesmo id repetem o uso."""
    uso = msg.get("usage")
    iteracoes = uso.get("iterations") if isinstance(uso, dict) else None
    for i, it in enumerate(iteracoes if isinstance(iteracoes, list) else []):
        if isinstance(it, dict) and it.get("type") == "advisor_message":
            usos[f"{msg.get('id')}#{i}"] = (it.get("model") or "advisor", it)


def somar_uso(usos: dict) -> dict[str, Counter[str]]:
    por_modelo: dict[str, Counter[str]] = defaultdict(Counter)
    for modelo, uso in usos.values():
        c = por_modelo[modelo]
        c["entrada"] += (uso.get("input_tokens") or 0) + (uso.get("cache_creation_input_tokens") or 0)
        c["cache lido"] += uso.get("cache_read_input_tokens") or 0
        c["saída"] += uso.get("output_tokens") or 0
    return por_modelo


def imprimir_custo(uso_principal: dict, uso_sub: dict, uso_advisor: dict) -> None:
    """Custo a preço de lista, contexto da sessão principal e Haiku acima de 100K.
    Uma requisição = um message.id (o uso guardado já é o final de cada um); do
    advisor, uma consulta."""
    custo = {"principal": Counter(), "subagents": Counter(), "advisor": Counter()}
    faixa_n: Counter[str] = Counter()
    faixa_custo: Counter[str] = Counter()
    sem_preco: Counter[str] = Counter()
    haiku = haiku_alto = 0
    sobrepreco = 0.0
    for rotulo, usos in (("principal", uso_principal), ("subagents", uso_sub), ("advisor", uso_advisor)):
        for modelo, uso in usos.values():
            prefixo = prefixo_preco(modelo)
            if prefixo is None:
                sem_preco[modelo] += 1
                continue
            contexto, tokens = requisicao(uso)
            preco = PRECO[prefixo]
            if prefixo == HAIKU:
                haiku += 1
                if contexto > HAIKU_LIMITE:
                    haiku_alto += 1
                    sobrepreco += valor(tokens, HAIKU_ALTO) - valor(tokens, preco)
                    preco = HAIKU_ALTO
            v = valor(tokens, preco)
            custo[rotulo][modelo] += v
            if rotulo == "principal":
                faixa = next(nome for nome, teto in FAIXAS if contexto <= teto)
                faixa_n[faixa] += 1
                faixa_custo[faixa] += v
    print(f"custo estimado a preço de lista de {PRECO_EM} (em assinatura é peso relativo, não cobrança):")
    for rotulo, por_modelo in custo.items():
        for modelo, v in sorted(por_modelo.items(), key=lambda kv: -kv[1]):
            print(f"  {rotulo:<10} {modelo:<22} US$ {v:.2f}")
    principal = sum(custo["principal"].values())
    sub = sum(custo["subagents"].values())
    advisor = sum(custo["advisor"].values())
    total = principal + sub + advisor
    print(f"  total      US$ {total:.2f} · subagents {(sub / total if total else 0):.0%}"
          + (f" · advisor {advisor / total:.0%}" if advisor else ""))
    print("contexto por requisição da sessão principal (requisições · % do custo dela):")
    for nome, _ in FAIXAS:
        parte = faixa_custo[nome] / principal if principal else 0
        print(f"  {nome:<17}{faixa_n[nome]} · {parte:.0%}")
    print(f"Haiku acima de 100K: {haiku_alto} de {haiku} requisições · sobrepreço US$ {sobrepreco:.2f}")
    if sem_preco:
        print("sem preço na tabela (fora da conta): "
              + ", ".join(f"{m}={n}" for m, n in sem_preco.most_common()))


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
    curta = Path.home() / ".claude" / "projects" / chave_projeto(str(raiz))
    pasta = caminho_longo(curta)
    if not pasta.is_dir():
        raise SystemExit(f"sem transcripts em {curta}")

    chamadas: dict[str, Counter[str]] = defaultdict(Counter)
    corrigidas: Counter[str] = Counter()
    com_effort: Counter[str] = Counter()
    turnos_principal: Counter[str] = Counter()
    turnos_sub: Counter[str] = Counter()
    uso_principal: dict = {}
    uso_sub: dict = {}
    uso_advisor: dict = {}
    recusas = sessoes = sem_delegar = 0
    commits = com_docs = lembretes = 0
    # verificação antes do commit: [teste ou build, revisor, executor] e os sem nenhuma
    com_verif = [0, 0, 0]
    sem_verif = 0
    vistos: set[str] = set()

    for arq in pasta.glob("*.jsonl"):
        delegou = ativa = False
        # id da chamada Agent → (tipo, modelo), para tirar da conta a que foi recusada
        ids_agent: dict[str, tuple[str, str]] = {}
        # id do commit → (se a atualizar-docs rodou desde o commit anterior, a verificação
        # vista desde o commit anterior: teste ou build, revisor, executor)
        ids_commit: dict[str, tuple[bool, tuple[bool, bool, bool]]] = {}
        docs_antes = False
        verif = [False, False, False]
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
                        and c.get("tool_use_id") in ids_commit
                        and LEMBRETE in json.dumps(c.get("content"), ensure_ascii=False)
                    ):
                        # o hook recusou: a tentativa não é commit
                        lembretes += 1
                        commits -= 1
                        teve_docs, vista = ids_commit.pop(c["tool_use_id"])
                        com_docs -= teve_docs
                        # a verificação vista vale para a repetição do commit
                        for k in range(3):
                            com_verif[k] -= vista[k]
                            verif[k] = verif[k] or vista[k]
                        sem_verif -= not any(vista)
                    if (
                        isinstance(c, dict)
                        and c.get("type") == "tool_result"
                        and c.get("tool_use_id") in ids_agent
                        and any(m in json.dumps(c.get("content"), ensure_ascii=False) for m in RECUSA)
                    ):
                        recusas += 1
                        tipo, modelo = ids_agent[c["tool_use_id"]]
                        chamadas[tipo][modelo] -= 1
                        chamadas[tipo][f"{modelo} (recusada)"] += 1
            if o.get("type") != "assistant" or not isinstance(msg, dict):
                continue
            guardar_uso(uso_principal, msg)
            guardar_advisor(uso_advisor, msg)
            if de_modelo(msg) and turno_novo(o, vistos):
                turnos_principal[msg["model"]] += 1
            for c in msg.get("content") or []:
                if not isinstance(c, dict) or c.get("type") != "tool_use":
                    continue
                i = c.get("input") or {}
                nome_skill = str(i.get("skill") or "") if c.get("name") == "Skill" else ""
                if "review" in nome_skill or "verify" in nome_skill:
                    verif[1] = True
                if c.get("name") in ("Bash", "PowerShell") and verifica(str(i.get("command") or "")):
                    verif[0] = True
                if c.get("name") == "Skill" and "atualizar-docs" in nome_skill:
                    docs_antes = True
                elif (
                    c.get("name") in ("Bash", "PowerShell")
                    and c.get("id") not in ids_commit
                    and faz_commit(str(i.get("command") or ""))
                ):
                    commits += 1
                    com_docs += docs_antes
                    vista = (verif[0], verif[1], verif[2])
                    for k in range(3):
                        com_verif[k] += vista[k]
                    sem_verif += not any(vista)
                    ids_commit[c.get("id")] = (docs_antes, vista)
                    docs_antes = False
                    verif = [False, False, False]
                if c.get("name") in ("Agent", "Task"):
                    tipo = i.get("subagent_type") or "general-purpose"
                    modelo, corrigida = modelo_efetivo(tipo, i.get("model") or "")
                    chamadas[tipo][modelo] += 1
                    corrigidas[tipo] += corrigida
                    if i.get("effort"):
                        com_effort[str(i["effort"])] += 1
                    if tipo == "padrao:revisor":
                        verif[1] = True
                    elif tipo == "padrao:executor":
                        verif[2] = True
                    ids_agent[c.get("id")] = (tipo, modelo)
                    delegou = True
        sessoes += ativa
        sem_delegar += ativa and not delegou

    for arq in pasta.glob("*/subagents/*.jsonl"):
        for o, _ in linhas(arq, desde):
            msg = o.get("message")
            if o.get("type") == "assistant" and isinstance(msg, dict):
                guardar_uso(uso_sub, msg)
                guardar_advisor(uso_advisor, msg)
                if de_modelo(msg) and turno_novo(o, vistos):
                    turnos_sub[msg["model"]] += 1

    print(f"últimos {dias} dias · {sessoes} sessão(ões) · {sem_delegar} sem nenhuma delegação")
    correcoes = "  ".join(f"{t}={n}" for t, n in corrigidas.most_common() if n)
    print(f"hook de modelo: {sum(corrigidas.values())} correção(ões) de papel fixo"
          + (f" ({correcoes})" if correcoes else "") + f" · {recusas} recusa(s)")
    print(f"documentação antes do commit: {commits} commit(s) · {com_docs} com a atualizar-docs antes"
          f" · {lembretes} lembrete(s) do hook")
    print(f"verificação antes do commit: {commits} commit(s) · {com_verif[0]} com teste ou build"
          f" · {com_verif[1]} com revisor · {com_verif[2]} com executor · {sem_verif} sem nenhuma")
    if com_effort:
        print(f"effort na chamada do subagent: {sum(com_effort.values())} chamada(s) · "
              + "  ".join(f"{e}={n}" for e, n in com_effort.most_common()))
    if uso_advisor:
        consultas = Counter(modelo for modelo, _ in uso_advisor.values())
        print(f"advisor: {len(uso_advisor)} consulta(s) · " + "  ".join(f"{m}={n}" for m, n in consultas.most_common()))
    total: Counter[str] = Counter()
    print("subagents (tipo: modelo em que rodou × chamadas):")
    for tipo, por_modelo in sorted(chamadas.items()):
        por_modelo = +por_modelo  # some a contagem zerada pela recusa
        total.update(por_modelo)
        print(f"  {tipo:<20} " + "  ".join(f"{m}={n}" for m, n in por_modelo.most_common()))
    print("  total                " + "  ".join(f"{m}={n}" for m, n in total.most_common()))
    print("tokens por modelo (entrada · cache lido · saída):")
    for rotulo, usos in (("principal", uso_principal), ("subagents", uso_sub), ("advisor", uso_advisor)):
        for modelo, c in sorted(somar_uso(usos).items(), key=lambda kv: -sum(kv[1].values())):
            print(f"  {rotulo:<10} {modelo:<22} {fmt(c['entrada'])} · {fmt(c['cache lido'])} · {fmt(c['saída'])}")
    print(
        "turnos do agente principal: "
        + "  ".join(f"{m}={n}" for m, n in turnos_principal.most_common())
    )
    print(
        "turnos dos subagents:       " + "  ".join(f"{m}={n}" for m, n in turnos_sub.most_common())
    )
    imprimir_custo(uso_principal, uso_sub, uso_advisor)


if __name__ == "__main__":
    main()
