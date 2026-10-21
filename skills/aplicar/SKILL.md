---
name: aplicar
description: Aplica o padrão de Claude Code no projeto — leva o que mora no global (~/.claude, ~/.claude.json) para o projeto, deixa o global limpo e fixa modelos e subagents (Opus decide, Sonnet executa, Haiku coleta). Use ao começar ou adotar o padrão num projeto, quando o hook do padrão avisar algo fora do lugar, ou quando pedirem para aplicar o padrão ou limpar o global.
---

# Aplicar o padrão

Regra: **tudo no projeto, global limpo.** No `~/.claude/settings.json` ficam só as chaves que
o Claude Code recusa de projeto — `permissions.defaultMode` (bypass/auto só valem do escopo
user) e `skipDangerousModePermissionPrompt` —, `autoMemoryEnabled: false`, para pasta sem o
padrão não criar memória no global (nos projetos o auto memory também fica desligado: contexto
vai no `CLAUDE.md` da pasta), e `statusLine` e `subagentStatusLine`: são interface do
terminal e têm de aparecer em qualquer pasta, inclusive no home — scripts em
`~/.claude/statusline.py` e `~/.claude/subagent-statusline.py`.

Os modelos estão em `modelos/` e o inventário em `inventariar.py`, ao lado deste arquivo
(o diretório base desta skill). Plugin NÃO carrega settings — por isso esta skill os grava.
Nunca sobrescreva sem ler: MESCLE, e mostre o diff ao final.

**Rodando do home** (`~`): o home NÃO é projeto — o `~/.claude/settings.json` dele É o global.
Não aplique os passos 4 e 7 nele: só distribua o global para os projetos (passos 1–3, 5, 6, 8)
e grave o backup em `~/Documents/backup-claude-global-<AAAA-MM-DD>/`.

## 0. Pré-requisitos (Windows e Linux)

- **Git Bash** no Windows: os hooks do plugin rodam em `bash`.
- **jq**: sem ele os hooks negam o coletor e não conferem o global. Ausente → ofereça
  instalar (`winget install jqlang.jq` | `sudo apt install jq` | `brew install jq`).
- **Python 3.9+**: rode sempre por `sh <plugin>/scripts/py.sh` (`<plugin>` = dois níveis acima
  desta skill), que acha `python3`/`python`/`py` — no Windows o `python3` costuma ser o atalho
  quebrado da Microsoft Store.

## 1. Levante o estado (só leitura)

    sh <plugin>/scripts/py.sh <esta skill>/inventariar.py

Devolve JSON com: chaves do settings global e o destino de cada uma; sobras (`settings.local.json`,
backups); `CLAUDE.md`, agents, commands, skills, output-styles, rules, workflows e status line
globais; plugins instalados no escopo user; MCP de escopo user e local (só nomes e NOMES de
variáveis — nunca imprima valores de token); memórias em `~/.claude/projects/*/memory` com o
projeto de cada uma; projetos conhecidos e se já têm o padrão.

Leia também do projeto: `.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`,
`CLAUDE.md`, `.gitignore`, `.claude/agents|skills|commands`.

## 2. Monte o plano e peça OK UMA vez

Mostre uma tabela item → destino → ação, cobrindo TODO o inventário. Mexe fora do projeto atual
(global e outros projetos): só com OK. Destinos:

| Item global | Vai para |
|---|---|
| `model`, `effortLevel`, `modelSettings`, `fallbackModel` (destino `padrao`) | descartados: o `modelos/settings.json` fixa Opus 5.5 1M, effort medium, subagents Sonnet/Haiku 5.5 effort medium, e sem `fallbackModel` (sem a chave não há fallback) |
| `autoMemoryDirectory` (destino `descartar`) | descartado: auto memory desligado |
| chaves `time` (`env`, `hooks`, `permissions.allow/deny/ask`, `enabledPlugins`, `extraKnownMarketplaces`) | `.claude/settings.json` dos projetos que usam |
| chaves `local` (`statusLine`, `language`, `tui`, `theme`, `outputStyle`, `switchModelsOnFlag`…) | `.claude/settings.local.json` |
| `permissions.defaultMode`, `skipDangerousModePermissionPrompt` | ficam no global (únicas) |
| `autoMode` (só vale em user/managed) | descartar se desatualizado (repo confiável que não existe mais etc.); senão pergunte |
| destino `avaliar` | pergunte |
| `settings.local.json` global, `settings.json.*` (backups) | apagar (o Claude Code não lê) |
| `~/.claude/CLAUDE.md` | `CLAUDE.md` de cada projeto, só o que se aplica a ele |
| `agents/`, `commands/`, `skills/` (menos `synced/`), `output-styles/`, `rules/`, `workflows/` | `.claude/<mesmo>` dos projetos que usam; de terceiro ou pessoal → também no `.gitignore` |
| status line (`statusline*`) | substituída pela do padrão (passo 8); a antiga só no backup |
| plugin no escopo user | `claude plugin install <p> --scope project` nos projetos que usam (rode DENTRO de cada um); depois `claude plugin uninstall <p> --scope user` |
| MCP escopo user | `.mcp.json` na raiz dos projetos que usam — PERGUNTE quais; depois `claude mcp remove <nome> --scope user` |
| MCP escopo local de um projeto | `.mcp.json` daquele projeto; depois, de dentro dele, `claude mcp remove <nome> --scope local` |
| memória `~/.claude/projects/<x>/memory` ou `<projeto>/.claude/memoria/` | texto no `CLAUDE.md` do projeto, se for fato durável dele; o resto só no backup (ver 5) |

