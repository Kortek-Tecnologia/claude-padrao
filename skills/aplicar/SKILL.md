---
name: aplicar
description: Aplica o padrão de Claude Code no projeto — leva o que mora no global (~/.claude, ~/.claude.json) para o projeto, deixa o global limpo e fixa modelos e subagents (Opus decide, Sonnet executa lote com ficha, Haiku coleta). Use ao começar ou adotar o padrão num projeto, quando o hook do padrão avisar algo fora do lugar, ou quando pedirem para aplicar o padrão ou limpar o global.
---

# Aplicar o padrão

Regra: **tudo no projeto, global limpo.** No `~/.claude/settings.json` ficam só
`autoMemoryEnabled: false`, para pasta sem o padrão não criar memória no global (nos projetos o
auto memory também fica desligado: contexto vai no `CLAUDE.md` da pasta), e `statusLine` e
`subagentStatusLine`: são interface do terminal e têm de aparecer em qualquer pasta, inclusive
no home — scripts em `~/.claude/statusline.py` e `~/.claude/subagent-statusline.py`. As chaves
que o Claude Code recusa de projeto — `permissions.defaultMode` (bypass/auto só valem do escopo
user) e `skipDangerousModePermissionPrompt` — ficam se o usuário já as tem; o padrão não as cria.

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
variáveis); memórias em `~/.claude/projects/*/memory` com o projeto de cada uma; projetos
conhecidos e se já têm o padrão. Do `env` global vêm só os nomes (`valor: "(oculto)"`): nunca
imprima um valor de variável — mova-o de arquivo para arquivo com `jq`, sem exibir. No Windows o
Python não enxerga caminho com mais de 260 caracteres (projeto em pasta funda): se o hook de
abertura acusar memória ou MCP que o inventário não traz, liste pelo Bash e inclua no plano.

Leia também do projeto: `.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`,
`CLAUDE.md`, `.gitignore`, `.claude/agents|skills|commands` e todo `AGENTS.md` versionado
(`git ls-files AGENTS.md '*/AGENTS.md'`).

## 2. Monte o plano e peça OK UMA vez

Mostre uma tabela item → destino → ação, cobrindo TODO o inventário. Mexe fora do projeto atual
(global e outros projetos): só com OK. Destinos:

| Item global | Vai para |
|---|---|
| `model`, `effortLevel`, `modelSettings`, `fallbackModel`, `cleanupPeriodDays`, `disableClaudeAiConnectors` (destino `padrao`) | descartados: o `modelos/settings.json` fixa Opus 5.5 1M, effort medium, subagents Sonnet/Haiku 5.5 effort medium, transcripts por 14 dias, conectores do claude.ai desligados, e sem `fallbackModel` (sem a chave, indisponibilidade não troca de modelo) |
| `autoMemoryDirectory`, `autoDreamEnabled` (destino `descartar`) | descartados: auto memory desligado |
| `env.*` que o modelo já define (destino `padrao`) | descartados: o `modelos/settings.json` fixa |
| chaves `time` (`env.*` comuns, `hooks`, `permissions.deny/ask`, `enabledPlugins`, `extraKnownMarketplaces`) | `.claude/settings.json` dos projetos que usam |
| chaves `local` (`env.*` com nome de segredo — TOKEN, KEY, SECRET, PASS, AUTH, URL…; `permissions.additionalDirectories`; `language`, `tui`, `theme`, `outputStyle`, `switchModelsOnFlag`…) | `.claude/settings.local.json` (fora do git) |
| `permissions.allow` (destino `avaliar`) | pergunte regra a regra: do time → `.claude/settings.json`; liberação pessoal → `.claude/settings.local.json` |
| `permissions.defaultMode`, `skipDangerousModePermissionPrompt` | ficam no global (únicas), se já existem; o padrão não as cria |
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

