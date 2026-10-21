# padrao

Plugin de Claude Code (`padrao`) que padroniza projetos novos e existentes: **tudo no
projeto, global limpo**, tudo na **família 5.5 com 1M de contexto** — principal Opus 5.5 1M,
effort medium; subagents Sonnet 5.5 e Haiku 5.5, effort medium (aliases fixados por
`ANTHROPIC_DEFAULT_*_MODEL`); sem fallback de modelo; auto memory desligado (contexto do
projeto no `CLAUDE.md`) — e distribuição de subagents fixa: Opus decide, Sonnet executa,
Haiku coleta. Funciona no Windows (Git Bash) e no Linux.

- Subagent sem `model` roda em Sonnet, não no Opus da sessão (`CLAUDE_CODE_SUBAGENT_MODEL`
  no `.claude/settings.json`; o `model:` do frontmatter do agente vence). Hook que corrige
  `Plan` para opus, `Explore`, `padrao:coletor` e `padrao:leitor` para haiku e
  `padrao:revisor` e `padrao:executor` para sonnet (o Explore rodaria no modelo da sessão; o
  `model` da chamada venceria o frontmatter) e recusa
  `model` fora de `haiku|sonnet|opus`; `fork` passa.
- Agentes `padrao:coletor` (haiku), `padrao:leitor` (haiku), `padrao:executor` (sonnet) e
  `padrao:revisor` (sonnet), todos com effort medium; teto de turnos (`maxTurns` 30/30/100/40)
  e, nos que só leem, `disallowedTools: Write, Edit, NotebookEdit` além da lista `tools`.
- Hook que deixa os agentes que só leem (`Explore`, `padrao:coletor`, `padrao:revisor`,
  `padrao:leitor`) só lerem: Bash fechado por padrão (sem gravar, redirecionar ou executar
  programa), PowerShell fechado. Se o próprio hook falhar ou estourar o tempo, o comando é
  bloqueado (`onFailure: "block"`) — para qualquer agente, já que o hook roda em todo Bash.
- Hook de abertura que avisa quando algo voltou para o global (o `/model` e o `/effort`
  gravam lá), o projeto saiu do padrão ou há `fallbackModel`.
