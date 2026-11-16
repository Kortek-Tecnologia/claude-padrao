# Como funciona por dentro

Para quem mantém o plugin. O uso está no [README](../README.md); a regra exata de cada hook está
no cabeçalho do script dele — aqui fica como as peças se ligam e por quê.

## As peças

```mermaid
flowchart LR
  subgraph CC["Claude Code"]
    SS["SessionStart"]
    AG["PreToolUse: Agent"]
    BT["PreToolUse: Bash, PowerShell,<br/>mcp__*, Monitor, Workflow…"]
    GC["PreToolUse: Skill; Bash e<br/>PowerShell com git"]
  end
  SS --> CP["conferir-padrao.sh"]
  AG --> TM["travar-modelo-subagent.sh"]
  BT --> TL["trava-leitura.sh"] --> SL["so-le.sh"] --> SG["segmentos.sh"]
  GC --> CD["cobrar-docs.sh"] --> SG
  AP["skill aplicar"] -->|"grava a partir de"| MOD["skills/aplicar/modelos/"]
  CP -->|"compara com"| MOD
  AP -->|"copia para ~/.claude/"| ST["statusline/statusline.py"]
  CP -->|"confere a cópia"| ST
  PS["settings.json do plugin:<br/>subagentStatusLine"] --> SU["py.sh →<br/>subagent-statusline.py"]
```