**`AGENTS.md` do projeto entra no plano.** O Claude Code só lê `AGENTS.md` enquanto não há
`CLAUDE.md` na pasta nem acima dela — e o passo 7 cria o `CLAUDE.md`. Sem import, as instruções
do time saem do contexto sem aviso. Para cada `AGENTS.md` versionado que o `CLAUDE.md` da mesma
pasta não importa (`@AGENTS.md` fora de crase), uma linha no plano, com o tamanho (`wc -l`): na
raiz, `@AGENTS.md` na primeira linha do `CLAUDE.md`; em subpasta, um `<pasta>/CLAUDE.md` só com
`@AGENTS.md` (ou a linha no que já existir), que carrega quando o Claude lê arquivo de lá. O
import soma à carga fixa: o que o usuário não quiser importar fica de fora e vai para o resumo.

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
  effort `medium` para Opus, Sonnet e Haiku 5.5 e o teto de compactação automática do Opus em
  400K (`modelSettings["claude-opus-5-5"].autoCompactWindow: 400000`), os aliases
  (`env.ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` na família 5.5 e
  `env.ANTHROPIC_DEFAULT_FABLE_MODEL` no Fable 5.2), sem "atualizar", e a memória
  desligada (`env.CLAUDE_CODE_DISABLE_AUTO_MEMORY: "1"`, que vence `autoMemoryEnabled` nos dois
  sentidos — tire `autoMemoryEnabled` e `autoDreamEnabled` do projeto, se houver), subagent sem
  `model` em sonnet (`env.CLAUDE_CODE_SUBAGENT_MODEL`) e subagent sem abrir subagent
  (`env.CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH: "1"`) —, SEM
  `env.CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING` (versões antigas do padrão o punham: tire, para o
  `/rewind` voltar), SEM
  `fallbackModel` (tire se houver: sem a chave, indisponibilidade não troca de modelo; o `[]`
  não é documentado),
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
- `.gitignore`: `.claude/settings.local.json`, `.claude/backup-global-*/` e `_audit/` (rascunho
  do `/padrao:arrumar`; os commits dele não podem levá-lo). `.claude/memoria/` não é mais acrescentado (não remova de
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

Insira `modelos/claude-md.md` no fim do `CLAUDE.md` da raiz (o texto do projeto vem antes). Se
já houver o bloco entre `<!-- padrao:inicio` e `<!-- padrao:fim -->`, SUBSTITUA só ele, onde
estiver. Se o projeto já tiver seção
própria de modelos/subagents, mostre a sobreposição e pergunte qual fica. A primeira linha do
bloco e a dos `padrao-*.md` trazem o carimbo `modelo X`: copie-a como está — o hook de abertura
compara só o carimbo e avisa quando o projeto ficou com um modelo anterior.

O bloco é curto de propósito: o que não vale em toda sessão fica em arquivos lidos sob demanda,
listados no índice dele (sem `@`: import carrega sempre e não economiza contexto).
- Copie `modelos/agente/padrao-*.md` para `docs/agente/` do projeto, sobrescrevendo (são do
  plugin, como o bloco).
- `AGENT_LEARNINGS.md` na raiz (erros do agente e a abordagem certa, no git, para o time): sem
  ele, crie de `modelos/agent-learnings.md`; existindo, não toque.
- `AGENTS.md` aprovado no plano: `@AGENTS.md` sozinho na primeira linha do `CLAUDE.md` da mesma
  pasta, antes de tudo e fora de crase (entre crases é só texto — é assim que este arquivo o
  cita). Já importado, não repita.
- Projeto com `CLAUDE.md` longo (perto de 200 linhas ou mais): sugira no resumo final rodar
  `/padrao:arrumar`, que move o que não vale em toda sessão para `docs/agente/`.

## 8. Limpe o global e feche

1. Grave `~/.claude/settings.json` como `modelos/global.json`, mais `permissions.defaultMode` e
   `skipDangerousModePermissionPrompt` SÓ se o usuário já os tinha (com o mesmo valor; não os
   crie), `<PYTHON>` = o interpretador que o `py.sh` acha nesta máquina (`python3`,
   `python` ou `py`) e `<HOME>` = o home com `/` (no Git Bash, `cygpath -m "$HOME"`; trocar as
   barras do caminho do Windows à mão come as barras). Copie `<plugin>/statusline/statusline.py` e
   `subagent-statusline.py` para `~/.claude/` (rodar a skill de novo os atualiza; o hook
   de abertura avisa se ficarem velhos). Apague as sobras e o que foi migrado.
2. Valide todo JSON tocado (`jq empty <arquivo>`).
3. Confira: `printf '{}' | CLAUDE_PROJECT_DIR=<raiz> sh <plugin>/scripts/conferir-padrao.sh` não
   imprime nada, e rodar o inventário de novo mostra o global vazio.
4. Resuma o que mudou em cada arquivo/projeto, o que ficou no global e por quê.
5. Diga que vale a partir da PRÓXIMA sessão (confira com `/status` → "Setting sources"), que na
   primeira sessão o Claude Code pede confiança na pasta para instalar o plugin, que o `/model`
   grava no global — o projeto reaplica o Opus 5.5 1M ao abrir, e o hook do padrão avisa — e que
   toda sessão abre em effort medium: o `/effort` muda a sessão (com `s` no seletor, sem gravar no
   global) e a próxima volta a medium. A compactação automática do Opus fica em 400K (cada
   requisição relê o contexto inteiro); a sessão que precisar de mais abre com
   `claude --autocompact 1M`. Subir ao Fable 5.2 é o último degrau e vale só na sessão:
   `/model`, escolher o Fable e teclar `s`, de preferência depois de `/compact` (o cache é por
   modelo).
