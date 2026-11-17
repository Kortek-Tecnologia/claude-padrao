#!/bin/sh
# Trava de SÓ-LEITURA para subagent que precisa de Bash (`git diff`, `grep`) mas
# não pode escrever. Pensada para rodar em sessões com permissões liberadas: sem
# esta trava, "não escreva" seria só prosa.
# `$1` = nome do agente, só para a mensagem (padrão: subagent).
#
# Regra: FECHADA POR PADRÃO, por segmento. Cada segmento do comando precisa
# começar por um leitor conhecido (git só com subcomando de leitura) e não
# redirecionar para arquivo; qualquer outra forma é NEGADA. A regra mora em
# so-le.awk e o corte em segmentos em segmentos.awk, no mesmo diretório: a
# decisão inteira sai de um jq e um awk (no Windows cada processo a mais pesa).
#
# Contrato PreToolUse: silêncio = segue; permissionDecision=deny = bloqueia.

set -f
quem=${1:-subagent}
case "$0" in */*) aqui=${0%/*} ;; *) aqui=. ;; esac

negar() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s so le: %s"}}\n' "$quem" "$1"
  exit 0
}

command -v jq >/dev/null 2>&1 || negar "jq ausente, nao consegui analisar o comando"
[ -r "$aqui/segmentos.awk" ] && [ -r "$aqui/so-le.awk" ] ||
  negar "segmentos.awk ou so-le.awk ausente, nao consegui analisar o comando"
jq -r '.tool_input.command // ""' 2>/dev/null |
  awk -v quem="$quem" -f "$aqui/segmentos.awk" -f "$aqui/so-le.awk"
