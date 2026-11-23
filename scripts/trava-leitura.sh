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
# - Bash: passa pela trava de segmentos (so-le.awk).
# - Qualquer outra ferramenta do matcher (PowerShell, MCP...): negada inteira;
#   o agente tem Read/Grep/Glob e o Bash travado. Ferramenta nova que executa
#   ou grava entra no matcher do hooks.json.
# - Sem jq, sem os .awk ou com o jq falhando: o agente que só lê é negado
#   (fechado por padrão); os demais seguem.
#
# Custo: este hook roda em todo Bash, e no Windows abrir um processo custa de
# 100 a 800 ms. A sessão principal sai sem abrir nenhum (a entrada é lida pelo
# `read` do shell); o agente que só lê paga um jq e um awk.
SO_LEEM='Explore|padrao:coletor|padrao:revisor|padrao:leitor'
nl='
'
entrada=
while IFS= read -r linha || [ -n "$linha" ]; do entrada="$entrada$linha$nl"; done
# Sessão principal não traz agent_type: sai aqui.
case "$entrada" in *'"agent_type"'*) ;; *) exit 0 ;; esac
case "$0" in */*) aqui=${0%/*} ;; *) aqui=. ;; esac

# sem_analise MOTIVO: sem como analisar, nega o agente que só lê (o tipo sai por
# regex) e deixa o resto seguir.
sem_analise() {
  tipo=$(printf '%s' "$entrada" | tr '\n' ' ' |
    sed -nE "s/.*\"agent_type\"[[:space:]]*:[[:space:]]*\"($SO_LEEM)\".*/\\1/p")
  [ -n "$tipo" ] &&
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s so le: %s, nao consigo analisar o comando. Use Read/Grep/Glob."}}\n' "$tipo" "$1"
  exit 0
}
command -v jq >/dev/null 2>&1 || sem_analise "jq ausente"
[ -r "$aqui/segmentos.awk" ] && [ -r "$aqui/so-le.awk" ] || sem_analise "segmentos.awk ou so-le.awk ausente"

# Um jq tira o agente, a ferramenta e o comando; o awk decide (so-le.awk). O jq
# que falha (entrada cortada, erro ao abrir) não devolve nada: sem o tipo o awk
# não tem como decidir e sai com 3, e a chamada cai na saída de quem não tem jq.
# Os dois seguem num pipe só (rodam juntos: em série a trava ficava ~50 ms mais
# lenta no Windows).
jq -r '(.agent_type // "" | tostring), (.tool_name // "Bash" | tostring), (.tool_input.command // "" | tostring)' 2>/dev/null <<EOF |
$entrada
EOF
  awk -v cab=1 -v so_leem="$SO_LEEM" -f "$aqui/segmentos.awk" -f "$aqui/so-le.awk"
rc=$?
[ "$rc" -eq 3 ] && sem_analise "o jq falhou"
exit "$rc"
