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
# sonnet); Plan, Explore e os agentes do plugin com outro model são corrigidos
# (allow + updatedInput); model fora de haiku|sonnet|opus é recusado.
rodar travar-modelo-subagent.sh raw <<'CASOS'
PASSA	{"tool_input":{"prompt":"x","model":"haiku"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"general-purpose","model":"sonnet"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"Explore","model":"haiku"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"Plan","model":"opus"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"fork"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"fork","model":"fable"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"padrao:coletor"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"padrao:leitor","model":"haiku"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"padrao:coletor","model":"sonnet"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"padrao:leitor","model":"opus"}}
PASSA	{"tool_input":{"prompt":"x","subagent_type":"padrao:revisor","model":"sonnet"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"padrao:revisor","model":"opus"}}
allow	{"tool_input":{"prompt":"x","subagent_type":"padrao:executor","model":"haiku"}}
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
  sh "$D/travar-modelo-subagent.sh" | jq -c '.hookSpecificOutput.updatedInput')
[ "$corrigida" = '{"prompt":"p","description":"d","subagent_type":"Explore","model":"haiku"}' ] ||
  { echo "divergiu: Explore corrigido para $corrigida"; FALHAS=$((FALHAS + 1)); }
# A recusa do fable diz onde ele vale (o medir reconhece a recusa por "fora da politica").
printf '%s' '{"tool_input":{"prompt":"x","model":"fable"}}' | sh "$D/travar-modelo-subagent.sh" |
  jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -q 'fora da politica.*Fable so na sessao' ||
  { echo "divergiu: recusa do fable sem o texto esperado"; FALHAS=$((FALHAS + 1)); }

rodar trava-leitura.sh raw <<'CASOS'
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
deny	{"agent_type":"Explore","tool_name":"mcp__github__create_issue","tool_input":{"title":"x"}}
deny	{"agent_type":"padrao:coletor","tool_name":"Monitor","tool_input":{"command":"touch f"}}
deny	{"agent_type":"Explore","tool_name":"Workflow","tool_input":{"script":"x"}}
PASSA	{"agent_type":"general-purpose","tool_name":"mcp__github__create_issue","tool_input":{"title":"x"}}
PASSA	{"tool_name":"mcp__github__create_issue","tool_input":{"title":"x"}}
CASOS

rodar so-le.sh cmd <<'CASOS'
PASSA	git diff HEAD
PASSA	git diff --stat origin/main...HEAD 2>&1
PASSA	grep -rn "a|b" apps | head
PASSA	sed --sandbox -n 1,20p x.py; echo ----; git show HEAD:x
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
PASSA	sed --sandbox -E 's/a/b/g' x
PASSA	sed --sandbox -n '/^e /p' x
PASSA	awk --sandbox '{print $1}' x
PASSA	awk --sandbox -F: -v n=1 '{print $n}' x
PASSA	awk --sandbox 'BEGIN{f="sys" "tem"; @f("touch f")}'
PASSA	ls >/dev/null; echo ok
PASSA	git log -1 2>/dev/null | head
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
deny	sed -n 1,20p x
deny	echo 'touch f' | sed 's#^##e'
deny	sed 's|a|b|w saida' x
deny	sed -f script.sed x
deny	sed -- --sandbox 's#^##e' x
deny	sed --sandbox -i s/a/b/ x
deny	sed --sandbox -n -i p x
deny	awk '{print $1}' x
deny	awk 'BEGIN{f="sys" "tem"; @f("touch f")}'
deny	awk '@load "rwarray"; BEGIN{writea("saida", a)}'
deny	awk --sandbox -dsaida 'BEGIN{}'
deny	awk --sandbox -o saida 'BEGIN{}'
deny	awk --sandbox --profile=saida 'BEGIN{}'
deny	cat x >/dev/nullX
deny	cat x >/dev/null/../f
deny	git --git-dir=x log
deny	git --work-tree=x status
deny	rg --hostname-bin=./evil x
CASOS

