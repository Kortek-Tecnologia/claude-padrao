#!/bin/sh
# Os coletores — o Explore embutido e os agentes `coletor`, `revisor` e `leitor` do
# plugin — não têm Write/Edit, mas têm Bash (e o Explore, no Windows,
# PowerShell) e podem gravar arquivo por eles mesmo instruídos a só ler.
# Agente de plugin não declara hook no frontmatter; por isso este porteiro roda
# para todo Bash e PowerShell e só aplica a trava quando a chamada vem de um
# coletor (`agent_type` da entrada do hook). Fora deles: silêncio.
#
# - Bash: passa pela trava de segmentos (so-le.sh).
# - PowerShell: negado inteiro — não há lista de leitura para ele; o coletor
#   tem Read/Grep/Glob e o Bash travado.
# - Sem jq: o coletor é negado (fechado por padrão); os demais seguem.
COLETORES='Explore|padrao:coletor|padrao:revisor|padrao:leitor'
entrada=$(cat)

nega() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s so le: %s"}}\n' "${tipo:-coletor}" "$1"
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s' "$entrada" | grep -Eq "\"agent_type\"[[:space:]]*:[[:space:]]*\"($COLETORES)\"" &&
    nega "jq ausente, nao consigo analisar o comando. Use Read/Grep/Glob."
  exit 0
fi
tipo=$(printf '%s' "$entrada" | jq -r '.agent_type // ""')
printf '%s' "$tipo" | grep -Eqx "$COLETORES" || exit 0
ferramenta=$(printf '%s' "$entrada" | jq -r '.tool_name // "Bash"')
[ "$ferramenta" = Bash ] ||
  nega "$ferramenta fechado. Use Read/Grep/Glob ou Bash de leitura."
printf '%s' "$entrada" | sh "$(dirname "$0")/so-le.sh" "$tipo"
