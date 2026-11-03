#!/bin/sh
# Os agentes que só leem — o Explore embutido e os agentes `coletor`, `revisor` e
# `leitor` do plugin — não têm Write/Edit, mas o Explore recebe quase todas as
# ferramentas da sessão (Bash, PowerShell no Windows, MCP do projeto, Monitor,
# Workflow, CronCreate...) e pode gravar ou executar por elas mesmo instruído a
# só ler. Agente de plugin não declara hook no frontmatter; por isso este
# porteiro roda para as ferramentas do matcher em hooks.json — as que executam,
# gravam ou falam com fora — e só aplica a trava quando a chamada vem de um
# deles (`agent_type` da entrada do hook). Fora deles: silêncio.
#
# - Bash: passa pela trava de segmentos (so-le.sh).
# - Qualquer outra ferramenta do matcher (PowerShell, MCP...): negada inteira;
#   o agente tem Read/Grep/Glob e o Bash travado. Ferramenta nova que executa
#   ou grava entra no matcher do hooks.json.
# - Sem jq: o agente que só lê é negado (fechado por padrão); os demais seguem.
SO_LEEM='Explore|padrao:coletor|padrao:revisor|padrao:leitor'
entrada=$(cat)
# Sessão principal não traz agent_type: sai sem abrir jq (este hook roda em todo
# Bash; no Windows cada processo a mais pesa).
case "$entrada" in *'"agent_type"'*) ;; *) exit 0 ;; esac

negar() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s so le: %s"}}\n' "${tipo:-subagent}" "$1"
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s' "$entrada" | grep -Eq "\"agent_type\"[[:space:]]*:[[:space:]]*\"($SO_LEEM)\"" &&
    negar "jq ausente, nao consigo analisar o comando. Use Read/Grep/Glob."
  exit 0
fi
tipo=$(printf '%s' "$entrada" | jq -r '.agent_type // ""')
printf '%s' "$tipo" | grep -Eqx "$SO_LEEM" || exit 0
ferramenta=$(printf '%s' "$entrada" | jq -r '.tool_name // "Bash"')
[ "$ferramenta" = Bash ] ||
  negar "$ferramenta fechado. Use Read/Grep/Glob ou Bash de leitura."
printf '%s' "$entrada" | sh "$(dirname "$0")/so-le.sh" "$tipo"
