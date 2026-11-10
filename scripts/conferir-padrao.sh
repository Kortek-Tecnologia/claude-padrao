#!/bin/sh
# SessionStart: confere se o padrão segue de pé e AVISA (não corrige sozinho).
# Roda em toda sessão e a 1ª resposta espera por ele: um jq para as settings e
# versões, outro para o ~/.claude.json (pode ser grande; não vai como argumento).
#
# 1. Modelos e env: `model`, `effortLevel`, todo campo que o modelo de
#    settings define em cada chave de `modelSettings` (effort; no Opus, o teto
#    de compactação `autoCompactWindow`) — campo ou modelo que só o projeto
#    tenha não conta — e as chaves de `env` do padrão (aliases dos subagents na
#    família 5.5, modelo de subagent sem `model`, memória desligada, subagent
#    sem subagent) do .claude/settings.json iguais aos de modelos/settings.json
#    (fonte única). `CLAUDE_CODE_DISABLE_AUTO_MEMORY` vence `autoMemoryEnabled`
#    nos dois sentidos: por isso basta conferir o env. Checkpoints ligados:
#    sem `CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING` (versões antigas o punham).
# 2. Global limpo: ~/.claude/settings.json só com permissions.defaultMode,
#    skipDangerousModePermissionPrompt, autoMemoryEnabled, statusLine e
#    subagentStatusLine (interface do terminal: vale em qualquer pasta,
#    inclusive no home), com os scripts em ~/.claude iguais aos do plugin; nada
#    de CLAUDE.md, agents, commands, skills, output-styles, rules ou workflows
#    em ~/.claude; nenhum MCP de escopo user nem local deste projeto no
#    ~/.claude.json; nenhuma memória deste projeto em ~/.claude/projects. O
#    `/model` grava no global — por isso o 2. O effort que o `/effort` salva
#    (`modelSettings` só com `effortLevel`, ou o `effortLevel` antigo) passa: o
#    `modelSettings` do projeto vence o do usuário, e toda sessão abre em medium.
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
# 6. Modelos em dia: o bloco do padrão no CLAUDE.md e os docs/agente/padrao-*.md
#    do projeto trazem o carimbo `modelo X` da 1ª linha do arquivo de
#    skills/aplicar/modelos de onde saíram. Compara só o carimbo, não o texto:
#    quem grava no projeto é o Claude, e espaço ou CRLF dariam aviso falso.
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
  # modelSettings que só guarda effort por modelo (o que o /effort grava)
  def so_effort: type == "object"
    and ([.[] | if type == "object" then keys[] else "?" end] - ["effortLevel"] | length) == 0;
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
      + ($M.modelSettings // {} | to_entries | map(.key as $m | .value
          | if type == "object" then keys else [] end
          | map(["modelSettings[\"\($m)\"].\(.)", ["modelSettings", $m, .]])) | add // [])
    )[]
    | .[1] as $c
    | ($M | getpath($c) | if . == null then "" else tostring end) as $quer
    # o `try`: `modelSettings` do projeto que não é objeto não pode derrubar o jq e calar o resto
    | (($P // {}) | (try getpath($c) catch null) | if . == null then "" else tostring end) as $tem
    | select($tem != $quer)
    | "\(.[0]) do projeto e '\''\($tem)'\'', o padrao e '\''\($quer)'\''"
  else empty end),
  (if $P and ($P.env // {} | has("CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING")) then
    "checkpoints (/rewind) desligados: tire env.CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING do .claude/settings.json" else empty end),
  (if $P and (($P.extraKnownMarketplaces["claude-padrao"].autoUpdate // false) != true) then
    "atualizacao automatica do padrao desligada (extraKnownMarketplaces.claude-padrao.autoUpdate no .claude/settings.json)" else empty end),
  (if $vi != "" and $vp != "" and $vi != $vp then
    "padrao \($vi) instalado, \($vp) disponivel: rode '\''claude plugin update padrao@claude-padrao --scope project'\'' e depois /reload-plugins" else empty end),
  (if $G then
    ((($G | keys) - ["permissions", "autoMemoryEnabled", "skipDangerousModePermissionPrompt", "statusLine", "subagentStatusLine", "effortLevel"]
        - (if ($G.modelSettings | so_effort) then ["modelSettings"] else [] end))
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
# carimbo ARQUIVO MARCA: o X de `modelo X` na 1ª linha do arquivo que casa com a
# marca. A marca vem ancorada no começo da linha: prosa do projeto que cite o
# marcador ("o bloco fica entre <!-- padrao:inicio e ...") não pode valer por ele.
carimbo() { sed -n "/$2/{s/.*modelo \([0-9][0-9.]*\).*/\1/p;q;}" "$1" 2>/dev/null; }
# maior A B: a versão A é maior que a B (campo a campo, numérico)
maior() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= (n > m ? n : m); i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 1 }'
}
em_dia() { # em_dia MODELO ARQUIVO_DO_PROJETO MARCA NOME_NO_AVISO
  quer=$(carimbo "$plugin/skills/aplicar/modelos/$1" "$3")
  [ -n "$quer" ] || return 0
  tem=$(carimbo "$raiz/$2" "$3")
  [ "$tem" = "$quer" ] && return 0
  # Carimbo do projeto mais novo: um colega aplicou com o plugin já atualizado e
  # esta sessão ainda roda o antigo — rodar o aplicar aqui rebaixaria o texto.
  if [ -n "$tem" ] && maior "$tem" "$quer"; then
    anota "$4 e de um modelo mais novo ('$tem') que o do plugin desta sessao ('$quer'): atualize o plugin em vez de rodar o /padrao:aplicar"
  else
    anota "$4 ausente ou de outro modelo do padrao (tem '${tem:-nenhum}', o plugin traz '$quer')"
  fi
}
em_dia claude-md.md CLAUDE.md '^<!-- padrao:inicio' "bloco do padrao no CLAUDE.md"
for doc in padrao-modelos.md padrao-configuracao.md; do
  em_dia "agente/$doc" "docs/agente/$doc" '^<!-- gerado pelo plugin padrao' "docs/agente/$doc"
done

for item in CLAUDE.md agents commands output-styles rules workflows; do
  [ -e "$g/$item" ] && [ -n "$(ls -A "$g/$item" 2>/dev/null)" ] && anota "~/.claude/$item existe"
done
# synced/ e as pastas ocultas (a .trash, lixeira do sync do claude.ai) sao estado do app
[ -n "$(ls -A "$g/skills" 2>/dev/null | grep -v -e '^synced$' -e '^\.')" ] && anota "~/.claude/skills tem skills pessoais"

chave_projeto=$(printf '%s' "$raiz" | sed 's/[^A-Za-z0-9]/-/g')
[ -n "$(ls -A "$g/projects/$chave_projeto/memory" 2>/dev/null)" ] &&
  anota "memoria deste projeto em ~/.claude/projects/$chave_projeto/memory"

if [ -r "$HOME/.claude.json" ]; then
  mcp=$(jq -r --arg c "$chave_projeto" '
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
