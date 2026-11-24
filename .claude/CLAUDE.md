# padrao — padrão de Claude Code (desenvolvimento)

Plugin **sem MCP**: hooks, agents, skills e status line que aplicam a política de
modelos (Opus decide, Sonnet executa lote com ficha, Haiku coleta) e a regra "tudo no projeto,
global limpo". Uso, instalação e migrações: `README.md`. Como as peças se ligam, a árvore de
decisão de cada hook e o teste de ponta a ponta das skills: `docs/como-funciona.md` — leia antes
de mexer em hook, skill ou teste. Mudou comportamento: atualize o README e esse doc no mesmo
commit (o CI valida os diagramas Mermaid; `.github/scripts/validar-mermaid.mjs`).

## Mapa

| Caminho | Conteúdo |
|---|---|
| `hooks/register.ts` | mod da linha dos subagents (TypeScript; hook `ui.render` em `AgentRow`, 2.1.326+), declarado em `modules` no `hooks.json`; testes em `hooks/register.test.tsx` (`claude plugin test .`) |
| `hooks/hooks.json` | SessionStart → `conferir-padrao.sh`; PreToolUse `Agent` → `travar-modelo-subagent.sh`; PreToolUse Bash, PowerShell, `mcp__*` e as ferramentas que executam ou gravam (regex no matcher) → `trava-leitura.sh`; PreToolUse `Skill` e Bash/PowerShell com `git` (`if`) → `cobrar-docs.sh`; Stop → `cobrar-pergunta.sh`; PreCompact → `instruir-compactacao.sh` |
| `scripts/conferir-padrao.sh` | só avisa (nunca corrige): global sujo (o effort salvo pelo `/effort` passa: o projeto vence; de `env`, só a variável do Code Mode), modelos fora da 5.5, conectores/plugins do app claude.ai ligados, auto memory ligado, checkpoints desligados ou `fallbackModel` no projeto, regra de `permissions.deny` do padrão ausente, bloco do `CLAUDE.md` ou `docs/agente/padrao-*.md` de outro modelo (carimbo), versão nova no marketplace |
| `scripts/travar-modelo-subagent.sh` | corrige `Plan`=opus, `Explore`/`coletor`/`leitor`=haiku e `revisor`/`executor`=sonnet (`updatedInput`); recusa `model` fora de haiku/sonnet/opus (o Fable 5.2 e o Mythos 5.2 são degrau só da sessão); sem `model` vale o `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`; `fork` passa |
| `scripts/trava-leitura.sh`, `so-le.sh`, `so-le.awk`, `segmentos.awk`, `segmentos.sh` | trava de leitura dos agentes que só leem (coletor, revisor, leitor, `Explore`): Bash por segmento contra uma lista de comandos de leitura (sed e awk só com `--sandbox`), qualquer outra ferramenta do matcher fechada. A regra mora em `so-le.awk` (decide sobre as palavras sem aspas, como o shell as entrega) e o corte em `segmentos.awk` (acompanha aspas, `$(...)` e comentário; o que não acompanha — crase, heredoc, `$"…"` — nega o comando inteiro) (um jq e um awk por chamada; POSIX awk, sem `[[:classe:]]` nem `{n}`); `segmentos.sh` é o `segmentar` do `cobrar-docs.sh`, sobre o mesmo awk |
| `scripts/cobrar-docs.sh` | lembrete da documentação: `git commit` sem a `padrao:atualizar-docs` desde o commit anterior é recusado uma vez (a repetição passa); anotação por sessão em `${CLAUDE_PLUGIN_DATA}`; falha aberta; não cobra os lotes do `arrumar` nem a mudança só de documentação (pelo `git status` da pasta da sessão) |
| `scripts/instruir-compactacao.sh` | instrução do resumo da compactação (evento `PreCompact`, stdout): uma lista para a sessão e outra para o subagent (entrada com `agent_type`); cala no `/compact <foco>`; sem `jq`, sem abrir processo, nunca bloqueia |
| `scripts/cobrar-pergunta.sh` | lembrete das pendências (evento `Stop`): resposta final com oferta ou pendência em aberto é recusada uma vez por turno, mandando só perguntar no `AskUserQuestion` (nada além disso por conta própria); detecção por frases (pt e en); falha aberta |
| `scripts/py.sh` | acha `python3`/`python`/`py` 3.9+ e roda com `-I` |
| `scripts/opcional.py` | os dois opcionais, fora da política de modelos e desligados por padrão: Code Mode (`env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE` no settings global, o único em que vale) e Fable como advisor (`advisorModel` no `.claude/settings.local.json` do projeto); liga, desliga e mostra o estado |
| `agents/` | `coletor` (haiku), `leitor` (haiku, sem CLAUDE.md), `revisor` (sonnet), `executor` (sonnet); coletor e leitor compactam aos 100K (`autoCompactWindow`) |
| `skills/` | os comandos — `aplicar` (+ `inventariar.py`, `modelos/`), `arrumar` (levanta, um OK, executa tudo; o `SKILL.md` fica abaixo de 15 KB para voltar inteiro depois da compactação, com a fase 1 em `levantar.md`, as regras de documentação em `regras-docs.md`, em `checagens.md` os desvios de segurança e de CI da trilha B e, em `padronizacao.md`, os de estrutura de arquivos por convenção e de versões fixadas), `reorganizar` (executa a lista "de → para" de arquivos-fonte que o `arrumar` deixa no relatório; só com verificação que roda), `medir` (+ `medir-modelos.py`) e os opcionais `code-mode` e `advisor` (só chamam o `opcional.py`) — e `atualizar-docs`, fora do menu: o Claude a chama antes de commitar (o `cobrar-docs.sh` cobra), e ela roda num subagent em Sonnet (`context: fork`) |
| `statusline/` | `statusline.py` (principal; a skill `aplicar` a instala em `~/.claude/`). A linha dos subagents é só o mod (`hooks/register.ts`): a reserva `subagentStatusLine` saiu na 2.13.0 |
| `avaliacao/revisor/` | avaliação do `padrao:revisor` com defeitos plantados (18 casos): projeto de exemplo (`base/`), os casos (`casos.py`) e o `avaliar.py` (`--conferir` não custa; a rodada de verdade abre uma sessão por caso) |
| `docs/como-funciona.md` | para quem mantém: peças, decisões dos hooks, skills, testes e publicação (o README é para quem usa) |
| `AGENT_LEARNINGS.md` | erros do agente neste repositório e a abordagem certa; lido sob demanda (modelo e `docs/agente/padrao-*.md` em `skills/aplicar/modelos/`) |

