#!/bin/sh
# SessionStart: confere se o padrão segue de pé e AVISA (não corrige sozinho).
# Roda em toda sessão e a 1ª resposta espera por ele: um jq para as settings e
# versões, outro para o ~/.claude.json (pode ser grande; não vai como argumento).
#
# 1. Modelos e env: `model`, `effortLevel`, o effort de cada modelo
#    (modelSettings) e as chaves de `env` do padrão (aliases dos subagents na
#    família 5.5, modelo de subagent sem `model`, memória desligada, subagent
#    sem subagent) do .claude/settings.json iguais aos de modelos/settings.json
#    (fonte única). `CLAUDE_CODE_DISABLE_AUTO_MEMORY` vence `autoMemoryEnabled`
#    nos dois sentidos: por isso basta conferir o env.
# 2. Global limpo: ~/.claude/settings.json só com permissions.defaultMode,
#    skipDangerousModePermissionPrompt, autoMemoryEnabled, statusLine e
#    subagentStatusLine (interface do terminal: vale em qualquer pasta,
#    inclusive no home), com os scripts em ~/.claude iguais aos do plugin; nada
#    de CLAUDE.md, agents, commands, skills, output-styles, rules ou workflows
#    em ~/.claude; nenhum MCP de escopo user nem local deste projeto no
#    ~/.claude.json; nenhuma memória deste projeto em ~/.claude/projects. O
#    `/model` e o `/effort` gravam no global — por isso o 2.
# 3. Sem fallback: nenhum `fallbackModel` no settings.json nem no local.
# 4. Nada do app: `disableClaudeAiConnectors: true` no .claude/settings.json
#    (conectores MCP do claude.ai) e `syncClaudeAiPlugins: false` no
#    .claude/settings.local.json (plugins @synced da conta; o settings.json do
#    projeto não aceita essa chave).
# 5. Atualização: `autoUpdate` ligado no marketplace `claude-padrao` do projeto
#    (marketplace de terceiro vem desligado) e a versão instalada igual à do
#    clone do marketplace em ~/.claude/plugins/marketplaces/claude-padrao —
#    compara por diferença, não por ordem: a numeração recomeçou em 1.0.0 e um
#    projeto em 3.x tem de ser avisado da 1.0.0. O
#    auto-update roda até 10 min depois da 1ª mensagem e não troca a versão da
#    sessão aberta: daí o aviso com o comando e o /reload-plugins.
#
# Achou algo: avisa o usuário (systemMessage) e o Claude (additionalContext),
# apontando o /padrao:aplicar. Sem jq: silêncio.
cat >/dev/null
command -v jq >/dev/null 2>&1 || exit 0
raiz=${CLAUDE_PROJECT_DIR:-$(pwd)}
plugin="$(dirname "$0")/.."
g="$HOME/.claude"
le() { cat "$1" 2>/dev/null; }

