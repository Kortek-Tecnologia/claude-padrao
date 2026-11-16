#!/usr/bin/env python3
"""Liga, desliga e mostra os dois opcionais do padrão. Ficam fora da política de
modelos: são escolha de quem liga, e nenhum vem ligado.

    sh <plugin>/scripts/py.sh <plugin>/scripts/opcional.py code-mode [ligar|desligar]
    sh <plugin>/scripts/py.sh <plugin>/scripts/opcional.py advisor [ligar|desligar] [--projeto P]

Sem ação, só mostra o estado.

- code-mode: `env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE: "1"` no ~/.claude/settings.json.
  O Claude Code só aceita essa variável do shell, do settings do usuário ou de
  um `--settings`; do settings do projeto e do local ele a descarta. Por isso é
  a única chave de `env` que o padrão deixa no global (o conferir-padrao.sh a
  deixa passar). Vale para a máquina inteira, não para um projeto.
- advisor: `advisorModel` no .claude/settings.local.json do PROJETO (o diretório
  corrente, ou --projeto). A chave vale em qualquer settings, então não precisa
  do global, onde o `/advisor` a grava. Fica no arquivo pessoal porque o Fable
  custa mais e, conforme o plano, consome créditos de uso de quem ligou. O valor
  é o ID que o padrão fixa (`env.ANTHROPIC_DEFAULT_FABLE_MODEL` do modelo de
  settings), não o alias `fable`, que acompanha a versão do Claude Code.

Desligar tira a chave (e o `env` que ficar vazio). O arquivo é regravado com a
indentação e o fim de linha que tinha. JSON inválido não é tocado: o script
para com erro.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

VAR = "CLAUDE_CODE_EXPERIMENTAL_CODE_MODE"
CHAVE = "advisorModel"
# Fonte única do padrão: o mesmo arquivo que o `aplicar` grava no projeto.
MODELO = Path(__file__).resolve().parent.parent / "skills" / "aplicar" / "modelos" / "settings.json"
ACOES = {
    "estado": None, "status": None,
    "ligar": "ligar", "on": "ligar", "ativar": "ligar",
    "desligar": "desligar", "off": "desligar", "desativar": "desligar",
}
GLOBAL = "~/.claude/settings.json"
LOCAL = ".claude/settings.local.json"
TIME = ".claude/settings.json"


def falha(msg: str):
    raise SystemExit(f"erro: {msg}")


def ler(arq: Path, nome: str) -> tuple[dict, str | None]:
    """(settings, texto original); ({}, None) se o arquivo não existe."""
    try:
        texto = arq.read_bytes().decode("utf-8-sig")
    except FileNotFoundError:
        return {}, None
    except (OSError, ValueError) as e:
        falha(f"não consegui ler {nome}: {e}")
    try:
        dados = json.loads(texto) if texto.strip() else {}
    except ValueError as e:
        falha(f"{nome} não é JSON válido ({e}). Não mexi no arquivo: corrija-o e rode de novo.")
    if not isinstance(dados, dict):
        falha(f"{nome} não é um objeto JSON. Não mexi no arquivo.")
    return dados, texto


def ler_solto(arq: Path) -> dict:
    """Para os arquivos que o script só consulta: ilegível conta como vazio."""
    try:
        dados = json.loads(arq.read_bytes().decode("utf-8-sig"))
    except (OSError, ValueError):
        return {}
    return dados if isinstance(dados, dict) else {}


def gravar(arq: Path, nome: str, dados: dict, antigo: str | None) -> None:
    """Regrava com a indentação e o fim de linha do original, por arquivo
    temporário na mesma pasta (o settings nunca fica pela metade)."""
    recuo: int | str = 2
    fim = "\n"
    if antigo:
        m = re.search(r'^([ \t]+)"', antigo, re.M)
        if m:
            recuo = m.group(1)
        if "\r\n" in antigo:
            fim = "\r\n"
    texto = (json.dumps(dados, ensure_ascii=False, indent=recuo) + "\n").replace("\n", fim)
    tmp = None
    try:
        arq.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=arq.parent, prefix=arq.name + ".", suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
            f.write(texto)
        if arq.exists():
            os.chmod(tmp, stat.S_IMODE(arq.stat().st_mode))
        os.replace(tmp, arq)
    except OSError as e:
        if tmp:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        falha(f"não consegui gravar {nome}: {e}")


def code_mode(acao: str | None) -> None:
    arq = Path.home() / ".claude" / "settings.json"
    cfg, texto = ler(arq, GLOBAL)
    env = cfg.get("env")
    if env is not None and not isinstance(env, dict):
        falha(f"`env` de {GLOBAL} não é um objeto. Não mexi no arquivo.")
    mudou = False
    if acao == "ligar" and (env or {}).get(VAR) != "1":
        if env is None:
            env = cfg["env"] = {}
        env[VAR] = "1"
        mudou = True
    elif acao == "desligar" and env and VAR in env:
        del env[VAR]
        if not env:
            del cfg["env"]
        mudou = True
    if mudou:
        gravar(arq, GLOBAL, cfg, texto)

    valor = (cfg.get("env") or {}).get(VAR)
    if valor == "1":
        print(f'Code Mode: ligado · env.{VAR} = "1" em {GLOBAL}')
    elif valor is None:
        print(f"Code Mode: desligado · {GLOBAL} sem env.{VAR}")
    elif valor == "0":
        print(f'Code Mode: desligado à força · env.{VAR} = "0" em {GLOBAL} (vence o "1" do shell)')
    else:
        print(f'Code Mode: desligado · env.{VAR} = {json.dumps(valor, ensure_ascii=False)} em {GLOBAL} (só "1" liga)')
    if mudou:
        print("gravado: vale a partir da próxima sessão, em todas as pastas desta máquina")
    elif acao:
        print("nada a gravar: já estava assim")


def fable_do_padrao() -> str:
    env = ler_solto(MODELO).get("env")
    return (env.get("ANTHROPIC_DEFAULT_FABLE_MODEL") if isinstance(env, dict) else None) or "fable"


def fora_do_gitignore(raiz: Path) -> bool:
    """True só quando há repositório git e o arquivo pessoal não está ignorado."""
    try:
        r = subprocess.run(
            ["git", "-C", str(raiz), "check-ignore", "-q", LOCAL],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except OSError:
        return False
    return r.returncode == 1


def advisor(acao: str | None, raiz: Path) -> None:
    raiz = raiz.resolve()
    if raiz == Path.home().resolve():
        falha(f"o home não é projeto (aqui o {LOCAL} seria global): rode de dentro de um projeto ou passe --projeto.")
    if not raiz.is_dir():
        falha(f"{raiz} não é uma pasta.")
    arq = raiz / ".claude" / "settings.local.json"
    cfg, texto = ler(arq, LOCAL)
    alvo = fable_do_padrao()
    mudou = False
    if acao == "ligar" and cfg.get(CHAVE) != alvo:
        cfg[CHAVE] = alvo
        mudou = True
    elif acao == "desligar" and CHAVE in cfg:
        del cfg[CHAVE]
        mudou = True
    if mudou:
        gravar(arq, LOCAL, cfg, texto)

    # Precedência do Claude Code: local > projeto > usuário.
    do_time = ler_solto(raiz / ".claude" / "settings.json").get(CHAVE)
    do_global = ler_solto(Path.home() / ".claude" / "settings.json").get(CHAVE)
    if cfg.get(CHAVE):
        print(f"Advisor neste projeto: {cfg[CHAVE]} · {CHAVE} em {LOCAL}")
    elif do_time:
        print(f"Advisor neste projeto: {do_time} · {CHAVE} em {TIME} (do time, no git)")
    elif do_global:
        print(f"Advisor neste projeto: {do_global} · {CHAVE} em {GLOBAL} (vale em todas as pastas)")
    else:
        print(f"Advisor neste projeto: desligado · nenhum settings traz {CHAVE}")
    if mudou:
        print(f"gravado em {LOCAL}: vale a partir da próxima sessão deste projeto")
    elif acao:
        print("nada a gravar: já estava assim")
    if do_global:
        print(f"aviso: {GLOBAL} tem {CHAVE} = {json.dumps(do_global, ensure_ascii=False)} (o /advisor grava lá): "
              "fora do padrão; o /padrao:aplicar o leva para o projeto. Desligar aqui não o tira de lá.")
    if acao == "desligar" and not cfg.get(CHAVE) and do_time:
        print(f"aviso: o advisor segue ligado pelo {TIME} do time.")
    if cfg.get(CHAVE) and fora_do_gitignore(raiz):
        print(f"aviso: {LOCAL} não está no .gitignore deste repositório (o /padrao:aplicar o põe): é arquivo pessoal.")


def main() -> None:
    ap = argparse.ArgumentParser(description="Liga, desliga e mostra os opcionais do padrão.")
    ap.add_argument("opcional", choices=["code-mode", "advisor"])
    ap.add_argument("acao", nargs="?", default="estado", help="ligar | desligar (vazio: só o estado)")
    ap.add_argument("--projeto", type=Path, default=None, help="só para o advisor; padrão: o diretório corrente")
    args = ap.parse_args()
    for saida in (sys.stdout, sys.stderr):  # console do Windows não é UTF-8
        saida.reconfigure(encoding="utf-8")
    if args.acao.lower() not in ACOES:
        falha(f"ação '{args.acao}' desconhecida: use ligar ou desligar (vazio mostra o estado).")
    acao = ACOES[args.acao.lower()]
    if args.opcional == "code-mode":
        code_mode(acao)
    else:
        advisor(acao, args.projeto or Path.cwd())


if __name__ == "__main__":
    main()