## Regras

- Scripts em sh/bash POSIX com awk e sed; no Windows rodam no **Git Bash**. `jq` é
  obrigatório: sem ele a trava fecha os agentes que só leem e a conferência do padrão se cala —
  mantenha esse comportamento (falhar fechado). O lembrete da documentação é o contrário de
  propósito: falha aberto, porque commit preso é pior que doc velha.
- Hook roda em toda chamada, e no Windows abrir um processo custa de 100 a 800 ms: leia a
  entrada com o `read` do shell e não abra `cat`, `sed` ou `ls` onde um `case` ou um glob resolve.
- Python só biblioteca padrão, 3.9+, sempre via `scripts/py.sh`.
- TypeScript só no mod (`hooks/register.ts`): sem dependência, sem Node nem DOM — tudo de fora vem pelo `$`. A API é de acesso antecipado: confira com `claude plugin validate .` e `claude plugin test .` a cada versão do Claude Code.
- `version` no `.claude-plugin/plugin.json`: o aviso de versão nova compara com ela.
  Toda mudança publicada sobe a `version` (semver). O `marketplace.json` da raiz
  publica este mesmo diretório (`source: "./"`).
- Repositório público, licença MIT (`LICENSE`). `statusline/statusline.py` é código de
  terceiro (Jhonatan de Souza), usado com permissão e fora da MIT: mantenha o crédito.
- Settings de plugin descartam `model` e `effortLevel`; por isso a skill `aplicar`
  grava no `.claude/settings.json` do projeto. O plugin não traz `settings.json` na raiz
  (dele só valeriam `agent` e o `subagentStatusLine`, obsoleto); `subagentStatusLine` no global
  é chave fora do padrão.
- Este arquivo mora em `.claude/` porque a raiz do repositório é a raiz do plugin: `CLAUDE.md`
  ali o `claude plugin validate` acusa (não é contexto do plugin). O validador tem de passar
  sem aviso nenhum (`claude plugin validate --strict .`).
- Mudou `claude-md.md` ou `agente/padrao-*.md` em `skills/aplicar/modelos/`: suba o carimbo
  `modelo X` da 1ª linha para a versão nova e registre-o com a soma em `scripts/testar.sh` (o
  teste cobra). O hook de abertura compara só o carimbo: sem subir, projeto antigo não é avisado.
- Arquivos em LF (`.gitattributes`).
- Este repositório usa o próprio padrão: `.claude/settings.json`, o bloco no fim deste arquivo e
  `docs/agente/padrao-*.md` são cópias de `skills/aplicar/modelos/` (o `testar.sh` cobra que
  sigam iguais — mudou o modelo, copie de novo). O plugin que roda nas sessões daqui é o
  publicado no marketplace, não a árvore de trabalho; para exercitar a árvore, `--plugin-dir .`.

## Testes

`bash scripts/testar.sh`: confere as decisões dos
seis hooks (inclusive sem `jq`; o `conferir-padrao.sh` com HOME falso), a status
line principal, que nenhum modelo mudou sem subir o carimbo, que o inventário não imprime valor do `env`,
as contas do `medir-modelos.py` (tokens, custo a preço de lista, faixas de contexto, advisor), o
`opcional.py` (liga, desliga, não toca em JSON inválido) e que os casos da avaliação do revisor
estão de pé (`avaliar.py --conferir`). Não cobre
o texto das skills. Depois: `claude plugin validate --strict .`. O CI (`.github/workflows/testes.yml`)
roda o `testar.sh` no Ubuntu (lá o sh é dash e o awk pode ser mawk) e no Windows. As skills se testam de ponta
a ponta num sandbox: roteiro em `docs/como-funciona.md#testes`.