- Hook de abertura que avisa quando o padrão está desatualizado (versão instalada atrás da
  do marketplace, ou `autoUpdate` desligado no projeto) — ver [Atualizar](#atualizar).
- Skill `aplicar`: avalia tudo o que mora no global e leva cada item para o seu projeto.
- Skill `medir`: placar de modelos por subagent a partir dos transcripts locais.
- Skill `enxugar-docs` (só por `/padrao:enxugar-docs`): enxuga a documentação do projeto ao
  essencial e mede a carga fixa do `CLAUDE.md` (com imports e rules sem `paths:`), movendo o que
  não vale em toda sessão para arquivos apontados num índice — analisa e lista primeiro, edita
  só após aprovação.
- Subagent não abre subagent (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` no `.claude/settings.json`).
- Skill `auditar` (só por `/padrao:auditar`): diagnóstico de documentação e infraestrutura e
  plano de correção em lotes com `/goal` prontos; roda até o fim sem perguntar, só lê o
  repositório e grava em `_audit/`. A leitura de código vai ao agente `padrao:leitor`
  (haiku, só lê, sem o `CLAUDE.md` no contexto, para não se contaminar pela documentação).
- Skill `executar-lote` (só por `/padrao:executar-lote <n>`): executa um lote do
  `_audit/PLANO.md` — executor (sonnet) aplica, revisor (sonnet) confere, a condição de saída
  roda de verdade e só então os ids viram `resolvido`. Não commita.
- Skill `atualizar-docs` (`/padrao:atualizar-docs [ref]`, ou o Claude chama antes de commitar):
  corrige só a documentação que o diff atual deixou falsa — porta, comando, variável, caminho,
  nome renomeado; regra contrariada pelo diff vira DIVERGENTE, sem edição.
- Status line (`statusline/statusline.py`): modelo, pasta, branch, contexto, limites de 5h/7d e
  calor do prompt cache; com o padrão na própria linha — modelo em vermelho fora do Opus 5.5
  1M, effort em vermelho fora de medium, "sem padrão" na pasta sem o plugin — e atualização a
  cada 30 s (o contador do cache não congela com a sessão parada). Embutida de
  [Jhonatan-de-Souza/claude-code-statusline](https://github.com/Jhonatan-de-Souza/claude-code-statusline)
  (commit 44e9e48) com crédito; o repositório de origem não declara licença — uso pessoal, não
  publique este repositório sem a licença do autor.
- Status line dos subagents (`statusline/subagent-statusline.py`): uma linha por subagent no
  painel de agentes — tipo, modelo (cor por família; vermelho fora da 5.5), effort, contexto,
  tempo e descrição.

## Requisitos

- Claude Code **v2.1.295+** (Haiku 5.5; `onFailure` nos hooks).
- Windows: **Git Bash** (os hooks rodam em `bash`).
- **jq** — `winget install jqlang.jq` | `sudo apt install jq`. Sem ele, os agentes que só leem
  ficam sem Bash/PowerShell (fechado por padrão) e o hook de abertura se cala.
- **Python 3.9+** para as skills (`scripts/py.sh` acha `python3`, `python` ou `py`).

## Instalar num projeto

Do diretório do projeto, escopo de PROJETO (nada no global):

```
claude plugin marketplace add Kortek-Tecnologia/claude-padrao --scope project
claude plugin install padrao@claude-padrao --scope project
```

Depois, numa sessão: `/padrao:aplicar`. Projeto que já tem o padrão aplicado instala
sozinho ao abrir — o `.claude/settings.json` declara o marketplace —, mas só depois de
você aceitar o diálogo de confiança da pasta; em `claude -p` esse diálogo não aparece e
o plugin é ignorado em silêncio: use os dois comandos acima.

## O que a skill `aplicar` faz

1. Inventaria o global (`inventariar.py`): `~/.claude/settings.json` e sobras, `CLAUDE.md`,
   agents, commands, skills, output-styles, status line, plugins no escopo user, MCP de
   escopo user e local, memórias de cada projeto em `~/.claude/projects/*/memory`.
2. Mostra o plano item → destino e pede OK uma vez.
3. Faz backup em `.claude/backup-global-<data>/` (fora do git; sem tokens).
4. Leva cada item ao projeto a que pertence: settings de time em `.claude/settings.json`,
   pessoais em `.claude/settings.local.json`, MCP em `.mcp.json`, plugins com
   `--scope project`; memórias existentes (global ou `.claude/memoria/`) viram texto no
   `CLAUDE.md` do projeto, se forem fato durável e não pessoal (auto memory fica desligado).
5. Insere no `CLAUDE.md` um bloco curto do padrão, sem sobrescrever o resto. O detalhe vai
   para arquivos lidos **sob demanda**, listados num índice "arquivo → quando ler" do bloco —
   sem `@import`, que carregaria tudo em toda sessão:
   - `docs/agente/padrao-modelos.md` (delegação) e `docs/agente/padrao-configuracao.md`
     (onde mora cada configuração), regravados a cada `aplicar`;
   - `AGENT_LEARNINGS.md` na raiz, criado se não existir: o agente o lê antes de tarefa que
     altera arquivos e registra ali cada erro que custou retrabalho (erro, padrão a evitar,
     abordagem certa); subagent recebe as entradas que valem na passagem de tarefa.

   O mesmo vale para o contexto do próprio projeto: o que não serve a toda sessão vai para
   `docs/agente/<tema>.md` (ou `.claude/rules/` com `paths:`), e o `/padrao:enxugar-docs`
   aponta o que mover.
6. Deixa o global só com `permissions.defaultMode`, `skipDangerousModePermissionPrompt`
   (o Claude Code os recusa de projeto), `autoMemoryEnabled: false`, a `statusLine` e a
   `subagentStatusLine` — interface do terminal, aparecem em qualquer pasta; scripts em `~/.claude/`.

## Por que as settings não vêm no plugin

A documentação do Claude Code descarta `model`, `effortLevel` e afins quando vêm de plugin; só
`agent` e `subagentStatusLine` valem. Por isso a skill `aplicar` grava essas chaves no projeto.
O `model` do projeto vence o do usuário e é reaplicado a cada abertura, mesmo depois de um
`/model`.

## Testar

```
bash scripts/testar.sh
claude plugin validate .
```

## Atualizar

Publicar: suba `version` em `.claude-plugin/plugin.json`, rode os testes e dê
push.

Receber: o `.claude/settings.json` do padrão liga `autoUpdate` no marketplace `claude-padrao`
(marketplace de terceiro vem desligado). O Claude Code busca a versão nova até 10 min depois da
primeira mensagem da sessão; a sessão aberta segue na versão antiga até `/reload-plugins` ou
reiniciar. Se a instalada ficar diferente da do marketplace, o hook de abertura avisa com o
comando:

```
claude plugin update padrao@claude-padrao --scope project
```

Projeto sem `autoUpdate` no `.claude/settings.json` (instalado antes de o padrão gravá-lo) não
recebe sozinho: rode o comando acima uma vez nele e depois `/padrao:aplicar`.

Toda mudança publicada sobe a `version` (semver): o aviso de versão nova do hook de abertura
compara com ela. A numeração recomeçou em 1.0.0 com o histórico deste repositório; o aviso
compara por diferença, então projeto que ainda tem uma 3.x instalada também é avisado.

### Projeto instalado por um marketplace antigo

Antes deste repositório o plugin veio de `christian-jorge/claude-padrao` (`padrao@padrao`) e
depois do monorepo `Kortek-Tecnologia/kortek-tools` (`padrao@kortek-tools`). Num projeto antigo,
de dentro dele (troque `kortek-tools` por `padrao` se for o mais antigo):

```
claude plugin uninstall padrao@kortek-tools --scope project
claude plugin marketplace add Kortek-Tecnologia/claude-padrao --scope project
claude plugin install padrao@claude-padrao --scope project
```

Depois `/padrao:aplicar` troca o `extraKnownMarketplaces` e o `enabledPlugins` do
`.claude/settings.json`. Se o projeto não usa outro plugin do `kortek-tools`, tire também
`extraKnownMarketplaces.kortek-tools`.