# O --sandbox segura de verdade o que a trava deixa passar com ele (GNU sed e
# gawk; o mawk recusa a opção, e também não grava).
LAB=$(mktemp -d)
(
  cd "$LAB" && printf 'touch pwned\n' >x
  sed --sandbox -n 's#^##e' x
  sed --sandbox 's|t|t|w saida' x
  awk --sandbox 'BEGIN{f="sys" "tem"; @f("touch pwned")}'
  awk --sandbox '@load "rwarray"; BEGIN{a[1]=1; writea("saida", a)}'
) >/dev/null 2>&1
[ "$(ls "$LAB")" = x ] || { echo "divergiu: --sandbox deixou gravar: $(ls "$LAB" | tr '\n' ' ')"; FALHAS=$((FALHAS + 1)); }
rm -rf "$LAB"

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
for caso in 'deny|trava-leitura.sh|{"agent_type":"Explore","tool_input":{"command":"ls"}}'   'PASSA|trava-leitura.sh|{"agent_type":"general-purpose","tool_input":{"command":"touch f"}}'   'PASSA|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"Explore","model":"haiku"}}'   'PASSA|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x \"model\": \"opus\""}}'   'deny|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"Explore"}}'   'deny|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"Plan","model":"sonnet"}}'   'PASSA|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"padrao:coletor"}}'   'deny|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"padrao:leitor","model":"sonnet"}}'   'deny|travar-modelo-subagent.sh|{"tool_input":{"prompt":"x","subagent_type":"padrao:executor","model":"opus"}}'; do
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
# o bloco e os docs gerados, com o carimbo do modelo; o CLAUDE.md em CRLF (checkout
# do Windows), com texto do projeto em volta e com prosa que cita o marcador antes
# do bloco não pode dar aviso falso
mkdir -p "$PROJ/docs/agente"
cp skills/aplicar/modelos/agente/padrao-*.md "$PROJ/docs/agente/"
{ printf '# Projeto\n\nO bloco do plugin fica entre `<!-- padrao:inicio` e `<!-- padrao:fim -->`.\n\n'
  cat skills/aplicar/modelos/claude-md.md; } | sed 's/$/\r/' >"$PROJ/CLAUDE.md"
mkdir -p "$CASA/.claude/skills/synced/x" "$CASA/.claude/skills/.trash/1-x/morning"
# o effort que o /effort salva no global não conta: o projeto vence ao abrir
jq '. + {effortLevel: "high", modelSettings: {"claude-opus-5-5": {effortLevel: "xhigh"}}}' "$CASA/.claude/settings.json" >"$CASA/s" && mv "$CASA/s" "$CASA/.claude/settings.json"
conferir() { printf '{}' | HOME="$CASA" CLAUDE_PROJECT_DIR="$PROJ" sh "$D/conferir-padrao.sh"; }
# modelo ou campo de modelSettings que só o projeto tem não conta
jq '.modelSettings["claude-opus-5-5"].extra = 1 | .modelSettings["outro-modelo"] = {effortLevel: "high"}' "$PROJ/.claude/settings.json" >"$PROJ/s" && mv "$PROJ/s" "$PROJ/.claude/settings.json"
[ -z "$(conferir)" ] || { echo "divergiu: conferir-padrao acusou um ambiente limpo: $(conferir)"; FALHAS=$((FALHAS + 1)); }
jq '.fallbackModel = [] | .modelSettings["claude-sonnet-5-5"].effortLevel = "high" | .modelSettings["claude-opus-5-5"].autoCompactWindow = 200000 | del(.env.ANTHROPIC_DEFAULT_HAIKU_MODEL) | del(.extraKnownMarketplaces["claude-padrao"].autoUpdate) | del(.disableClaudeAiConnectors) | del(.env.CLAUDE_CODE_SUBAGENT_MODEL) | .env.CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING = "1"' "$PROJ/.claude/settings.json" >"$PROJ/s" && mv "$PROJ/s" "$PROJ/.claude/settings.json"
# modelSettings com mais que effort já é configuração no global
jq '. + {model: "opus", fallbackModel: []} | .modelSettings["claude-opus-5-5"].autoCompactWindow = 100000' "$CASA/.claude/settings.json" >"$CASA/s" && mv "$CASA/s" "$CASA/.claude/settings.json"
mkdir -p "$CASA/.claude/projects/$(printf '%s' "$PROJ" | sed 's/[^A-Za-z0-9]/-/g')/memory" && touch "$CASA/.claude/projects/$(printf '%s' "$PROJ" | sed 's/[^A-Za-z0-9]/-/g')/memory/MEMORY.md"
printf '# velha\n' >"$CASA/.claude/statusline.py"
mkdir -p "$CASA/.claude/skills/minha"
# marketplace com versão mais nova que a instalada
mkdir -p "$CASA/.claude/plugins/marketplaces/claude-padrao/.claude-plugin"
printf '{"version":"0.9.0"}' >"$CASA/.claude/plugins/marketplaces/claude-padrao/.claude-plugin/plugin.json"
jq '.fallbackModel = "x" | del(.syncClaudeAiPlugins)' "$PROJ/.claude/settings.local.json" >"$PROJ/s" &&
  mv "$PROJ/s" "$PROJ/.claude/settings.local.json"
