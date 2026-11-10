#!/bin/sh
# Documentação antes do commit. A regra "antes de todo commit, a skill
# padrao:atualizar-docs" morava só no bloco do CLAUDE.md, e instrução depende de
# o modelo lembrar: medida no histórico local, ela rodava antes de ~4% dos commits.
# O que tem hora certa para acontecer vai em hook; este cobra a skill na hora
# do `git commit`.
#
# Dois papéis, pelo `tool_name` da entrada:
# - Skill `padrao:atualizar-docs`: anota `docs` para a sessão.
# - Bash ou PowerShell com `git commit` (segmento que começa por git, com ou sem
#   opção global, e subcomando commit; o corte é o de segmentos.sh):
#     há anotação — `docs` (a skill rodou) ou `avisado` (já recusei uma vez) —
#       → segue, e a anotação é gasta: cada commit pede a sua passada;
#     não há → recusa UMA vez, mandando rodar a skill, e anota `avisado`.
#   A segunda tentativa sempre passa: é lembrete na hora certa, não trava. O
#   hook não sabe se o diff tem algo documentado, e commit preso é pior que doc
#   velha.
# - Commit do /padrao:arrumar (mensagem que começa por `arrumar: lote `) passa:
#   o plano já cuidou da documentação.
#
# A anotação é por sessão (`session_id`), não por repositório: ~12% dos commits
# do histórico rodam fora do cwd da sessão (`cd outro && git commit`, `git -C`).
# Mora em ${CLAUDE_PLUGIN_DATA}, um arquivo por sessão; o commit que passa o
# apaga, e a skill varre os de mais de 7 dias (skill que rodou sem commit).
#
# Falha ABERTA, ao contrário das travas: sem jq, sem session_id ou sem onde
# anotar, o hook se cala e o commit segue.
entrada=$(cat)
# Roda em todo `git …` do Bash: sai sem abrir jq quando não é commit nem a skill.
case "$entrada" in *commit* | *atualizar-docs*) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

# No Windows o jq termina a linha em CRLF.
cab=$(printf '%s' "$entrada" |
  jq -r '[.tool_name // "", .session_id // "", .tool_input.skill // ""] | join("|")' 2>/dev/null |
  tr -d '\r') || exit 0
ferramenta=${cab%%|*}
resto=${cab#*|}
skill=${resto#*|}
sessao=$(printf '%s' "${resto%%|*}" | tr -cd 'A-Za-z0-9_-')
[ -n "$sessao" ] || exit 0

dir=${CLAUDE_PLUGIN_DATA:-}
[ -n "$dir" ] || exit 0
mkdir -p "$dir" 2>/dev/null || exit 0
nota="$dir/docs-$sessao"

if [ "$ferramenta" = Skill ]; then
  case "$skill" in
    padrao:atualizar-docs | atualizar-docs)
      { printf 'docs\n' >"$nota"; } 2>/dev/null
      find "$dir" -name 'docs-*' -mtime +7 -exec rm -f {} + 2>/dev/null
      ;;
  esac
  exit 0
fi
case "$ferramenta" in Bash | PowerShell) ;; *) exit 0 ;; esac

cmd=$(printf '%s' "$entrada" | jq -r '.tool_input.command // ""' 2>/dev/null | tr -d '\r')
lib="$(dirname "$0")/segmentos.sh"
[ -r "$lib" ] || exit 0
# shellcheck source=segmentos.sh
. "$lib"
# Segmento que é um commit: atribuições (`X=1`, `X="a b"`) e palavras do shell
# na frente, `git` (com caminho ou `.exe`), opções globais (`-C dir`, `-c k=v`,
# `--no-pager`) e o subcomando `commit`. Escapam, e o commit segue sem lembrete:
# `bash -c "git commit"`, alias (`git ci`) e opção global com o valor separado
# (`--git-dir x`) — nenhuma apareceu no histórico.
arg="([^[:space:]\"']|\"[^\"]*\"|'[^']*')+"
commit="^((then|do|else|time|command|exec|env|sudo)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=($arg)?[[:space:]]+)*([^[:space:]\"']*[/\\\\])?git(\\.exe)?([[:space:]]+(-[Cc][[:space:]]+$arg|--?[A-Za-z][A-Za-z-]*(=$arg)?))*[[:space:]]+commit([[:space:]]|\$)"
# Corpo de heredoc é texto, não comando: sai antes do corte. O segmentador é o
# da trava, que parte na crase por segurança, e veria um commit em todo texto
# que cita `git commit` (entrada de AGENT_LEARNINGS, doc gravada por `cat <<EOF`).
# Só some o corpo que fecha: `<<` de aritmética ou entre aspas não tem linha de
# fim, e o que vinha depois (talvez um commit) volta.
sem_heredoc() {
  awk -v q="[\"']?" '
    fim != "" {
      l = $0; sub(/^\t+/, "", l)
      if (l == fim) { fim = ""; corpo = "" } else corpo = corpo $0 "\n"
      next
    }
    { print }
    match($0, "(^|[^<])<<-?[ \t]*" q "[A-Za-z_][A-Za-z0-9_]*" q) {
      fim = substr($0, RSTART, RLENGTH)
      sub("^[^<]?<<-?[ \t]*", "", fim)
      gsub("[\"\047]", "", fim)
      corpo = ""
    }
    END { if (fim != "") printf "%s", corpo }'
}
commits=$(segmentar "$(printf '%s\n' "$cmd" | sem_heredoc)" | grep -Ec "$commit")
[ "${commits:-0}" -gt 0 ] 2>/dev/null || exit 0
# Lote do /padrao:arrumar: a MENSAGEM do commit começa por `arrumar: lote `, em
# `-m "…"` ou na 1ª linha de `-m "$(cat <<EOF`. Citar o texto em outro ponto do
# comando não isenta, e commit comum no mesmo comando continua cobrado.
lotes=$(printf '%s\n' "$cmd" | awk -v q="[\"']" '
  { n += gsub("-m[ \t]*" q "arrumar: lote ", "&") }
  ant ~ /-m[ \t]*"\$\(cat[ \t]*<</ && /^arrumar: lote / { n++ }
  { ant = $0 }
  END { print n + 0 }')
[ "${lotes:-0}" -ge "$commits" ] 2>/dev/null && exit 0

if [ -f "$nota" ]; then
  rm -f "$nota"
  exit 0
fi
{ printf 'avisado\n' >"$nota"; } 2>/dev/null || exit 0
# O Claude Code mostra a recusa como "hook error": o texto diz que é rotina, senão
# o modelo a registra como erro no AGENT_LEARNINGS (aconteceu no teste de ponta a
# ponta). O medir reconhece a recusa por "antes deste commit, rode a skill".
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"padrao: lembrete de rotina, nao e erro nem vai para o AGENT_LEARNINGS: antes deste commit, rode a skill padrao:atualizar-docs (ela acerta a doc que o diff deixou falsa) e repita o commit. Se ela ja rodou sobre este diff, so repita: o lembrete sai uma vez por commit."}}\n'