`keybindings.json` e `themes/` são só globais por natureza: ficam. Nunca toque em estado do app:
`.credentials.json`, `projects/*.jsonl` e `projects/*/subagents` (transcripts, o `/resume`
depende), `plugins/` (só via `claude plugin`), `skills/synced/`, `skills/.trash/` (lixeira do sync do claude.ai), `history.jsonl`,
`file-history/`, `sessions/`, `session-env/`, `shell-snapshots/`, `cache/`, `ide/`, `chrome/`,
`state/`, `backups/`, `~/.claude.json` (só via `claude mcp`).

**MCP com segredo** (variável com TOKEN/KEY/SECRET/PASSWORD, cabeçalho `Authorization`): o
`.mcp.json` não pode ir ao git com o valor. Ou use `${VAR}` no `.mcp.json` e a variável no
ambiente do usuário, ou ponha `.mcp.json` no `.gitignore`. Pergunte qual; copie o valor do
`~/.claude.json` sem mostrá-lo.

## 3. Backup

Antes de escrever, copie para `<projeto atual>/.claude/backup-global-<AAAA-MM-DD>/` (e garanta
`.claude/backup-global-*/` no `.gitignore`): `~/.claude/settings.json`, as sobras, os arquivos
globais que vão mudar e as pastas de memória. NÃO copie `~/.claude.json` (tem tokens).

## 4. Projeto — time e pessoal

- `.claude/settings.json` (time, git): mescle `modelos/settings.json`. As chaves do modelo
  VENCEM — `model` é sempre `claude-opus-5-5[1m]`, `effortLevel` `medium`, `modelSettings` com
  effort `medium` para Opus, Sonnet e Haiku 5.5, os aliases dos subagents
  (`env.ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`) na família 5.5, sem "atualizar", e a memória
  desligada (`env.CLAUDE_CODE_DISABLE_AUTO_MEMORY: "1"`, que vence `autoMemoryEnabled` nos dois
  sentidos — tire `autoMemoryEnabled` e `autoDreamEnabled` do projeto, se houver), subagent sem
  `model` em sonnet (`env.CLAUDE_CODE_SUBAGENT_MODEL`) e subagent sem abrir subagent
  (`env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH: "1"`) —, SEM
  `fallbackModel` (tire se houver: sem a chave não há fallback; o `[]` não é documentado),
  e `extraKnownMarketplaces.claude-padrao` com `autoUpdate: true` (marketplace de terceiro vem sem
  atualização automática),
  exceto `permissions`, `hooks`, `env` (una) e chaves que o projeto tenha e o modelo não cite
  (preserve). Some as chaves `time` vindas do global. Projeto de marketplace antigo: tire
  `enabledPlugins["padrao@padrao"]`, `enabledPlugins["padrao@kortek-tools"]`,
  `extraKnownMarketplaces.padrao` e `extraKnownMarketplaces.kortek-tools` (este só se nenhum
  outro plugin `@kortek-tools` estiver ligado) e reinstale como no README do plugin.
- `.claude/settings.local.json` (pessoal, fora do git): mescle `modelos/settings.local.json`
  (só `syncClaudeAiPlugins`). Tire `autoMemoryEnabled` e `autoMemoryDirectory`, se houver:
  memória é desligada no `settings.json`. Some as chaves `local`.
  Sem `statusLine` aqui: ela vem do global (passo 8). O `syncClaudeAiPlugins: false` do modelo
  corta os plugins `@synced` da conta claude.ai (os do app); ele só vale daqui ou do global — o
  `.claude/settings.json` do projeto ignora. Plugin do app que o projeto use: instale-o pelo
  marketplace com `--scope project`.