# modelos antigos: bloco de outro carimbo, doc gerado antes do carimbo, doc ausente
sed 's/modelo [0-9][0-9.]*/modelo 0.9.0/' skills/aplicar/modelos/claude-md.md >"$PROJ/CLAUDE.md"
printf '<!-- gerado pelo plugin padrao (/padrao:aplicar); edite no plugin, não aqui -->\n' >"$PROJ/docs/agente/padrao-modelos.md"
rm "$PROJ/docs/agente/padrao-configuracao.md"
saida=$(conferir | jq -r .systemMessage)
for esperado in "bloco do padrao no CLAUDE.md ausente ou de outro modelo do padrao (tem '0.9.0'" "docs/agente/padrao-modelos.md ausente ou de outro modelo do padrao (tem 'nenhum'" "docs/agente/padrao-configuracao.md ausente ou de outro modelo" "chaves fora do padrao: fallbackModel, model, modelSettings" "checkpoints (/rewind) desligados" "statusline.py ausente ou diferente" "fallbackModel em .claude/settings.local.json" "fallbackModel em .claude/settings.json" "modelSettings[\"claude-sonnet-5-5\"].effortLevel do projeto e 'high', o padrao e 'medium'" "modelSettings[\"claude-opus-5-5\"].autoCompactWindow do projeto e '200000', o padrao e '400000'" "memoria deste projeto" "env.ANTHROPIC_DEFAULT_HAIKU_MODEL do projeto e ''" "env.CLAUDE_CODE_SUBAGENT_MODEL do projeto e ''" "atualizacao automatica do padrao desligada" "0.9.0 disponivel" "conectores MCP do claude.ai ligados" "plugins do app (claude.ai) sincronizados" "skills tem skills pessoais"; do
  case "$saida" in *"$esperado"*) ;; *) echo "divergiu: conferir-padrao nao acusou '$esperado'"; FALHAS=$((FALHAS + 1)) ;; esac
