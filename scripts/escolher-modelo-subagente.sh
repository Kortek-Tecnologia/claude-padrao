#!/bin/sh
# Política de modelos: Opus decide e faz o difícil, Sonnet executa plano já
# montado, Haiku coleta.
#
# Subagent sem `model` não herda o Opus: o CLAUDE_CODE_SUBAGENT_MODEL=sonnet do
# .claude/settings.json do padrão vale para chamada sem `model` e agente sem
# `model:` no frontmatter (o frontmatter, quando há, vence o env). Este hook só:
# - corrige `Plan` para opus e `Explore` para haiku (papel fixo): devolve a
#   chamada reescrita (updatedInput) em vez de recusar — o Explore sem `model`
#   rodaria no modelo da sessão, e o env não o alcança;
# - recusa `model` fora de haiku|sonnet|opus (fable, `inherit`, ID completo): os
#   aliases são os que o padrão fixa na família 5.5;
# - deixa o `fork` passar (roda no modelo da sessão e ignora `model`).
#
# Sem jq não dá para reescrever a chamada: Plan/Explore fora do modelo são
# recusados com o modelo certo na mensagem. Os campos saem por regex: dentro de
# `prompt` as aspas vêm escapadas (\"model\"), então só as chaves de verdade casam.
entrada=$(cat)
tem_jq() { command -v jq >/dev/null 2>&1; }

campo() {
  if tem_jq; then
    printf '%s' "$entrada" | jq -r ".tool_input.$1 // \"\""
  else
    printf '%s' "$entrada" | tr '\n' ' ' |
      sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]*)\".*/\\1/p" | head -n 1
  fi
}

nega() {
  r=$(printf '%s' "$1" | tr -d '"\\')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$r"
  exit 0
}

tipo=$(campo subagent_type)
modelo=$(campo model)
[ "$tipo" = fork ] && exit 0

case "$tipo" in
  Plan) exigido=opus ;;
  Explore) exigido=haiku ;;
  *) exigido= ;;
esac
if [ -n "$exigido" ]; then
  [ "$modelo" = "$exigido" ] && exit 0
  tem_jq || nega "O subagent '$tipo' roda em model=$exigido (papel fixo): chame de novo com model=$exigido."
  printf '%s' "$entrada" | jq -c --arg m "$exigido" --arg t "$tipo" '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: ("padrao: \($t) travado em model=\($m)"),
    updatedInput: (.tool_input + {model: $m}),
    additionalContext: ("padrao: o subagent \($t) roda em model=\($m) (papel fixo); a chamada foi corrigida.")}}'
  exit 0
fi

case "$modelo" in "" | haiku | sonnet | opus) exit 0 ;; esac
nega "model='$modelo' fora da politica. Use opus (decidir, planejar, o dificil), sonnet (executar plano ja montado, revisar diff) ou haiku (coletar: busca, leitura, log); sem model o subagent roda em sonnet. Detalhes em docs/agente/padrao-modelos.md."
