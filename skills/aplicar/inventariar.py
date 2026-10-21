#!/usr/bin/env python3
"""Inventário do que mora FORA dos projetos (~/.claude e ~/.claude.json), com o
destino sugerido de cada item pelo padrão. Só LÊ; imprime JSON.

    sh <plugin>/scripts/py.sh <dir da skill>/inventariar.py [--projeto P]

Segredos não saem: de MCP vêm nome, tipo e os NOMES das variáveis/cabeçalhos,
nunca os valores. O projeto é o diretório corrente, ou o dado em --projeto.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

G = Path.home() / ".claude"

# Destino de cada chave de ~/.claude/settings.json:
#   padrao  = o modelo do plugin define (o valor global é descartado)
#   descartar = auto memory desligado: a chave não tem mais lugar
#   time    = .claude/settings.json (vai para o git)
#   local   = .claude/settings.local.json (pessoal, fora do git)
#   global  = só vale no escopo user (o Claude Code recusa de projeto)
DESTINO = {
    "model": "padrao",
    "effortLevel": "padrao",
    "fallbackModel": "padrao",  # fora do padrão: sem a chave não há fallback
    "modelSettings": "padrao",
    "autoMemoryEnabled": "global",  # false no global: pasta sem o padrão não cria memória
    "autoMemoryDirectory": "descartar",  # auto memory desligado
    "autoDreamEnabled": "descartar",  # idem
    "cleanupPeriodDays": "padrao",
    "env": "time",
    "hooks": "time",
    "enabledPlugins": "time",
    "extraKnownMarketplaces": "time",
    "disableClaudeAiConnectors": "padrao",
    "statusLine": "global",
    "subagentStatusLine": "global",
    "language": "local",
    "tui": "local",
    "theme": "local",
    "outputStyle": "local",
    "skipDangerousModePermissionPrompt": "global",
    "switchModelsOnFlag": "local",
    "autoMode": "global",
}


def chave_projeto(caminho: str) -> str:
    """Nome da pasta em ~/.claude/projects: não alfanumérico vira "-"."""
    return re.sub(r"[^A-Za-z0-9]", "-", caminho)


def ler_json(arq: Path):
    try:
        return json.loads(arq.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def destino_settings(cfg: dict) -> list[dict]:
    itens = []
    for k, v in cfg.items():
        if k == "permissions" and isinstance(v, dict):
            for pk, pv in v.items():
                d = "global" if pk == "defaultMode" else "time"
                itens.append({"chave": f"permissions.{pk}", "valor": pv, "destino": d})
            continue
        itens.append({"chave": k, "valor": v, "destino": DESTINO.get(k, "avaliar")})
    return itens


def resumo_mcp(servidores: dict) -> list[dict]:
    out = []
    for nome, s in (servidores or {}).items():
        s = s if isinstance(s, dict) else {}
        out.append(
            {
                "nome": nome,
                "tipo": s.get("type") or ("stdio" if "command" in s else "?"),
                "command": s.get("command"),
                "url": s.get("url"),
                "env": sorted((s.get("env") or {}).keys()),
                "headers": sorted((s.get("headers") or {}).keys()),
            }
        )
    return out


def listar(d: Path, ignorar: set[str] = frozenset(), ocultos: bool = True) -> list[str]:
    if not d.is_dir():
        return []
    return sorted(p.name for p in d.iterdir() if p.name not in ignorar and (ocultos or not p.name.startswith(".")))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--projeto", type=Path, default=None)
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    raiz = (args.projeto or Path.cwd()).resolve()

    estado = ler_json(Path.home() / ".claude.json") or {}
    projetos_conhecidos = {chave_projeto(k): k for k in (estado.get("projects") or {})}

    settings = ler_json(G / "settings.json") or {}
    sobras = sorted(
        p.name
        for p in G.glob("settings*")
        if p.name != "settings.json"
    )

    memorias = []
    for mem in sorted(G.glob("projects/*/memory")):
        arquivos = listar(mem)
        if not arquivos:
            continue
        pasta = mem.parent.name
        caminho = projetos_conhecidos.get(pasta)
        memorias.append(
            {
                "pasta": str(mem),
                "projeto": caminho,
                "projeto_existe": bool(caminho) and Path(caminho).is_dir(),
                "eh_este_projeto": pasta == chave_projeto(str(raiz)),
                "eh_home": caminho is not None and Path(caminho).resolve() == Path.home().resolve(),
                "arquivos": arquivos,
            }
        )

    instalados = (ler_json(G / "plugins" / "installed_plugins.json") or {}).get("plugins") or {}
    plugins = [
        {"plugin": nome, "escopo": i.get("scope"), "projeto": i.get("projectPath"), "versao": i.get("version")}
        for nome, lista in instalados.items()
        for i in lista
    ]

    mcp_local = []
    for caminho, p in (estado.get("projects") or {}).items():
        servidores = resumo_mcp((p or {}).get("mcpServers"))
        if servidores:
            mcp_local.append({"projeto": caminho, "projeto_existe": Path(caminho).is_dir(), "servidores": servidores})

    projetos = []
    for chave, caminho in sorted(projetos_conhecidos.items()):
        cfg = ler_json(Path(caminho) / ".claude" / "settings.json") or {}
        if Path(caminho).is_dir():
            projetos.append(
                {
                    "projeto": caminho,
                    "padrao_aplicado": any((cfg.get("enabledPlugins") or {}).get(p) for p in ("padrao@claude-padrao", "padrao@kortek-tools", "padrao@padrao")),
                }
            )

    print(
        json.dumps(
            {
                "projeto_atual": str(raiz),
                "settings_global": destino_settings(settings),
                "settings_sobras": sobras,
                "arquivos_globais": {
                    "CLAUDE.md": (G / "CLAUDE.md").is_file(),
                    "agents": listar(G / "agents"),
                    "commands": listar(G / "commands"),
                    "skills": listar(G / "skills", {"synced"}, ocultos=False),
                    "output-styles": listar(G / "output-styles"),
                    "rules": listar(G / "rules"),
                    "workflows": listar(G / "workflows"),
                    "statusline": sorted(p.name for p in G.glob("statusline*") if p.name not in ("statusline.py", "subagent-statusline.py")),
                    "keybindings.json": (G / "keybindings.json").is_file(),
                },
                "plugins": plugins,
                "mcp_user": resumo_mcp(estado.get("mcpServers")),
                "mcp_local": mcp_local,
                "memorias": memorias,
                "projetos": projetos,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