done
# bloco de modelo MAIS NOVO que o do plugin da sessão: manda atualizar o plugin, não o aplicar
sed 's/modelo [0-9][0-9.]*/modelo 99.0.0/' skills/aplicar/modelos/claude-md.md >"$PROJ/CLAUDE.md"
saida=$(conferir | jq -r .systemMessage)
case "$saida" in *"CLAUDE.md e de um modelo mais novo ('99.0.0')"*) ;; *) echo "divergiu: conferir-padrao nao tratou o carimbo mais novo"; FALHAS=$((FALHAS + 1)) ;; esac
case "$saida" in *"CLAUDE.md ausente ou de outro modelo"*) echo "divergiu: carimbo mais novo tratado como antigo"; FALHAS=$((FALHAS + 1)) ;; esac
# projeto sem CLAUDE.md
rm "$PROJ/CLAUDE.md"
case "$(conferir | jq -r .systemMessage)" in *"bloco do padrao no CLAUDE.md ausente ou de outro modelo do padrao (tem 'nenhum'"*) ;; *) echo "divergiu: conferir-padrao nao acusou o CLAUDE.md ausente"; FALHAS=$((FALHAS + 1)) ;; esac
# teto ausente no projeto: acusado com o valor vazio
jq 'del(.modelSettings["claude-opus-5-5"].autoCompactWindow)' skills/aplicar/modelos/settings.json >"$PROJ/.claude/settings.json"
case "$(conferir | jq -r .systemMessage)" in *"modelSettings[\"claude-opus-5-5\"].autoCompactWindow do projeto e '', o padrao e '400000'"*) ;; *) echo "divergiu: conferir-padrao nao acusou o teto ausente"; FALHAS=$((FALHAS + 1)) ;; esac
# modelSettings do projeto que não é objeto: acusa campo a campo e NÃO cala os avisos seguintes
jq '.modelSettings = "x"' skills/aplicar/modelos/settings.json >"$PROJ/.claude/settings.json"
case "$(conferir | jq -r .systemMessage)" in *"modelSettings[\"claude-sonnet-5-5\"].effortLevel do projeto e ''"*"chaves fora do padrao"*) ;; *) echo "divergiu: modelSettings que nao e objeto calou o hook"; FALHAS=$((FALHAS + 1)) ;; esac
rm -rf "$CASA" "$PROJ"

# Carimbo dos modelos: o hook de abertura compara só o `modelo X` da 1ª linha.
# Mudou o texto de um modelo: suba o carimbo dele para a versão do plugin e
# registre a soma aqui — sem isso, o projeto com o texto velho não é avisado.
while read -r arq carimbo soma; do
  tem_c=$(sed -n '1s/.*modelo \([0-9][0-9.]*\).*/\1/p' "skills/aplicar/modelos/$arq")
  tem_s=$(tail -n +2 "skills/aplicar/modelos/$arq" | cksum | cut -d' ' -f1)
  [ "$tem_c $tem_s" = "$carimbo $soma" ] ||
    { echo "divergiu: modelo $arq mudou (carimbo '$tem_c', soma $tem_s): suba o 'modelo X' da 1a linha e registre os dois em testar.sh"; FALHAS=$((FALHAS + 1)); }
done <<'CARIMBOS'
claude-md.md 2.1.0 2511660356
agente/padrao-modelos.md 2.1.0 3490513551
agente/padrao-configuracao.md 2.1.0 1073251858
CARIMBOS

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
VERM=$(printf '\033[31m'); AMAR=$(printf '\033[33m')
confere_sl "no padrao, nada vermelho" "$(linha1 claude-opus-5-5 1000000 medium "$PADRAO_DIR")" "$VERM" n
confere_sl "no padrao, sem marca" "$(linha1 claude-opus-5-5 1000000 medium "$PADRAO_DIR")" "sem padrão" n
confere_sl "sonnet na principal = vermelho" "$(linha1 claude-sonnet-5-5 1000000 medium "$PADRAO_DIR")" "${VERM}M" s
confere_sl "janela 200k = vermelho" "$(linha1 claude-opus-5-5 200000 medium "$PADRAO_DIR")" "${VERM}M" s
# o Fable 5.2 é degrau de escalada da sessão: amarelo, como o effort fora de medium
confere_sl "fable na principal = amarelo" "$(linha1 claude-fable-5-2 1000000 medium "$PADRAO_DIR")" "${AMAR}M" s
confere_sl "fable 5.1 = vermelho" "$(linha1 claude-fable-5-1 1000000 medium "$PADRAO_DIR")" "${VERM}M" s
# effort fora de medium é ajuste da sessão (a próxima abre em medium): amarelo
confere_sl "effort high = amarelo" "$(linha1 claude-opus-5-5 1000000 high "$PADRAO_DIR")" "${AMAR}high" s
confere_sl "effort high nao e vermelho" "$(linha1 claude-opus-5-5 1000000 high "$PADRAO_DIR")" "$VERM" n
confere_sl "pasta solta = sem padrao" "$(linha1 claude-opus-5-5 1000000 medium "$SOLTA")" "sem padrão" s
rm -rf "$PADRAO_DIR" "$SOLTA"
jq -e '.statusLine.refreshInterval >= 1' skills/aplicar/modelos/global.json >/dev/null ||
  { echo "divergiu: global.json sem statusLine.refreshInterval"; FALHAS=$((FALHAS + 1)); }

