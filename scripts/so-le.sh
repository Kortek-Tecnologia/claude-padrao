#!/bin/sh
# Trava de SÓ-LEITURA para subagent que precisa de Bash (`git diff`, `grep`) mas
# não pode escrever. Pensada para rodar em sessões com permissões liberadas: sem
# esta trava, "não escreva" seria só prosa.
# `$1` = nome do agente, só para a mensagem (padrão: subagent).
#
# Regra: FECHADA POR PADRÃO, por segmento. Cada segmento do comando precisa
# começar por um leitor conhecido (git só com subcomando de leitura) e não
# redirecionar para arquivo; qualquer outra forma é NEGADA. O corte em
# segmentos é o de segmentos.sh, no mesmo diretório.
#
# Contrato PreToolUse: silêncio = segue; permissionDecision=deny = bloqueia.

set -f
quem=${1:-subagent}
cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null) || cmd=

negar() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s so le: %s"}}\n' "$quem" "$1"
  exit 0
}

command -v jq >/dev/null 2>&1 || negar "jq ausente, nao consegui analisar o comando"
lib="$(dirname "$0")/segmentos.sh"
[ -r "$lib" ] || negar "segmentos.sh ausente, nao consegui analisar o comando"
# shellcheck source=segmentos.sh
. "$lib"
[ -n "$cmd" ] || exit 0

bloqueado=$(segmentar "$cmd" |
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    case "$seg" in *'>'*) echo "$seg"; continue ;; esac
    set -- $seg
    case "$1" in
      cat|grep|egrep|fgrep|head|tail|wc|ls|stat|diff|cmp|echo|printf|jq|test|'['|readlink|realpath|basename|dirname|true|false|cd|pwd|cut|tr|column|nl) ;;
      sort) printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*o|--output|--compress-program)' && echo "$seg" ;;
      uniq)
        # `uniq ENTRADA SAIDA` grava SAIDA: nega com dois operandos.
        printf '%s' "$seg" | awk '{n=0; for(i=2;i<=NF;i++){if($i ~ /^-[fsw]$/){i++;continue} if($i !~ /^-/)n++} exit !(n>=2)}' && echo "$seg" ;;
      file) printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*C|--compile)' && echo "$seg" ;;
      rg) printf '%s' "$seg" | grep -Eq -- '--pre' && echo "$seg" ;;
      sed)
        # -i grava no lugar; os comandos w/W e a flag w do s/// gravam arquivo;
        # e (GNU) executa comando. Na dúvida, nega.
        printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*i|--in-place)|([0-9$/!;{}]|[[:space:]]|['"'"'"])[wWe]([[:space:]'"'"'"]|$)|/[gpiImM0-9]*[we]([[:space:]'"'"'";}]|$)' && echo "$seg" ;;
      awk)
        # `|` dentro do programa abre comando ("cmd" | getline, print | "sh");
        # -f/-E/-i/-l carregam programa ou biblioteca de fora.
        printf '%s' "$seg" | grep -Eq -- 'inplace|system|getline|[|]|[[:space:]](-[fEil]|--(file|exec|include|load))' && echo "$seg" ;;
      find) printf '%s' "$seg" | grep -Eq -- '-(exec|execdir|ok|okdir|delete|fprint|fls)' && echo "$seg" ;;
      git)
        # -c/--config-env mudam config na hora (core.fsmonitor, diff.external
        # executam programa); -O/--open-files-in-pager do grep também.
        case "$seg" in *--output*|*--open-files-in-pager*|*--config-env*|*--exec-path*|*--ext-diff*) echo "$seg"; continue ;; esac
        printf '%s' "$seg" | grep -Eq -- '[[:space:]](-c|-O[^[:space:]]*)([[:space:]]|$)' && { echo "$seg"; continue; }
        sub=$(printf '%s' "$seg" | awk '{for(i=2;i<=NF;i++){if($i=="-C"){i++;continue} if($i ~ /^-/)continue; print $i; exit}}')
        case "$sub" in
          log|show|diff|blame|grep|status|ls-files|ls-tree|rev-parse|rev-list|cat-file|shortlog|merge-base|name-rev|describe) ;;
          *) echo "$seg" ;;
        esac ;;
      *) echo "$seg" ;;
    esac
  done | head -n 1)

[ -n "$bloqueado" ] &&
  negar "segmento fora da lista de leitura: $(printf '%s' "$bloqueado" | tr -d '"\\' | cut -c1-80)"
exit 0
