#!/usr/bin/env bash
# Confere as decisões dos hooks do plugin. Cada caso é "esperado<TAB>entrada";
# PASSA = o hook fica calado. Sai 0 só se tudo conferir.
#
#   scripts/testar.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
command -v jq >/dev/null || { echo "jq ausente"; exit 1; }
D=scripts

FALHAS=0
# rodar HOOK MODO: MODO=cmd embrulha a linha em {tool_input:{command}}; MODO=raw usa a linha como está.
rodar() {
  local hook="$1" modo="$2" esperado entrada saida obtido
  while IFS=$'\t' read -r esperado entrada; do
    [ -n "$esperado" ] || continue
    if [ "$modo" = cmd ]; then
      saida=$(printf '%s' "$entrada" | jq -Rs '{tool_input:{command:.}}' | sh "$D/$hook")
    else
      saida=$(printf '%s' "$entrada" | sh "$D/$hook")
    fi
    obtido=$(printf '%s' "$saida" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
    obtido=${obtido:-PASSA}
    if [ "$obtido" != "$esperado" ]; then
      echo "divergiu: $hook: esperado $esperado, veio $obtido - $entrada"
      FALHAS=$((FALHAS + 1))
    fi
  done
}

# Subagent sem model segue (o CLAUDE_CODE_SUBAGENT_MODEL do padrão o põe em
# sonnet); Plan/Explore fora do modelo são corrigidos (allow + updatedInput);
# model fora de haiku|sonnet|opus é recusado.
rodar escolher-modelo-subagente.sh raw <<'CASOS'
PASSA	{"tool_input":{"prompt":"x","model":"haiku"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"general-purpose","model":"sonnet"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"Explore","model":"haiku"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"Plan","model":"opus"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"fork"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"fork","model":"fable"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"padrao:coletor"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"padrao:executor"}}
PASSA	{"tool_input":{"prompt":"usa \"model\": \"opus\" aqui","subagent_type":"general-purpose"}}
PASSA	{"tool_input":{"prompt":"x"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"Explore"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"Explore","model":"sonnet"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"Plan","model":"haiku"}}
deny	{"tool_input":{"prompt":"x","model":"fable"}}
deny	{"tool_input":{"prompt":"x","model":"inherit"}}
deny	{"tool_input":{"prompt":"x","subagent_type":"general-purpose","model":"claude-opus-5-5"}}
CASOS

# A correção mantém o resto da chamada e só troca o model.
corrigida=$(printf '%s' '{"tool_input":{"prompt":"p","description":"d","subagent_type":"Explore","model":"opus"}}' |
  sh "$D/escolher-modelo-subagente.sh" | jq -c '.hookSpecificOutput.updatedInput')
[ "$corrigida" = '{"prompt":"p","description":"d","subagent_type":"Explore","model":"haiku"}' ] ||
  { echo "divergiu: Explore corrigido para $corrigida"; FALHAS=$((FALHAS + 1)); }

rodar coletor-so-le.sh raw <<'CASOS'
PASSA	{"agent_type":"Explore","tool_name":"Bash","tool_input":{"command":"grep -rn x src | head"}}
PASSA	{"agent_type":"padrao:revisor","tool_name":"Bash","tool_input":{"command":"git diff HEAD"}}
PASSA	{"agent_type":"general-purpose","tool_name":"PowerShell","tool_input":{"command":"Set-Content f x"}}
deny	{"agent_type":"Explore","tool_name":"PowerShell","tool_input":{"command":"Get-Content f"}}
deny	{"agent_type":"padrao:coletor","tool_name":"Bash","tool_input":{"command":"touch f"}}
deny	{"agent_type":"padrao:leitor","tool_name":"Bash","tool_input":{"command":"touch f"}}
PASSA	{"agent_type":"padrao:leitor","tool_name":"Bash","tool_input":{"command":"git log --oneline -5"}}
PASSA	{"tool_input":{"command":"touch f"}}
PASSA	{"agent_type":"general-purpose","tool_input":{"command":"touch f"}}
PASSA	{"agent_type":"revisor","tool_name":"Bash","tool_input":{"command":"touch f"}}
PASSA	{"agent_type":"Explore","tool_input":{"command":"git log --oneline -5"}}
deny	{"agent_type":"Explore","tool_input":{"command":"grep x src > /tmp/x"}}
deny	{"agent_type":"Explore","tool_input":{"command":"touch f"}}
deny	{"agent_type":"Explore","tool_input":{"command":"git commit -m x"}}
CASOS

rodar so-le.sh cmd <<'CASOS'
PASSA	git diff HEAD
PASSA	git diff --stat origin/main...HEAD 2>&1
PASSA	grep -rn "a|b" apps | head
PASSA	sed -n 1,20p x.py; echo ----; git show HEAD:x
PASSA	git log --oneline -5 >/dev/null
deny	git commit -m x
deny	git add .
deny	git diff --output=x
deny	touch f
deny	echo x > f
deny	sed -i s/a/b/ f
deny	FOO=1 git diff
deny	cat $(rm -rf x)
deny	find . -delete
deny	bash -c "git diff"
PASSA	sort -n x | uniq -c
PASSA	uniq x
PASSA	sed -E 's/a/b/g' x
PASSA	sed -n '/^e /p' x
PASSA	awk '{print $1}' x
PASSA	rg -n foo src
PASSA	git -C sub log --oneline
PASSA	find . -name '*.py' -newer x
deny	sort -o saida x
deny	sort -no saida x
deny	sort --compress-program=./evil x
deny	uniq x saida
deny	sed -n 's/a/b/w saida' x
deny	sed 's/a/b/gw saida' x
deny	sed '1,5w saida' x
deny	sed 'e touch f' x
deny	sed -E -i s/a/b/ x
deny	awk 'BEGIN{"touch f" | getline}'
deny	awk 'BEGIN{print "x" | "sh"}'
deny	awk -f prog.awk x
deny	rg --pre ./evil x
deny	git -c core.fsmonitor=./evil status
deny	git -c diff.external=./evil diff
deny	git --config-env=core.pager=X log
deny	git grep -O./evil x
deny	git grep --open-files-in-pager=./evil x
deny	git diff --ext-diff
deny	find . -fls saida
deny	find . -fprintf saida %p
deny	file -C -m magia
CASOS

# Sem jq: o coletor é negado; os demais seguem; o hook de modelo cai na regex.
# PATH sem jq: tira as pastas que têm jq; se o sh sumir junto (Linux, tudo em
# /usr/bin), monta uma pasta de symlinks só com o que os hooks usam.
SEMJQ_PATH=$(printf '%s' "$PATH" | tr ':' '
' | while IFS= read -r d; do
  [ -x "$d/jq" ] || [ -x "$d/jq.exe" ] || printf '%s:' "$d"; done)
SEMJQ=
if ! PATH="$SEMJQ_PATH" command -v sh >/dev/null 2>&1; then
  SEMJQ=$(mktemp -d)
  for b in sh cat grep sed tr head find awk dirname printf cut; do
    ln -s "$(command -v "$b")" "$SEMJQ/$b"
  done
  SEMJQ_PATH=$SEMJQ
fi
semjq() { printf '%s' "$2" | PATH="$SEMJQ_PATH" sh "$D/$1" | grep -o '"permissionDecision":"[a-z]*"' | cut -d'"' -f4; }
confere() { [ "${3:-PASSA}" = "$1" ] || { echo "divergiu (sem jq): esperado $1, veio ${3:-PASSA} - $2"; FALHAS=$((FALHAS + 1)); }; }
for caso in 'deny|coletor-so-le.sh|{"agent_type":"Explore","tool_input":{"command":"ls"}}'   'PASSA|coletor-so-le.sh|{"agent_type":"general-purpose","tool_input":{"command":"touch f"}}'   'PASSA|escolher-modelo-subagente.sh|{"tool_input":{"prompt":"x","subagent_type":"Explore","model":"haiku"}}'   'PASSA|escolher-modelo-subagente.sh|{"tool_input":{"prompt":"x \"model\": \"opus\""}}'   'deny|escolher-modelo-subagente.sh|{"tool_input":{"prompt":"x","subagent_type":"Explore"}}'   'deny|escolher-modelo-subagente.sh|{"tool_input":{"prompt":"x","subagent_type":"Plan","model":"sonnet"}}'; do
  esperado=${caso%%|*}; resto=${caso#*|}; hook=${resto%%|*}; entrada=${resto#*|}
  confere "$esperado" "$hook $entrada" "$(semjq "$hook" "$entrada")"
done
[ -z "$SEMJQ" ] || rm -rf "$SEMJQ"

# Guarda do global: HOME e projeto falsos.
CASA=$(mktemp -d); PROJ=$(mktemp -d)
mkdir -p "$CASA/.claude" "$PROJ/.claude"
cp skills/aplicar/modelos/settings.json "$PROJ/.claude/settings.json"
cp skills/aplicar/modelos/settings.local.json "$PROJ/.claude/settings.local.json"
cp skills/aplicar/modelos/global.json "$CASA/.claude/settings.json"
cp statusline/statusline.py statusline/subagent-statusline.py "$CASA/.claude/"
mkdir -p "$CASA/.claude/skills/synced/x" "$CASA/.claude/skills/.trash/1-x/morning"
guarda() { printf '{}' | HOME="$CASA" CLAUDE_PROJECT_DIR="$PROJ" sh "$D/guarda-global.sh"; }
[ -z "$(guarda)" ] || { echo "divergiu: guarda-global acusou um ambiente limpo: $(guarda)"; FALHAS=$((FALHAS + 1)); }
jq '.fallbackModel = [] | .modelSettings["claude-sonnet-5-5"].effortLevel = "high" | del(.env.ANTHROPIC_DEFAULT_HAIKU_MODEL) | del(.extraKnownMarketplaces["claude-padrao"].autoUpdate) | del(.disableClaudeAiConnectors) | del(.env.CLAUDE_CODE_SUBAGENT_MODEL)' "$PROJ/.claude/settings.json" >"$PROJ/s" && mv "$PROJ/s" "$PROJ/.claude/settings.json"
jq '. + {model: "opus", fallbackModel: []}' "$CASA/.claude/settings.json" >"$CASA/s" && mv "$CASA/s" "$CASA/.claude/settings.json"
mkdir -p "$CASA/.claude/projects/$(printf '%s' "$PROJ" | sed 's/[^A-Za-z0-9]/-/g')/memory" && touch "$CASA/.claude/projects/$(printf '%s' "$PROJ" | sed 's/[^A-Za-z0-9]/-/g')/memory/MEMORY.md"
printf '# velha\n' >"$CASA/.claude/statusline.py"
mkdir -p "$CASA/.claude/skills/minha"
# marketplace com versão mais nova que a instalada
mkdir -p "$CASA/.claude/plugins/marketplaces/claude-padrao/.claude-plugin"
printf '{"version":"0.9.0"}' >"$CASA/.claude/plugins/marketplaces/claude-padrao/.claude-plugin/plugin.json"
jq '.fallbackModel = "x" | del(.syncClaudeAiPlugins)' "$PROJ/.claude/settings.local.json" >"$PROJ/s" &&
  mv "$PROJ/s" "$PROJ/.claude/settings.local.json"
saida=$(guarda | jq -r .systemMessage)
for esperado in "chaves fora do padrao: fallbackModel, model" "statusline.py ausente ou diferente" "fallbackModel em .claude/settings.local.json" "fallbackModel em .claude/settings.json" "modelSettings[\"claude-sonnet-5-5\"].effortLevel do projeto e 'high', o padrao e 'medium'" "memoria deste projeto" "env.ANTHROPIC_DEFAULT_HAIKU_MODEL do projeto e ''" "env.CLAUDE_CODE_SUBAGENT_MODEL do projeto e ''" "atualizacao automatica do padrao desligada" "0.9.0 disponivel" "conectores MCP do claude.ai ligados" "plugins do app (claude.ai) sincronizados" "skills tem skills pessoais"; do
  case "$saida" in *"$esperado"*) ;; *) echo "divergiu: guarda-global nao acusou '$esperado'"; FALHAS=$((FALHAS + 1)) ;; esac