# Status line dos subagents: uma linha JSON por task; os modelos que o padrão
# fixa (5.5 e Fable 5.2) na cor da família, o resto em vermelho (\033[31m).
saida=$(printf '%s' '{"columns":80,"tasks":[{"id":"a","agentType":"padrao:coletor","status":"running","description":"x","startTime":0,"model":"claude-haiku-5-5","contextWindowSize":1000000,"tokenCount":1000},{"id":"b","agentType":"velho","status":"running","description":"y","startTime":0,"model":"claude-sonnet-4-5","tokenCount":1},{"id":"c","agentType":"fork","status":"running","description":"z","startTime":0,"model":"claude-fable-5-2","tokenCount":1},{"id":"d","agentType":"fork","status":"running","description":"w","startTime":0,"model":"claude-fable-5-5","tokenCount":1}]}' |
  sh "$D/py.sh" statusline/subagent-statusline.py)
ok=$(printf '%s\n' "$saida" | jq -rs '[.[0].id == "a", (.[0].content | contains("Haiku 5.5")), (.[1].content | contains("\u001b[31mSonnet 4.5")), (.[2].content | contains("\u001b[33mFable 5.2")), (.[3].content | contains("\u001b[31mFable 5.5"))] | all')
[ "$ok" = true ] || { echo "divergiu: subagent-statusline: $saida"; FALHAS=$((FALHAS + 1)); }