<!-- padrao:inicio — gerado pelo plugin padrao (/padrao:aplicar), modelo 2.15.0; edite no plugin, não aqui -->
## Claude Code: padrão do projeto

Configuração só no projeto (`.claude/settings.json` time, `.claude/settings.local.json`
pessoal); global limpo. Se o hook do plugin `padrao` avisar que algo saiu do lugar (o `/model`
grava no global), peça ao usuário para rodar `/padrao:aplicar`: só ele chama esse comando.

**Opus decide, Sonnet executa lote com ficha, Haiku coleta** — subagent sem `model` roda em sonnet; coleta pede `haiku`.

| Papel | Agente |
|---|---|
| decidir e o difícil — plano, arquitetura, bug sem pista; a mudança de poucas chamadas de ferramenta, em sessão ainda curta | a sessão (opus); `Plan` |
| executar lote com ficha fechada (arquivos, mudança, aceite, verificação que roda): o de muitos passos, e todo lote quando a sessão já está longa | `padrao:executor` (sonnet) |
| revisar diff grande ou arriscado, antes do commit | `padrao:revisor` (sonnet, só lê) |
| coletar — busca, leitura, log, saída de CI | `padrao:coletor` (haiku, só lê); `Explore` |

### Decida e siga; pare só no irreversível

- **Reversível → siga com a recomendada.** Editar código e arquivos do projeto, criar branch,
  rodar teste, build e comando local, instalar dependência no projeto, repetir o comando seguro
  que falhou por erro passageiro: escolha a opção que você recomendaria, faça e conte depois.
- **Irreversível → pare e pergunte:** commit, push, merge, deploy, publicar, apagar o que você
  não criou, dado de produção, mexer no global (`~/.claude`), mensagem para uma pessoa fora da
  sessão (e-mail, chat, comentário em PR ou issue), compra, serviço pago ou recurso de nuvem que
  gera cobrança.
  Antes de todo commit, a skill `padrao:atualizar-docs` acerta a doc que o diff deixou falsa.
  Autorizado uma vez, vale até o fim daquele trabalho (subagent incluso: cite a autorização);
  volte só se o risco for maior do que o usuário aprovou.
- **Dúvida que um comando responde, rode o comando.** Pergunta cuja resposta só pode ser "sim",
  siga sem perguntar.
- **No meio do trabalho, pergunte só gosto ou produto que só o usuário decide:** uma pergunta
  por vez, no `AskUserQuestion`, com a recomendada primeiro. Enquanto espera, adiante o que não
  depende dela.
- **No relatório final, liste as decisões tomadas sozinho** que o usuário pode querer desfazer.

### Ao encerrar: pergunta com opções, não pendência em aberto

A resposta que terminaria com "não fiz commit", "quer que eu…?", "posso…", "falta…" ou
"sugiro…" termina com uma chamada `AskUserQuestion` no lugar da frase: uma pergunta por
pendência, a opção recomendada primeiro, com "(Recomendado)" no rótulo, e "deixar como está"
entre elas. O que é reversível e
do pedido, faça antes, sem perguntar. Sem a ferramenta (`claude -p`), liste as opções com a
recomendada marcada. Um hook do plugin lembra disso uma vez por turno.

### Contexto sob demanda

Estes arquivos não carregam sozinhos: leia o que a tarefa pedir, quando pedir.

| Arquivo | Leia quando |
|---|---|
| `AGENT_LEARNINGS.md` | antes de tarefa que altera arquivos; e ao errar, para registrar (formato no arquivo) |
| `docs/agente/padrao-modelos.md` | antes de delegar a subagent, montar Workflow ou propor subir effort ou modelo |
| `docs/agente/padrao-configuracao.md` | ao mexer em settings, plugins, MCP, memória ou status line |

Registre em `AGENT_LEARNINGS.md` todo erro que custou retrabalho (o usuário corrigiu, comando ou
teste falhou por suposição errada, hook recusou, algo refeito); subagent devolve o erro e a
sessão registra. Contexto do projeto que não vale em toda sessão não engorda este arquivo: vai
para `docs/agente/<tema>.md`, com uma linha "Leia quando" na seção do projeto
`## Contexto sob demanda` (fora deste bloco); regra presa a caminhos vai para `.claude/rules/`
com `paths:`.

### Compact instructions

Ao compactar, preserve: o plano aprovado e o que falta dele, as decisões tomadas (e as que o
usuário pode querer desfazer), os arquivos alterados e a saída real da última verificação.
<!-- padrao:fim -->
