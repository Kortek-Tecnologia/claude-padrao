#!/bin/sh
# Política de modelos: Opus decide e faz o difícil, Sonnet executa lote com
# ficha fechada e revisa diff, Haiku coleta.
#
# Subagent sem `model` não herda o Opus: o CLAUDE_CODE_SUBAGENT_MODEL=sonnet do
# .claude/settings.json do padrão vale para chamada sem `model` e agente sem
# `model:` no frontmatter (o frontmatter, quando há, vence o env). Este hook só:
# - corrige `Plan` para opus, `Explore`, `padrao:coletor` e `padrao:leitor` para
#   haiku e `padrao:revisor` e `padrao:executor` para sonnet (papel fixo):
#   devolve a chamada reescrita (updatedInput) em vez de recusar — o Explore sem
#   `model` rodaria no modelo da sessão, e o env não o alcança; os agentes do
#   plugin sem `model` passam (o frontmatter já tem o modelo certo), mas o
#   `model` da chamada venceria o frontmatter;
# - recusa `model` fora de haiku|sonnet|opus (fable, mythos, `inherit`, ID
#   completo): os aliases são os que o padrão fixa na família 5.5; o Fable e o
#   Mythos são degrau de escalada da sessão (/model, só a sessão), não de subagent;
# - deixa o `fork` passar (roda no modelo da sessão e ignora `model`).
#
# Custo: no Windows abrir um processo custa de 100 a 800 ms. A entrada é lida
# pelo `read` do shell e um jq só tira os campos, decide e monta a saída (até a
# 2.16.0 eram um `cat` e de dois a três jq por chamada).
#
# Sem jq não dá para reescrever a chamada: os de papel fixo fora do modelo são
# recusados com o modelo certo na mensagem. Os campos saem por regex: dentro de
# `prompt` as aspas vêm escapadas (\"model\"), então só as chaves de verdade casam.
nl='
'
entrada=
while IFS= read -r linha || [ -n "$linha" ]; do entrada="$entrada$linha$nl"; done

if command -v jq >/dev/null 2>&1; then
  # Sem saída = a chamada segue. O jq que falha (entrada inválida) não devolve
  # nada, e a chamada segue, como antes.
  # ($q é a aspa simples, que não cabe no programa entre aspas simples do shell.)
  jq -c --arg q "'" '
    def negar(r): {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
      permissionDecisionReason: (r | gsub("[\"\\\\]"; ""))}};
    (.tool_input.subagent_type // "" | tostring) as $t
    | (.tool_input.model // "" | tostring) as $m
    | {Plan: "opus", Explore: "haiku", "padrao:coletor": "haiku", "padrao:leitor": "haiku",
       "padrao:revisor": "sonnet", "padrao:executor": "sonnet"}[$t] as $x
    | if $t == "fork" then empty
      elif $x then
        if $m == $x or ($m == "" and ($t | startswith("padrao:"))) then empty
        else {hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: ("padrao: \($t) travado em model=\($x)"),
          updatedInput: (.tool_input + {model: $x}),
          additionalContext: ("padrao: o subagent \($t) roda em model=\($x) (papel fixo); a chamada foi corrigida.")}}
        end
      elif $m == "" or $m == "haiku" or $m == "sonnet" or $m == "opus" then empty
      else negar("model=\($q)\($m)\($q) fora da politica. Use opus (decidir, planejar, o dificil), sonnet (executar lote com ficha fechada, revisar diff) ou haiku (coletar: busca, leitura, log); sem model o subagent roda em sonnet. Fable e Mythos so na sessao (/model, tecla s), nunca em subagent. Detalhes em docs/agente/padrao-modelos.md.")
      end' 2>/dev/null <<EOF
$entrada
EOF
  exit 0
fi

campo() {
  printf '%s' "$entrada" | tr '\n' ' ' |
    sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]*)\".*/\\1/p" | head -n 1
}

negar() {
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
  padrao:coletor | padrao:leitor) [ -z "$modelo" ] && exit 0; exigido=haiku ;;
  padrao:revisor | padrao:executor) [ -z "$modelo" ] && exit 0; exigido=sonnet ;;
  *) exigido= ;;
esac
if [ -n "$exigido" ]; then
  [ "$modelo" = "$exigido" ] && exit 0
  negar "O subagent '$tipo' roda em model=$exigido (papel fixo): chame de novo com model=$exigido."
fi

case "$modelo" in "" | haiku | sonnet | opus) exit 0 ;; esac
negar "model='$modelo' fora da politica. Use opus (decidir, planejar, o dificil), sonnet (executar lote com ficha fechada, revisar diff) ou haiku (coletar: busca, leitura, log); sem model o subagent roda em sonnet. Fable e Mythos so na sessao (/model, tecla s), nunca em subagent. Detalhes em docs/agente/padrao-modelos.md."