| Caminho | Papel |
|---|---|
| `hooks/hooks.json` | liga os quatro hooks; todos com `shell: bash` e timeout de 10 s; as duas travas com `onFailure: "block"` (falhou, bloqueia), o lembrete da documentação com `onFailure: "continue"` (falhou, o commit segue — por extenso, porque no Code Mode o hook que falha sem a chave recusa a chamada) |
| `skills/aplicar/modelos/` | **fonte única** do padrão: o `aplicar` grava a partir dela e o hook de abertura compara com ela |
| `scripts/py.sh` | acha `python3`, `python` ou `py` 3.9+ (no Windows o `python3` costuma ser o atalho quebrado da Store) e roda com `-I` |
| `agents/*.md` | os quatro agentes; os que só leem têm `tools` fechado e `disallowedTools` |
| `statusline/` | `statusline.py` é de terceiro (Jhonatan de Souza); nossas linhas ficam entre `padrao: início` e `padrao: fim` ou marcadas `# padrao` |
| `scripts/opcional.py` | liga, desliga e mostra os dois opcionais (Code Mode e Fable como advisor); as skills `code-mode` e `advisor` só o chamam — ver [Os opcionais](#os-opcionais--opcionalpy) |
| `settings.json` | a única setting que o plugin traz: `subagentStatusLine`, que roda o `subagent-statusline.py` direto do plugin (de plugin só valem ela e `agent`) |

## Hook de abertura — `conferir-padrao.sh`

Roda a cada `startup` e `resume`, e a primeira resposta espera por ele (~1 s). **Só avisa**: o
que achar vai ao usuário (`systemMessage`) e ao Claude (`additionalContext`), apontando o
`/padrao:aplicar`. Sem `jq`, fica calado.

| Confere | Contra |
|---|---|
| `model`, `effortLevel`, `modelSettings` (todos os campos que o modelo define em cada modelo, inclusive `autoCompactWindow`; campo ou modelo só do projeto não conta) e as chaves de `env` do projeto | `modelos/settings.json` |
| `fallbackModel` em `settings.json` ou `settings.local.json`; `CLAUDE_CODE_DISABLE_FILE_CHECKPOINTING` | têm de estar ausentes |
| `disableClaudeAiConnectors` (projeto) e `syncClaudeAiPlugins: false` (local, único lugar em que vale) | `true` / `false` |
| `~/.claude/settings.json` | só `permissions.defaultMode`, `skipDangerousModePermissionPrompt`, `autoMemoryEnabled`, a status line principal, o effort que o `/effort` salva (o projeto vence) e, de `env`, só `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` (o Code Mode só liga do escopo user); outra variável sai no aviso como `env.NOME`. `subagentStatusLine` ali é chave fora do padrão, porque o global vence o plugin, e `advisorModel` também (o `/advisor` grava lá; o lugar dele é o `settings.local.json` do projeto) |
| `~/.claude/` | sem `CLAUDE.md`, agents, commands, rules, workflows, skills pessoais (menos `synced/` e ocultas), `statusline.py` diferente da do plugin, `subagent-statusline.py` sobrando |
| `~/.claude.json` e `~/.claude/projects/<chave>/memory` | sem MCP de escopo user nem local deste projeto; sem memória deste projeto |
| versão instalada × `~/.claude/plugins/marketplaces/claude-padrao` | por **diferença**, não por ordem: a numeração recomeçou em 1.0.0 |
| carimbo `modelo X` do bloco do `CLAUDE.md` e dos `docs/agente/padrao-*.md` do projeto | o da 1ª linha do arquivo em `modelos/`; só o carimbo, não o texto — quem grava no projeto é o Claude, e espaço ou CRLF dariam aviso falso. A marca vale só no começo da linha (prosa que cita o marcador não conta), e carimbo mais novo que o do plugin manda atualizar o plugin, não rodar o `aplicar` |

## Linha dos subagents — `settings.json` do plugin

O `subagentStatusLine` vem do `settings.json` da raiz, sem cópia em `~/.claude`: atualizou o
plugin, atualizou a linha. Medido na v2.1.322, numa sessão interativa dentro de um
pseudo-terminal (ver [Testes](#testes)):

- o comando roda pelo Git Bash, com `${CLAUDE_PLUGIN_ROOT}` já trocado (a troca só existe da
  v2.1.319 em diante) e com `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA` e `CLAUDE_PROJECT_DIR`
  no ambiente;
- o painel chama o comando a cada 5 s enquanto há subagent visível; nos primeiros segundos
  aparece a linha padrão do Claude Code. Por isso o `py.sh` serve (~0,6 s no Windows, com o
  teste de versão do Python) e não foi preciso um lançador próprio;
- **o global vence o plugin**: `subagentStatusLine` em `~/.claude/settings.json` (o padrão a
  punha lá até a 2.2.1) esconde a do plugin. O hook de abertura acusa a chave e a cópia antiga
  do script, e o `aplicar` tira as duas.

## Hook de modelo — `travar-modelo-subagent.sh`

```mermaid
flowchart TD
  C["Chamada Agent"] --> T{"subagent_type"}
  T -->|"fork"| P0["passa: roda no<br/>modelo da sessão"]
  T -->|"papel fixo"| F{"model da chamada<br/>é o do papel?"}
  T -->|"outro"| M{"model"}
  F -->|"sim, ou agente do<br/>plugin sem model"| P1["passa"]
  F -->|"não"| COR["corrige: allow +<br/>updatedInput"]
  M -->|"vazio"| ENV["passa: CLAUDE_CODE_<br/>SUBAGENT_MODEL = sonnet"]
  M -->|"haiku, sonnet, opus"| P2["passa"]
  M -->|"fable, inherit, ID"| REC["recusa, explicando<br/>a política"]
```

| Papel fixo | Modelo |
|---|---|
| `Plan` | opus |
| `Explore`, `padrao:coletor`, `padrao:leitor` | haiku |
| `padrao:executor`, `padrao:revisor` | sonnet |

- **Precedência do modelo** no Claude Code: `model` da chamada > `model:` do frontmatter >
  `CLAUDE_CODE_SUBAGENT_MODEL` > modelo da sessão. Por isso os agentes do plugin sem `model` passam
  (o frontmatter já tem o certo) e o hook só age quando a chamada traz outro.
- O `Explore` embutido roda no `opus` por padrão: daí a correção sempre.
- `fable` segue recusado em subagent: é o último degrau de escalada da **sessão** (`/model` com
  `s`; amarelo na status line), e o alias está fixado no Fable 5.2 só para não mudar sozinho.
- A correção devolve a entrada inteira com o `model` trocado (`updatedInput` substitui a entrada).
- **Sem jq** não dá para reescrever: os campos saem por regex e o papel fixo fora do modelo é
  recusado com o modelo certo na mensagem.

## Trava de leitura — `trava-leitura.sh` → `so-le.sh` → `segmentos.sh`

```mermaid
flowchart TD
  A["Chamada de uma ferramenta do matcher"] --> F{"traz agent_type?"}
  F -->|"não: sessão principal"| S0["segue, sem abrir jq"]
  F -->|"sim"| Q{"Explore, padrao:coletor,<br/>padrao:leitor ou padrao:revisor?"}
  Q -->|"não"| S1["segue"]
  Q -->|"sim"| B{"Bash?"}
  B -->|"não: PowerShell, MCP, Workflow…"| N1["recusa"]
  B -->|"sim"| SG["corta em segmentos<br/>(fora de aspas; $( e crase também dentro de aspas duplas)"]
  SG --> K{"cada segmento"}
  K -->|"leitor conhecido, sem opção que grava"| S2["segue"]
  K -->|"grava, redireciona, executa"| N2["recusa dizendo o motivo"]
```

- **Matcher** (`hooks.json`): Bash, PowerShell, `mcp__*` e as embutidas que executam, gravam ou
  falam com fora (Monitor, Workflow, CronCreate/Delete, RemoteTrigger, Enter/ExitWorktree,
  SendMessage, SendToProject*, PushNotification, TaskStop). Ferramenta nova desse tipo entra
  ali. Não é `*` de propósito: cada chamada custa ~90 ms no Windows.
- **Lista de leitura** (`so-le.sh`): `cat grep head tail wc ls stat diff cmp echo printf jq test
  readlink realpath basename dirname cd pwd cut tr column nl`, mais estes com checagem:

| Comando | Recusado quando |
|---|---|
| `sed`, `awk` | sem `--sandbox` logo após o nome; com `-i` (sed) ou `-d/-p/-o/-D` (gawk), que o sandbox não impede |
| `git` | subcomando fora de `log show diff blame grep status ls-files ls-tree rev-parse rev-list cat-file shortlog merge-base name-rev describe`; `-c`, `--config-env`, `--output`, `--ext-diff`, `--exec-path`, `--git-dir`, `--work-tree`, `-O` |
| `sort`, `uniq`, `find`, `file`, `rg` | opção que grava ou executa (`-o`, dois operandos, `-exec`/`-delete`/`-fprint`, `-C`, `--pre`/`--hostname-bin`) |
| qualquer segmento | `>` que não seja `>/dev/null` ou `2>&1` |

- **Por que `--sandbox`:** sed e awk são linguagens. `s|a|b|e` executa comando com qualquer
  delimitador, e o gawk chama `system()` por chamada indireta (`@f`); nenhum filtro de texto
  fecha isso. O `--sandbox` do GNU sed recusa `e/r/w`, e o do gawk, `system`, redirecionamento e
  extensões. O mawk não tem a opção: falha, e fica fechado.
- **Risco que fica:** `cd` ou `git -C` para dentro de um repositório bare versionado com config
  hostil (`core.fsmonitor`). `safe.bareRepository=explicit` no git do usuário fecha.

## Lembrete da documentação — `cobrar-docs.sh`

A regra "antes de todo commit, a `padrao:atualizar-docs`" morava só no bloco do `CLAUDE.md`.
Medida em 14 dias de histórico local, a skill rodava antes de cerca de 4% dos commits (todos da
sessão principal, pelo Bash). Instrução depende de o modelo lembrar; o que tem hora certa vai em
hook.

```mermaid
flowchart TD
  K["Skill padrao:atualizar-docs"] --> AN["anota a sessão"]
  G["Bash ou PowerShell com git"] --> C{"algum segmento é<br/>git … commit?"}
  C -->|"não"| S0["segue, sem abrir jq"]
  C -->|"sim, de lote do arrumar"| S1["segue"]
  C -->|"sim"| N{"há anotação<br/>da sessão?"}
  N -->|"sim: a skill rodou,<br/>ou já lembrei"| S2["segue e gasta<br/>a anotação"]
  N -->|"não"| R["recusa uma vez: rode a skill<br/>e repita; anota que lembrou"]
```

- **Lembrete, não trava.** A segunda tentativa passa sempre. O hook não sabe se o diff tem algo
  documentado, e commit preso é pior que doc velha. Por isso também **falha aberto**: sem `jq`,
  sem `session_id` ou sem onde anotar, ele se cala.
- **Um commit, uma passada.** O commit que passa apaga a anotação; o seguinte pede a skill de
  novo. Commit que falha depois de passar pelo hook custa um lembrete a mais (menos de 1% dos
  commits do histórico).
- **Por sessão, não por repositório.** A anotação é `${CLAUDE_PLUGIN_DATA}/docs-<session_id>`.
  Cerca de 12% dos commits do histórico rodam fora do cwd da sessão (`cd outro && git commit`,
  `git -C`): amarrar ao HEAD de um repositório erraria nesses. A skill, ao anotar, varre as
  anotações de mais de 7 dias.
- **Filtro `if`** (`hooks.json`): `Bash(git *)` e `PowerShell(git *)`, um handler por ferramenta
  (o `if` leva uma regra só). Medido na v2.1.322: dispara em commit encadeado (`cd x && git add
  && git commit`), com atribuição na frente, com `git -C` e com heredoc; não dispara em `ls` nem
  em `echo "git commit"`. `Bash(git commit*)` perderia o `git -C x commit`. O filtro é de melhor
  esforço (dispara também em crase e `$()` que cita git): quem decide é o script.
- **O que é commit** para o script: segmento (`segmentos.sh`) que começa por `git`, com ou sem
  opções globais (`-C dir`, `-c k=v`, `--no-pager`), e subcomando `commit`. Antes do corte sai o
  corpo dos heredocs: o segmentador parte na crase, e texto que cita `git commit` entre crases
  (uma entrada de `AGENT_LEARNINGS.md` gravada por `cat <<EOF`) virava commit.
- **Fora:** os lotes do `/padrao:arrumar` (mensagem que começa por `arrumar: lote `, em `-m "…"`
  ou na 1ª linha do heredoc; o plano já cuidou da documentação) e o commit que o usuário roda no
  terminal, que não é chamada de ferramenta. Citar `arrumar: lote` em outro ponto do comando não
  isenta.
- **Escapam, e o commit segue sem lembrete:** `bash -c "git commit"`, alias (`git ci`) e opção
  global com o valor separado (`--git-dir x commit`). Nenhuma apareceu no histórico; o erro é
  sempre para o lado de deixar passar.
- **O texto da recusa** diz que é rotina e que não vai para o `AGENT_LEARNINGS.md`: o Claude
  Code a mostra como `hook error`, e sem isso o modelo a registrava como erro. O `medir` conta os
  lembretes por esse texto — mudou a frase, mude o `LEMBRETE` do `medir-modelos.py`.

## As skills

**`aplicar`** — o `inventariar.py` só lê e imprime JSON com o destino de cada item (`DESTINO`,
`PERMISSOES` e `SEGREDO` no topo do script): `padrao` (o modelo define), `time`, `local`,
`global`, `avaliar` (pergunte) ou `descartar`. Do `env` e dos MCP saem só os nomes. Os arquivos
que vão para o projeto saem de `modelos/`; o bloco do `CLAUDE.md` fica entre
`<!-- padrao:inicio` e `<!-- padrao:fim -->` e é substituído inteiro a cada `aplicar`.
Projeto com `AGENTS.md`: o plano propõe `@AGENTS.md` na primeira linha do `CLAUDE.md` da mesma
pasta. O Claude Code lê um ou outro — conferido na v2.1.322, com uma palavra-código que só
existe no `AGENTS.md`: sem import ela some, na raiz e em subpasta; com import, volta. A opção
que liga os dois (`pluginConfigs`) só vale no settings global, fora do padrão; o import mora no
projeto. O `arrumar` acha o mesmo caso na carga fixa.

LSP no `aplicar` é oferta, e só com o binário já no `PATH`. Medido na v2.1.322, no Windows, com
o `pyright-lsp` e o Pyright do npm num projeto Python público de 13 mil linhas:

- o servidor sobe (o atalho `.cmd` do npm serve) e o Claude recebe a ferramenta `LSP`
  (`workspaceSymbol`, `findReferences`, `hover`) e os diagnósticos de tipo — estes na chamada de
  ferramenta seguinte à edição, e só para `Edit`/`Write` (edição por `sed` no Bash não dispara);
- a ferramenta `LSP` é adiada: o modelo a carrega pelo `ToolSearch` quando decide usá-la. Em
  duas tarefas iguais com e sem o plugin (achar as chamadas de um método entre homônimos;
  renomear um método no código e nos testes), o resultado, os turnos e o custo foram os mesmos,
  e o Claude não chamou o `LSP` em nenhuma: resolveu por grep. Sem o plugin em uso, o contexto
  não cresce;
- `claude plugin install <plugin>@claude-plugins-official --scope project` grava só o
  `enabledPlugins` do projeto (e reordena as chaves do arquivo). O marketplace oficial já vem
  registrado numa instalação normal; num HOME novo de teste é preciso adicioná-lo, e no Windows
  o clone dele estoura os 260 caracteres sem `core.longpaths`.

**`arrumar`** — o estado mora em `_audit/` (no `.gitignore`), e é ele que permite retomar:

```mermaid
stateDiagram-v2
  [*] --> Levantar
  Levantar --> Levantar: artefato sem COMPLETO ou git mudou
  Levantar --> OK: PLANO.md completo
  OK --> [*]: só o diagnóstico, ou claude -p
  OK --> Executar: linha APROVADO no PLANO.md
  Executar --> Executar: próximo lote pendente
  Executar --> [*]: relatório
```

| Artefato | O que guarda |
|---|---|
| `ESCOPO.md`, `SISTEMA.md`, `INFRA.md`, `CONFRONTO.md` | o levantamento; cabeçalho com branch, commit e `git status`, fim `<!-- COMPLETO -->` |
| `PENDENCIAS.md` | um id por achado (`DOC-*`: Gap, Divergência, Obsoleto, Duplicado, Excesso, Fora do lugar; `INF-*`: Desvio), com evidência `arquivo:linha` e status |
| `PLANO.md` | lotes com verificação checável, decisões assumidas, `<!-- APROVADO … -->` e a situação de cada lote |
| `raw/` | saída bruta dos subagentes |

**`atualizar-docs`** — `user-invocable: false`: fora do menu. Quem a dispara é o modelo: o bloco
do `CLAUDE.md` manda chamá-la antes de todo commit, e o `cobrar-docs.sh` cobra na hora do
`git commit` (só a linha do bloco, no uso real, cobria cerca de 4% dos commits).

**`medir`** — lê `~/.claude/projects/<chave>/*.jsonl` e os `subagents/`. O modelo de cada chamada
é o efetivo pela regra do hook; chamada recusada não conta como rodada; tokens por `message.id`
(as linhas de uma resposta repetem o uso). Commits da sessão principal: reconhecidos pela regra do
`cobrar-docs.sh` (sem os do `arrumar`), refeita em regex — em forma rara os dois podem divergir, com a `atualizar-docs` chamada desde o commit anterior
ou não; tentativa que o hook recusou conta como lembrete, não como commit. Cada `message.id` é uma requisição: o custo estimado
sai da tabela `PRECO` (preço de lista por milhão, modelo casado por prefixo, escrita de cache de
1 h à parte da de 5 min); contexto = entrada + cache lido + escrita, distribuído em faixas na
sessão principal; Haiku acima de 100.000 paga a requisição inteira no preço alto. Modelo fora da
tabela não entra no custo nem nas faixas e é listado à parte. Mensagem `<synthetic>` (aviso do
Claude Code; no Code Mode, cada chamada feita de dentro do código) não é requisição: o
`tool_use` dela conta para commits e subagents, e ela fica fora de tokens, turnos e custo.

## Os opcionais — `opcional.py`

Code Mode e advisor são recursos experimentais do Claude Code. O padrão não liga nenhum dos dois
nem muda a política de modelos por causa deles: as skills `code-mode` e `advisor`
(`disable-model-invocation`: só o usuário chama) rodam o `scripts/opcional.py`, que grava ou tira
uma chave e mostra o estado.

| | Code Mode | Fable como advisor |
|---|---|---|
| Chave | `env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE: "1"` | `advisorModel` |
| Arquivo | `~/.claude/settings.json` | `.claude/settings.local.json` do projeto |
| Por que ali | o Claude Code só aceita a variável do shell, do settings do usuário ou de um `--settings`; do projeto e do local ele a descarta | a chave vale em qualquer settings, então não precisa do global; pessoal porque o Fable custa mais e pode consumir créditos de uso de quem ligou |
| Valor | `"1"`; desligar tira a chave (um `"0"` venceria até o `1` do shell) | o ID de `env.ANTHROPIC_DEFAULT_FABLE_MODEL` do `modelos/settings.json`, não o alias `fable`, que acompanha a versão do Claude Code |

- **O global ganhou uma exceção, e só uma.** O hook de abertura deixa passar a variável do Code
  Mode, o inventário a classifica como `global` e o `aplicar` a mantém. `advisorModel` no global
  segue acusado; o inventário o manda para o `settings.local.json` (destino `local`).
- **O script não conserta arquivo.** JSON inválido, ou `env` que não é objeto: para com erro e
  não grava. Regrava com a indentação e o fim de linha do original, por arquivo temporário na
  mesma pasta. Do home, o advisor é recusado: lá o `settings.local.json` seria global.
- **Advisor, medido** (v2.1.325, Windows): com `advisorModel` no `settings.local.json` de uma
  pasta, `claude -p "/advisor"` responde `Advisor: Fable 5.2`; sem ele, `Advisor: off`. No Git
  Bash o argumento precisa de `MSYS_NO_PATHCONV=1`, senão `/advisor` vira caminho e segue como
  prompt. Só da documentação: os subagents herdam o advisor (executor, revisor e coletor podem
  consultar o Fable, e o hook de modelo não vê, porque o advisor não é o `model` da chamada).

**Code Mode, medido em sessão real** (v2.1.325, Windows, uma sessão interativa em pseudo-terminal
com HOME falso, o plugin e um plugin-sonda que grava a entrada de todo hook):

- **Liga e desliga.** Com a variável gravada pelo `opcional.py` no settings do usuário, a sessão
  abre no diálogo de confirmação (a opção marcada é **No**) e depois mostra
  `Code Mode (experimental) is on`; com ele ligado, o `--continue` retoma a sessão. Desligado
  pelo script, o `--continue` é recusado com a instrução de pôr a variável em 1, e a sessão
  nova abre sem Code Mode.
- **Os hooks valem dentro do código.** O código roda numa chamada `REPL` (`tool_input.code`), e
  cada chamada que ele faz dispara `PreToolUse` e `PostToolUse` com o nome normal (`Bash`,
  `Read`, `Edit`, `Skill`, `Grep`…) e os mesmos campos. `Agent` e `Poll` (espera de código em
  segundo plano) o modelo chama direto.
- **Lembrete da documentação:** o `git commit` de dentro do código foi recusado uma vez (o
  modelo recebe a lista de chamadas recusadas, com o texto do hook), a skill rodou por
  `tools.Skill(...)` (o hook a vê como `Skill`) e o commit seguinte passou.
- **Hook de modelo:** o `Explore` sem `model` rodou em Haiku nas quatro chamadas — o
  `updatedInput` vale ali.
- **Trava de leitura:** os subagents também rodam em Code Mode (o `Explore` usou `REPL`; o
  coletor, com `tools:` fechado, fez direto a única chamada dele), e as chamadas de dentro do
  código deles chegam ao hook com `agent_type`: um `date` do `Explore` foi recusado pela trava.
  O ambiente é selado (`require` não carrega módulo; sem `process` nem `fetch`), e num agente
  sem a ferramenta `Write` a função `write()` falha com `Write tool is not available in this
  REPL context`. Por isso o `REPL` fica fora do matcher: o que grava continua passando por
  ferramenta, e cada ferramenta pelo hook.
- **`medir`:** o transcript grava cada chamada de dentro do código como mensagem `<synthetic>`
  (`isVirtual`, uso zerado) com o `tool_use` normal. Commits, lembretes, subagents e correções
  saíram iguais ao registro da sonda; `<synthetic>` não entra em tokens nem em turnos.
- **Não medido:** hook que falha ou estoura o tempo dentro do Code Mode — o
  `onFailure: "continue"` do lembrete vem da documentação; `revisor` e `leitor` (mesma
  configuração do coletor); auto mode.

**Ganho do Code Mode, medido** (v2.1.325, Windows, Opus 5.5 medium, uma cópia deste repositório
com o padrão aplicado e defeitos plantados). Três tarefas na mesma sessão, com o aceite escrito
antes: achar os links quebrados dos .md, renomear um script citado em 10 arquivos e rodar seis
verificações independentes. Custo a preço de lista, pelo transcript:

| Rodada | Requisições | Tempo | US$ | Contexto por requisição |
|---|---|---|---|---|
| sem Code Mode (3 rodadas) | 9–10 | 72–77 s | 0,39 | 49K → 61K |
| com Code Mode, cache quente (1) | 9 | 82 s | 0,34 | 26K → 39K |
| com Code Mode, cache frio (1) | 11 | 91 s | 0,47 | 26K → 39K |

- **Mesma qualidade:** as cinco rodadas passaram em todo o aceite, e o `testar.sh` do projeto
  passou depois da renomeação em todas.
- **Não poupou requisição.** Sem Code Mode o Opus já resolve cada tarefa com dois ou três
  comandos de shell (`grep | xargs sed`, um script Python no heredoc); o Code Mode embrulha os
  mesmos comandos em JavaScript.
- **O ganho vem do contexto menor:** a sessão com Code Mode abre com 26,1K tokens, contra
  48,7K da comum, e a diferença de uns 22 mil segue em toda requisição. Com o cache quente isso
  deu 13% a menos nesta sessão curta; é um valor fixo por requisição (cache lido), então pesa
  menos quanto maior o contexto da sessão.
- **Cache frio custa caro:** o prefixo do Code Mode é outro, e a primeira sessão com ele o
  regrava inteiro (26 mil tokens de escrita de 1 h) — saiu 21% mais cara que a sessão comum,
  cujo prefixo estava quente. Quem liga e desliga paga isso a cada troca.
- **Um pouco mais lento:** 82 e 91 s de relógio, contra 72 a 77 s.
- **Limites:** sessões curtas (contexto até 62K), nenhuma delegação (as tarefas eram pequenas e
  a sessão não chamou subagent), um repositório, poucas rodadas. Sessão longa, lote no
  executor e tarefa com muita chamada que o shell não faz (MCP, `WebFetch`, vários `Agent`)
  não foram medidos. Por isso a política de modelos não mudou.

## Testes

`bash scripts/testar.sh` (e o CI, no Ubuntu) confere:

- as decisões dos quatro hooks, inclusive sem `jq` e as brechas já fechadas da trava;
- o lembrete da documentação: as formas de commit do histórico, o que não é commit, a sequência
  recusa → repetição → commit seguinte, a skill liberando só a própria sessão e a falha aberta;
- que o `--sandbox` do sed e do gawk segura de verdade o que a trava deixa passar;
- o hook de abertura com HOME e projeto falsos, limpo e sujo;
- que nenhum modelo de `skills/aplicar/modelos/` mudou sem subir o carimbo (soma do texto);
- as duas status lines, o comando do `settings.json` do plugin (com o `${CLAUDE_PLUGIN_ROOT}`
  trocado), o inventário (não imprime valor do `env`) e as contas do `medir`
  (inclusive custo, faixas de contexto, Haiku acima de 100K e período sem requisição);
- os opcionais: ligar, desligar e estado do `opcional.py` com HOME e projeto falsos (o resto do
  settings, a indentação e o CRLF preservados; JSON inválido intocado; o home recusado), a
  variável do Code Mode calada no hook de abertura e o `onFailure` de cada hook no `hooks.json`.

O CI tem ainda um job `diagramas`, que passa todo bloco Mermaid dos .md pelo parser oficial
(`.github/scripts/validar-mermaid.mjs`, com `mermaid` e `jsdom` instalados só ali). O parser não
vê layout: diagrama novo, abra numa página local antes, porque largo demais fica ilegível no
GitHub e título de bloco (`subgraph`) longo é cortado.

Não cobre o texto das skills. Para elas, o **teste de ponta a ponta**:

1. Projeto de exemplo no scratchpad, com documentação errada de propósito, e um HOME falso com
   um global sujo (modelo, effort, token, MCP, memória, `CLAUDE.md` global).
2. `claude -p --plugin-dir <este repo> --dangerously-skip-permissions --output-format json`,
   com `HOME` e `USERPROFILE` apontando para o HOME falso, sem as variáveis `CLAUDE*` da sessão
   e o login por `CLAUDE_CODE_OAUTH_TOKEN` — o `accessToken` do `.credentials.json`, só na env:
   não copie o arquivo, que tem o refresh token e tokens de MCP.
3. Etapa que pede OK: `--resume <session_id> "<resposta>"` (no `-p` não há `AskUserQuestion`).
4. Confira o resultado com scripts (arquivos, commits, `conferir-padrao.sh` calado) e que o
   `~/.claude` real não mudou. Uma rodada completa (`aplicar`, hooks, `arrumar`) custa ~US$ 4.
5. Lembrete da documentação: peça uma mudança com commit autorizado num projeto com o padrão
   aplicado e confira no transcript a ordem das chamadas. Com o bloco inteiro, `Skill` antes do
   `git commit` e nenhuma recusa; com o bloco sem a linha "Antes de todo commit", recusa →
   `Skill` → commit. O que o hook recebe (campos, `if`, `CLAUDE_PLUGIN_DATA`) se sonda com um
   plugin de um hook só que grava a entrada, num `--plugin-dir` a mais.

O que só a interface mostra (linha dos subagents, status line, diálogos) não aparece no
`claude -p`. Para isso, uma sessão interativa num pseudo-terminal: um script Node com
`@lydell/node-pty` (sobe o `claude` com o HOME falso e o token na env) e `@xterm/headless`
(remonta a tela), gravando a tela em texto a cada mudança. No HOME falso, ponha
`hasTrustDialogAccepted` para a pasta em `.claude.json` e `skipDangerousModePermissionPrompt`
no settings, senão a sessão para nos diálogos de abertura. É o único jeito de testar o Code
Mode, que não roda em `claude -p`: o diálogo dele abre com **No** marcado (seta para baixo e
Enter — confira na tela o cursor no **Yes** antes do Enter e o aviso `is on` depois: seta
mandada cedo demais se perde, e a sessão abre sem Code Mode). `autoUpdates: false` no `.claude.json` falso vira `env.DISABLE_AUTOUPDATER` no settings
global, e o hook de abertura acusa. Com um servidor de linguagem instalado, o diálogo de LSP
aparece no meio da sessão. Texto que começa por `/` (`/exit`) passado pelo Git Bash ao script
que digita na sessão pede `MSYS_NO_PATHCONV=1`.

**`claude plugin eval`: ensaiado, não adotado** (v2.1.322, Windows, três casos de teste). Roda
com a assinatura, guarda o relatório local e custa ~US$ 0,10 por rodada, mas não alcança o que
este plugin precisa testar:

- caso que pede Bash é recusado no Windows nativo, porque não há sandbox (`no sandbox backend on
  this platform`). É onde mora quase tudo: o lembrete do commit, o `aplicar`, o `arrumar`, o
  `medir`. Em Linux, macOS ou WSL2 roda; em CI pede API key, `bubblewrap` e `socat`;
- nada de projeto carrega na rodada (`CLAUDE.md`, `.claude/`): as regras do bloco ficam de fora,
  e o hook de abertura acusa "padrão fora do lugar" em toda rodada;
- os arquivos de `context.add_dirs` não aparecem na pasta de trabalho: o Claude não os achou em
  nenhuma rodada; fixture pede `scaffold_script`.

O que rodou: a `atualizar-docs` foi chamada por frase natural só com o plugin carregado, e o
`Explore` rodou em Haiku pelo hook de modelo (no `trace` isso aparece no `model` das mensagens
do subagent; o texto do hook não entra). Vale rever quando o time tiver máquina com sandbox ou
quando o sandbox do Windows sair de trás do `feature gate` que a recusa cita.

No Windows, o caminho do HOME falso no scratchpad passa de 260 caracteres dentro de
`.claude/projects/`: Python e o `jq` nativo não abrem — leia com `cat arquivo | jq` e, para o
`medir`, copie os transcripts para um HOME curto.

## Publicar

Suba a `version` em `.claude-plugin/plugin.json` (semver) a cada mudança publicada — o
marketplace pina por ela, e o aviso de versão nova compara com ela —, rode os testes e dê push.
Mudou `claude-md.md` ou `agente/padrao-*.md`: suba o `modelo X` da 1ª linha para a versão nova e
registre-o com a soma em `scripts/testar.sh` — é o carimbo que faz o hook de abertura avisar o
projeto que ficou com o texto antigo.
O `marketplace.json` publica este mesmo diretório (`source: "./"`).
