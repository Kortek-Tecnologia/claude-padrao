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

# barra MOTIVO: imprime "motivo|segmento" — a recusa diz ao agente o que mudar.
barra() { printf '%s|%s\n' "$1" "$seg"; }
grava='opcao que grava arquivo ou executa programa'

bloqueado=$(segmentar "$cmd" |
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    case "$seg" in *'>'*) barra 'grava em arquivo (redirecionamento)'; continue ;; esac
    set -- $seg
    case "$1" in
      cat|grep|egrep|fgrep|head|tail|wc|ls|stat|diff|cmp|echo|printf|jq|test|'['|readlink|realpath|basename|dirname|true|false|cd|pwd|cut|tr|column|nl) ;;
      sort) printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*o|--output|--compress-program)' && barra "$grava" ;;
      uniq)
        # `uniq ENTRADA SAIDA` grava SAIDA: nega com dois operandos.
        printf '%s' "$seg" | awk '{n=0; for(i=2;i<=NF;i++){if($i ~ /^-[fsw]$/){i++;continue} if($i !~ /^-/)n++} exit !(n>=2)}' && barra "$grava" ;;
      file) printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*C|--compile)' && barra "$grava" ;;
      # --hostname-bin roda o programa dado para descobrir o host.
      rg) printf '%s' "$seg" | grep -Eq -- '--pre|--hostname-bin' && barra "$grava" ;;
      # sed e awk são linguagens: filtro de texto não fecha (s|a|b|e executa com
      # qualquer delimitador, o gawk chama system() por @f). Só passam com
      # --sandbox logo após o nome — antes de um `--`, que o tornaria nome de
      # arquivo —, que recusa e/r/w no sed e system, redirecionamento e extensão
      # no gawk. O mawk não tem --sandbox: falha, e fica fechado.
      sed)
        case "$seg" in 'sed --sandbox '*) ;; *) barra 'sed e awk so com --sandbox logo apos o nome'; continue ;; esac
        # o --sandbox não impede -i (grava no lugar)
        printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*i|--in-place)' && barra "$grava" ;;
      awk)
        case "$seg" in 'awk --sandbox '*) ;; *) barra 'sed e awk so com --sandbox logo apos o nome'; continue ;; esac
        # o --sandbox não impede -d/-p/-o (gravam variáveis, perfil e programa
        # em arquivo) nem o depurador (-D)
        printf '%s' "$seg" | grep -Eq -- '[[:space:]](-[A-Za-z]*[dDpo]|--(dump|debug|profile|pretty))' && barra "$grava" ;;
      find) printf '%s' "$seg" | grep -Eq -- '-(exec|execdir|ok|okdir|delete|fprint|fls)' && barra "$grava" ;;
      git)
        # -c/--config-env mudam config na hora (core.fsmonitor, diff.external
        # executam programa); -O/--open-files-in-pager do grep também;
        # --git-dir/--work-tree apontariam para um repositório com config de fora.
        case "$seg" in *--output*|*--open-files-in-pager*|*--config-env*|*--exec-path*|*--ext-diff*|*--git-dir*|*--work-tree*) barra "$grava"; continue ;; esac
        printf '%s' "$seg" | grep -Eq -- '[[:space:]](-c|-O[^[:space:]]*)([[:space:]]|$)' && { barra "$grava"; continue; }
        sub=$(printf '%s' "$seg" | awk '{for(i=2;i<=NF;i++){if($i=="-C"){i++;continue} if($i ~ /^-/)continue; print $i; exit}}')
        case "$sub" in
          log|show|diff|blame|grep|status|ls-files|ls-tree|rev-parse|rev-list|cat-file|shortlog|merge-base|name-rev|describe) ;;
          *) barra "git so com subcomando de leitura (log, show, diff, status, grep...)" ;;
        esac ;;
      *) barra 'comando fora da lista de leitura; para ler arquivo use Read/Grep/Glob' ;;
    esac
  done | head -n 1)

[ -n "$bloqueado" ] &&
  negar "${bloqueado%%|*}: $(printf '%s' "${bloqueado#*|}" | tr -d '"\\' | cut -c1-80)"
exit 0