achados=$(jq -rn \
  --arg proj "$(le "$raiz/.claude/settings.json")" \
  --arg local "$(le "$raiz/.claude/settings.local.json")" \
  --arg mod "$(le "$plugin/skills/aplicar/modelos/settings.json")" \
  --arg glob "$(le "$g/settings.json")" \
  --arg inst "$(le "$plugin/.claude-plugin/plugin.json")" \
  --arg pub "$(le "$g/plugins/marketplaces/claude-padrao/.claude-plugin/plugin.json")" '
  def obj: (try fromjson catch null) | if type == "object" then . else null end;
  ($proj | obj) as $P | ($local | obj) as $L | ($mod | obj) as $M | ($glob | obj) as $G
  | (($inst | obj) // {} | .version // "") as $vi
  | (($pub | obj) // {} | .version // "") as $vp
  | ([[$P, ".claude/settings.json"], [$L, ".claude/settings.local.json"]][]
    | select(.[0] != null and (.[0] | has("fallbackModel")))
    | "fallbackModel em \(.[1]) (o padrao e sem fallback: tire a chave)"),
  (if ($P.disableClaudeAiConnectors // false) != true then
    "conectores MCP do claude.ai ligados (disableClaudeAiConnectors: true no .claude/settings.json)" else empty end),
  (if ($L.syncClaudeAiPlugins | tostring) != "false" then
    "plugins do app (claude.ai) sincronizados (syncClaudeAiPlugins: false no .claude/settings.local.json)" else empty end),
  (if $M then
    ([["model", ["model"]], ["effortLevel", ["effortLevel"]]]
      + ($M.env // {} | keys | map(["env.\(.)", ["env", .]]))
      + ($M.modelSettings // {} | keys | map(["modelSettings[\"\(.)\"].effortLevel", ["modelSettings", ., "effortLevel"]]))
    )[]
    | .[1] as $c
    | (($M | getpath($c)) // "" | tostring) as $quer
    | ((($P // {}) | getpath($c)) // "" | tostring) as $tem
    | select($tem != $quer)
    | "\(.[0]) do projeto e '\''\($tem)'\'', o padrao e '\''\($quer)'\''"
  else empty end),
  (if $P and (($P.extraKnownMarketplaces["claude-padrao"].autoUpdate // false) != true) then
    "atualizacao automatica do padrao desligada (extraKnownMarketplaces.claude-padrao.autoUpdate no .claude/settings.json)" else empty end),
  (if $vi != "" and $vp != "" and $vi != $vp then
    "padrao \($vi) instalado, \($vp) disponivel: rode '\''claude plugin update padrao@claude-padrao --scope project'\'' e depois /reload-plugins" else empty end),
  (if $G then
    ((($G | keys) - ["permissions", "autoMemoryEnabled", "skipDangerousModePermissionPrompt", "statusLine", "subagentStatusLine"])
      + (($G.permissions // {}) | keys - ["defaultMode"] | map("permissions." + .))
    | select(length > 0) | "~/.claude/settings.json tem chaves fora do padrao: \(join(", "))")
  else empty end)
  ' 2>/dev/null | sed '/^$/d; s/^/- /')

anota() { achados="${achados:+$achados
}- $1"; }

for sl in statusline.py subagent-statusline.py; do
  orig="$plugin/statusline/$sl"
  if [ -r "$orig" ] && ! cmp -s "$orig" "$g/$sl"; then
    anota "~/.claude/$sl ausente ou diferente da do plugin"
  fi
done
for item in CLAUDE.md agents commands output-styles rules workflows; do
  [ -e "$g/$item" ] && [ -n "$(ls -A "$g/$item" 2>/dev/null)" ] && anota "~/.claude/$item existe"
done
# synced/ e as pastas ocultas (a .trash, lixeira do sync do claude.ai) sao estado do app
[ -n "$(ls -A "$g/skills" 2>/dev/null | grep -v -e '^synced$' -e '^\.')" ] && anota "~/.claude/skills tem skills pessoais"

chave=$(printf '%s' "$raiz" | sed 's/[^A-Za-z0-9]/-/g')
[ -n "$(ls -A "$g/projects/$chave/memory" 2>/dev/null)" ] &&
  anota "memoria deste projeto em ~/.claude/projects/$chave/memory"

if [ -r "$HOME/.claude.json" ]; then
  mcp=$(jq -r --arg c "$chave" '
    ((.mcpServers // {}) | keys | map("user:" + .)) +
    ((.projects // {}) | to_entries
      | map(select((.key | gsub("[^A-Za-z0-9]"; "-")) == $c))
      | map(.value.mcpServers // {} | keys | map("local:" + .)) | add // [])
    | join(", ")' "$HOME/.claude.json" 2>/dev/null)
  [ -n "$mcp" ] && anota "MCP fora do projeto (~/.claude.json): $mcp"
fi

[ -n "$achados" ] || exit 0
texto="Padrao fora do lugar:
${achados}
Rode /padrao:aplicar para levar ao projeto e limpar o global."
jq -cn --arg t "$texto" '{systemMessage: $t, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}'
