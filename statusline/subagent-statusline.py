#!/usr/bin/env python3
"""Linha de cada subagent no painel de agentes (subagentStatusLine) do padrao.

    tipo · Modelo 5.5 · effort · ctx 12% (120k) · 1m32s · descrição

Recebe {"columns": N, "tasks": [...]} no stdin e devolve uma linha JSON
{"id", "content"} por task. Modelo fora da família 5.5 sai em vermelho — é a
política do padrao (aliases fixados em claude-*-5-5). Task sem modelo resolvido
ainda: mostra "…".
"""
import json
import re
import sys
import time

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")

GREEN, YELLOW, RED, CYAN, MAGENTA, BOLD, RESET = (
    "\033[32m", "\033[33m", "\033[31m", "\033[36m", "\033[35m", "\033[1m", "\033[0m",
)
GRAY = "\033[38;5;244m"
FAMILIA = {"opus": MAGENTA, "sonnet": CYAN, "haiku": GREEN}
STATUS = {"completed": f"{GREEN}✓{RESET}", "failed": f"{RED}✗{RESET}", "killed": f"{GRAY}■{RESET}"}
ANSI = re.compile(r"\033\[[0-9;]*m")
SEP = f" {GRAY}·{RESET} "


def modelo(m):
    """claude-haiku-5-5[1m] → ('Haiku 5.5', cor); fora da 5.5 em vermelho."""
    if not m:
        return f"{GRAY}…{RESET}"
    r = re.match(r"claude-([a-z]+)-(\d+)-(\d+)", m)
    if not r:
        return f"{RED}{m}{RESET}"
    fam, maj, men = r.groups()
    nome = f"{fam.capitalize()} {maj}.{men}"
    cor = FAMILIA.get(fam, YELLOW) if (maj, men) == ("5", "5") else RED
    return f"{BOLD}{cor}{nome}{RESET}"


def tokens(n):
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M".replace(".0M", "M")
    return f"{n / 1000:.0f}k" if n >= 1000 else str(n)


def contexto(t):
    n = t.get("tokenCount") or 0
    janela = t.get("contextWindowSize")
    if not janela:
        return f"{tokens(n)} tok"
    pct = n * 100 // janela
    cor = RED if pct >= 90 else YELLOW if pct >= 70 else GREEN
    return f"ctx {cor}{pct}%{RESET} {GRAY}({tokens(n)}){RESET}"


def duracao(inicio_ms):
    if not inicio_ms:
        return ""
    s = max(0, int(time.time() - inicio_ms / 1000))
    if s >= 3600:
        return f"{s // 3600}h{s % 3600 // 60:02d}m"
    return f"{s // 60}m{s % 60:02d}s" if s >= 60 else f"{s}s"


def corta(texto, largura):
    """Corta pelo comprimento visível, sem quebrar códigos de cor."""
    if len(ANSI.sub("", texto)) <= largura:
        return texto
    out, vis = [], 0
    for parte in re.split(r"(\033\[[0-9;]*m)", texto):
        if ANSI.fullmatch(parte or "x"):
            out.append(parte)
            continue
        resta = largura - 1 - vis
        if resta <= 0:
            break
        out.append(parte[:resta])
        vis += len(parte[:resta])
    return "".join(out) + "…" + RESET


def linha(t, largura):
    tipo = t.get("name") or t.get("agentType") or "agente"
    marca = STATUS.get(t.get("status"))
    partes = [(f"{marca} " if marca else "") + f"{BOLD}{tipo}{RESET}", modelo(t.get("model"))]
    if t.get("effort") is not None:
        partes.append(f"{GRAY}{t['effort']}{RESET}")
    partes += [contexto(t), duracao(t.get("startTime"))]
    descricao = t.get("label") or t.get("description") or ""
    if descricao:
        partes.append(f"{GRAY}{descricao}{RESET}")
    return corta(SEP.join(p for p in partes if p), largura)


def main():
    try:
        dados = json.load(sys.stdin)
    except ValueError:
        return
    largura = int(dados.get("columns") or 100)
    for t in dados.get("tasks") or []:
        if t.get("id"):
            print(json.dumps({"id": t["id"], "content": linha(t, largura)}, ensure_ascii=False))


main()