- `.gitignore`: `.claude/settings.local.json`, `.claude/backup-global-*/` e `_audit/` (saída do
  `/padrao:auditar`, rascunho local). `.claude/memoria/` não é mais acrescentado (não remova de
  projeto que já o tenha).

## 5. Memórias (auto memory desligado)

Memória não é mais recurso: o contexto do projeto mora só no `CLAUDE.md` da pasta. Cada memória
existente — global (`~/.claude/projects/<x>/memory/`) ou do projeto (`<projeto>/.claude/memoria/`)
— vira texto conciso no `CLAUDE.md` do projeto SE for fato durável dele (decisão, convenção,
armadilha, endereço) e NÃO for pessoal nem sigilosa (credencial, dado de pessoa, preferência
do usuário): pergunte item a item na dúvida. O que não entrar no `CLAUDE.md` fica só no backup.

- `projeto_existe: false` (pasta movida ou apagada): procure o projeto pelo nome (ex.:
  `Desktop/ANCC` → `Desktop/Projetos/ANCC`) e confirme com o usuário; sem destino, só no backup.
- `projeto: null`: deduza pelo conteúdo e confirme.
- `eh_home: true` (sessões abertas no home): o home NÃO é projeto. Distribua cada fato para o
  projeto de que fala; o genérico (perfil do usuário, feedback de trabalho) é pessoal: só no backup.
- Links `[[nome]]` e caminhos dentro das memórias: ajuste ao que mudou de lugar.

Depois de passar ao `CLAUDE.md` e conferir, apague a pasta de memória (`memory/` do global — só
ela, os `.jsonl` ficam — e `<projeto>/.claude/memoria/`), COM OK do usuário.

## 6. Outros projetos

Todo projeto que receber item nesta rodada recebe também o padrão completo (passos 4 e 7 nele).
Os projetos que só aparecem no inventário (sem item) ficam como estão: liste-os no fim, para o
usuário rodar `/padrao:aplicar` lá quando abrir.

## 7. Regras no `CLAUDE.md`

Insira `modelos/claude-md.md` no `CLAUDE.md` da raiz. Se já houver o bloco entre
`<!-- padrao:inicio` e `<!-- padrao:fim -->`, SUBSTITUA só ele. Se o projeto já tiver seção
própria de modelos/subagents, mostre a sobreposição e pergunte qual fica.

O bloco é curto de propósito: o que não vale em toda sessão fica em arquivos lidos sob demanda,
listados no índice dele (sem `@`: import carrega sempre e não economiza contexto).
- Copie `modelos/agente/padrao-*.md` para `docs/agente/` do projeto, sobrescrevendo (são do
  plugin, como o bloco).
- `AGENT_LEARNINGS.md` na raiz (erros do agente e a abordagem certa, no git, para o time): sem
  ele, crie de `modelos/agent-learnings.md`; existindo, não toque.
- Projeto com `CLAUDE.md` longo (perto de 200 linhas ou mais): sugira no resumo final rodar
  `/padrao:enxugar-docs`, que move o que não vale em toda sessão para `docs/agente/`.

## 8. Limpe o global e feche

1. Grave `~/.claude/settings.json` como `modelos/global.json`, mantendo o `defaultMode` que o
   usuário já usa, `<PYTHON>` = o interpretador que o `py.sh` acha nesta máquina (`python3`,
   `python` ou `py`) e `<HOME>` = o home com `/`. Copie `<plugin>/statusline/statusline.py` e
   `subagent-statusline.py` para `~/.claude/` (rodar a skill de novo os atualiza; a guarda
   avisa se ficarem velhos). Apague as sobras e o que foi migrado.
2. Valide todo JSON tocado (`jq empty <arquivo>`).
3. Confira: `printf '{}' | CLAUDE_PROJECT_DIR=<raiz> sh <plugin>/scripts/guarda-global.sh` não
   imprime nada, e rodar o inventário de novo mostra o global vazio.
4. Resuma o que mudou em cada arquivo/projeto, o que ficou no global e por quê.
5. Diga que vale a partir da PRÓXIMA sessão (confira com `/status` → "Setting sources"), que na
   primeira sessão o Claude Code pede confiança na pasta para instalar o plugin, e que o `/model`
   grava no global — o projeto reaplica o Opus 5.5 1M ao abrir, e o hook do padrão avisa.