done
rm -rf "$CASA" "$PROJ"

# Status line principal: o padrão na linha 1 (vermelho = \033[31m).
SL=statusline/statusline.py
# no Git Bash o mktemp devolve /tmp/...; o Claude Code passa caminho do Windows
nativo() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
PADRAO_DIR=$(nativo "$(mktemp -d)"); mkdir -p "$PADRAO_DIR/.claude"
cp skills/aplicar/modelos/settings.json "$PADRAO_DIR/.claude/settings.json"
SOLTA=$(nativo "$(mktemp -d)")
linha1() {  # linha1 ID JANELA EFFORT PASTA
  printf '{"model":{"id":"%s","display_name":"M"},"context_window":{"context_window_size":%s},"effort":{"level":"%s"},"workspace":{"current_dir":"%s","project_dir":"%s"}}' \
    "$1" "$2" "$3" "$4" "$4" | COLUMNS=120 sh "$D/py.sh" "$SL" | head -n 1
}
confere_sl() {  # confere_sl DESCRICAO SAIDA PADRAO_ESPERADO(s/n)
  case "$2" in *"$3"*) [ "$4" = s ] && return ;; *) [ "$4" = n ] && return ;; esac
  echo "divergiu: statusline: $1"; FALHAS=$((FALHAS + 1))
}
VERM=$(printf '\033[31m')
confere_sl "no padrao, nada vermelho" "$(linha1 claude-opus-5-5 1000000 medium "$PADRAO_DIR")" "$VERM" n
confere_sl "no padrao, sem marca" "$(linha1 claude-opus-5-5 1000000 medium "$PADRAO_DIR")" "sem padrão" n
confere_sl "sonnet na principal = vermelho" "$(linha1 claude-sonnet-5-5 1000000 medium "$PADRAO_DIR")" "${VERM}M" s
confere_sl "janela 200k = vermelho" "$(linha1 claude-opus-5-5 200000 medium "$PADRAO_DIR")" "${VERM}M" s
confere_sl "effort high = vermelho" "$(linha1 claude-opus-5-5 1000000 high "$PADRAO_DIR")" "${VERM}high" s
confere_sl "pasta solta = sem padrao" "$(linha1 claude-opus-5-5 1000000 medium "$SOLTA")" "sem padrão" s
rm -rf "$PADRAO_DIR" "$SOLTA"
jq -e '.statusLine.refreshInterval >= 1' skills/aplicar/modelos/global.json >/dev/null ||
  { echo "divergiu: global.json sem statusLine.refreshInterval"; FALHAS=$((FALHAS + 1)); }

# Status line dos subagents: uma linha JSON por task; 5.5 na cor da família,
# fora da 5.5 em vermelho (\033[31m).
saida=$(printf '%s' '{"columns":80,"tasks":[{"id":"a","agentType":"padrao:coletor","status":"running","description":"x","startTime":0,"model":"claude-haiku-5-5","contextWindowSize":1000000,"tokenCount":1000},{"id":"b","agentType":"velho","status":"running","description":"y","startTime":0,"model":"claude-sonnet-4-5","tokenCount":1}]}' |
  sh "$D/py.sh" statusline/subagent-statusline.py)
ok=$(printf '%s\n' "$saida" | jq -rs '[.[0].id == "a", (.[0].content | contains("Haiku 5.5")), (.[1].content | contains("\u001b[31mSonnet 4.5"))] | all')
[ "$ok" = true ] || { echo "divergiu: subagent-statusline: $saida"; FALHAS=$((FALHAS + 1)); }


if [ "$FALHAS" -eq 0 ]; then
  echo "hooks: todas as decisoes conferem"
  exit 0
fi
echo "hooks: $FALHAS decisao(oes) divergente(s)"
exit 1