# Inventário: do env global saem só os nomes (o JSON vai para o transcript); nome
# de segredo vai para o local, o que o modelo define é descartado, allow pergunta.
# Path.home() lê HOME no Linux e USERPROFILE no Windows.
CASA=$(mktemp -d); mkdir -p "$CASA/.claude"
printf '%s' '{"env":{"GITHUB_TOKEN":"ghp_SEGREDO_DE_TESTE","MEU_MODO":"x9z_VALOR","ANTHROPIC_DEFAULT_HAIKU_MODEL":"claude-haiku-4-5"},"permissions":{"allow":["Bash(rm:*)"],"defaultMode":"default"}}' >"$CASA/.claude/settings.json"
inv=$(HOME="$CASA" USERPROFILE="$(nativo "$CASA")" sh "$D/py.sh" skills/aplicar/inventariar.py --projeto "$(nativo "$CASA")")
case "$inv" in *SEGREDO_DE_TESTE* | *x9z_VALOR*) echo "divergiu: inventariar imprimiu valor do env"; FALHAS=$((FALHAS + 1)) ;; esac
ok=$(printf '%s' "$inv" | jq -r '[.settings_global[] | {(.chave): .destino}] | add
  | [."env.GITHUB_TOKEN" == "local", ."env.MEU_MODO" == "time", ."env.ANTHROPIC_DEFAULT_HAIKU_MODEL" == "padrao",
     ."permissions.allow" == "avaliar", ."permissions.defaultMode" == "global"] | all')
[ "$ok" = true ] || { echo "divergiu: inventariar: $(printf '%s' "$inv" | jq -c .settings_global)"; FALHAS=$((FALHAS + 1)); }
rm -rf "$CASA"

# medir: modelo em que o subagent rodou, correção do hook e tokens por modelo.
CASA=$(mktemp -d); PROJ=$(nativo "$(mktemp -d)")
# no Windows o print do Python termina em \r\n: tira o \r
chave=$(sh "$D/py.sh" -c 'import re, sys; from pathlib import Path; print(re.sub(r"[^A-Za-z0-9]", "-", str(Path(sys.argv[1]).resolve())))' "$PROJ" | tr -d '\r')
mkdir -p "$CASA/.claude/projects/$chave"
agora=$(date -u +%Y-%m-%dT%H:%M:%S)
{
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":2000,"cache_read_input_tokens":5000,"output_tokens":200},"content":[{"type":"tool_use","id":"t1","name":"Agent","input":{"subagent_type":"Explore","prompt":"x"}}]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m2","model":"claude-opus-5-5","usage":{"input_tokens":1000,"output_tokens":100},"content":[{"type":"tool_use","id":"t2","name":"Agent","input":{"subagent_type":"padrao:coletor","prompt":"y"}}]}}\n' "$agora"
  # chamada que o hook recusou: não conta como se tivesse rodado
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m3","model":"claude-opus-5-5","content":[{"type":"tool_use","id":"t3","name":"Agent","input":{"subagent_type":"general-purpose","model":"fable","prompt":"z"}}]}}\n' "$agora"
  printf '{"type":"user","timestamp":"%s","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t3","content":"model=fable fora da politica"}]}}\n' "$agora"
  # custo (US$/milhão): o sufixo [1m] casa por prefixo com claude-opus-5-5; m4 repete o id e
  # vale a última linha (10k·4 + 30k·5 + 20k de 1 h·8 + 140k lidos·0,2 + 1k·20 = 0,398, contexto
  # 200.000 exatos = faixa 100–200K); m5 = 300k·4 = 1,2; m6 = 500k·0,2 + 5k·20 = 0,2;
  # m7 = 1k·4 + 700k·0,2 = 0,144. Principal = 0,013 + 0,006 + 1,942 = 1,961.
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m4","model":"claude-opus-5-5[1m]","usage":{"input_tokens":10000,"cache_read_input_tokens":140000,"cache_creation_input_tokens":50000,"cache_creation":{"ephemeral_1h_input_tokens":20000},"output_tokens":1},"content":[{"type":"thinking","thinking":""}]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m4","model":"claude-opus-5-5[1m]","usage":{"input_tokens":10000,"cache_read_input_tokens":140000,"cache_creation_input_tokens":50000,"cache_creation":{"ephemeral_1h_input_tokens":20000},"output_tokens":1000},"content":[{"type":"text","text":"ok"}]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m5","model":"claude-opus-5-5[1m]","usage":{"input_tokens":300000},"content":[]}}\n' "$agora"
  # aviso sintético do Claude Code: não é requisição a modelo, não entra em "sem preço"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m9","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0},"content":[]}}\n' "$agora"
  # fable: 100k lidos·0,2 + 500·40 = 0,04 (o cache lido do Fable custa o mesmo que o do Opus);
  # contexto de 100.000 = faixa até 100K. Com ele a principal soma 2,001 e o total 2,1215005.
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m10","model":"claude-fable-5-2","usage":{"cache_read_input_tokens":100000,"output_tokens":500},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m6","model":"claude-opus-5-5[1m]","usage":{"cache_read_input_tokens":500000,"output_tokens":5000},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m7","model":"claude-opus-5-5[1m]","usage":{"input_tokens":1000,"cache_read_input_tokens":700000},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"m8","model":"claude-opus-4-8","usage":{"input_tokens":1000},"content":[]}}\n' "$agora"
} >"$CASA/.claude/projects/$chave/s.jsonl"
# subagents: sonnet 10k·2 + 10k escrita 5 min·2,5 + 100k lidos·0,1 + 2,5k·10 = 0,08; haiku com
# 100.000 exatos = faixa baixa (100k·0,1 + 1k·0,5 = 0,0105); com 100.001 = alta (1·0,5 + 100k·0,05
# + 10k·2,5 = 0,0300005; na baixa seria 0,0060001: sobrepreço 0,024). Subagents = 0,1205005;
# total = 2,0815005 (subagents 6%).
mkdir -p "$CASA/.claude/projects/$chave/s/subagents"
{
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"a1","model":"claude-sonnet-5-5","usage":{"input_tokens":10000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":100000,"output_tokens":2500},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"a2","model":"claude-haiku-5-5","usage":{"input_tokens":100000,"output_tokens":1000},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"a3","model":"claude-haiku-5-5","usage":{"input_tokens":1,"cache_read_input_tokens":100000,"output_tokens":10000},"content":[]}}\n' "$agora"
  printf '{"type":"assistant","timestamp":"%s","message":{"id":"a4","model":"claude-opus-4-8","usage":{"input_tokens":1000},"content":[]}}\n' "$agora"
} >"$CASA/.claude/projects/$chave/s/subagents/a.jsonl"
med=$(HOME="$CASA" USERPROFILE="$(nativo "$CASA")" sh "$D/py.sh" skills/medir/medir-modelos.py --projeto "$PROJ" | tr -d '\r')
for re in '1 correção\(ões\) de papel fixo \(Explore=1\) · 1 recusa\(s\)' '^  general-purpose +fable \(recusada\)=1$' '^  Explore +haiku=1$' '^  padrao:coletor +haiku=1$' '^  principal +claude-opus-5-5 +3k · 5k · 300$' \
  '^  principal  claude-opus-5-5\[1m\]    US\$ 1\.94$' '^  principal  claude-opus-5-5        US\$ 0\.02$' \
  '^  principal  claude-fable-5-2 +US\$ 0\.04$' \
  '^  subagents  claude-sonnet-5-5      US\$ 0\.08$' '^  subagents  claude-haiku-5-5       US\$ 0\.04$' \
  '^  total      US\$ 2\.12 · subagents 6%$' \
  '^  até 100K         3 · 3%$' '^  100–200K         1 · 20%$' '^  200–400K         1 · 60%$' '^  400–600K         1 · 10%$' '^  acima de 600K    1 · 7%$' \
  '^Haiku acima de 100K: 1 de 2 requisições · sobrepreço US\$ 0\.02$' '^sem preço na tabela \(fora da conta\): claude-opus-4-8=2$'; do
  printf '%s\n' "$med" | grep -Eq "$re" || { echo "divergiu: medir-modelos sem /$re/: $med"; FALHAS=$((FALHAS + 1)); }
done
# período sem requisição: as seções saem com zeros, sem quebrar
for f in "$CASA/.claude/projects/$chave/s.jsonl" "$CASA/.claude/projects/$chave/s/subagents/a.jsonl"; do
  sed 's/"timestamp":"[^"]*"/"timestamp":"2000-01-01T00:00:00"/' "$f" >"$f.velho" && mv "$f.velho" "$f"
done
med=$(HOME="$CASA" USERPROFILE="$(nativo "$CASA")" sh "$D/py.sh" skills/medir/medir-modelos.py --projeto "$PROJ" | tr -d '\r')
for re in '^  total      US\$ 0\.00 · subagents 0%$' '^  acima de 600K    0 · 0%$' '^Haiku acima de 100K: 0 de 0 requisições · sobrepreço US\$ 0\.00$'; do
  printf '%s\n' "$med" | grep -Eq "$re" || { echo "divergiu: medir-modelos (vazio) sem /$re/: $med"; FALHAS=$((FALHAS + 1)); }
done
case "$med" in *"sem preço"*) echo "divergiu: medir-modelos (vazio) listou modelo sem preço"; FALHAS=$((FALHAS + 1)) ;; esac
rm -rf "$CASA" "$PROJ"


if [ "$FALHAS" -eq 0 ]; then
  echo "hooks: todas as decisoes conferem"
  exit 0
fi
echo "hooks: $FALHAS decisao(oes) divergente(s)"
exit 1
