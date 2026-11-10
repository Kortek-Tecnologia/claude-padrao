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
| `hooks/hooks.json` | SessionStart → `conferir-padrao.sh`; PreToolUse `Agent` → `travar-modelo-subagent.sh`; PreToolUse Bash, PowerShell, `mcp__*` e as ferramentas que executam ou gravam (regex no matcher) → `trava-leitura.sh` |
| `scripts/conferir-padrao.sh` | só avisa (nunca corrige): global sujo (o effort salvo pelo `/effort` passa: o projeto vence), modelos fora da 5.5, conectores/plugins do app claude.ai ligados, auto memory ligado, checkpoints desligados ou `fallbackModel` no projeto, bloco do `CLAUDE.md` ou `docs/agente/padrao-*.md` de outro modelo (carimbo), versão nova no marketplace |
| `scripts/travar-modelo-subagent.sh` | corrige `Plan`=opus, `Explore`/`coletor`/`leitor`=haiku e `revisor`/`executor`=sonnet (`updatedInput`); recusa `model` fora de haiku/sonnet/opus (o Fable 5.2 é degrau só da sessão); sem `model` vale o `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`; `fork` passa |
| `scripts/trava-leitura.sh`, `so-le.sh`, `segmentos.sh` | trava de leitura dos agentes que só leem (coletor, revisor, leitor, `Explore`): Bash por segmento contra uma lista de comandos de leitura (sed e awk só com `--sandbox`), qualquer outra ferramenta do matcher fechada |
| `scripts/py.sh` | acha `python3`/`python`/`py` 3.9+ e roda com `-I` |
| `agents/` | `coletor` (haiku), `leitor` (haiku, sem CLAUDE.md), `revisor` (sonnet), `executor` (sonnet) |
| `skills/` | os três comandos — `aplicar` (+ `inventariar.py`, `modelos/`), `arrumar` (levanta, um OK, executa tudo) e `medir` (+ `medir-modelos.py`) — e `atualizar-docs`, fora do menu: o Claude a chama antes de commitar |
| `statusline/` | `statusline.py` (principal) e `subagent-statusline.py`; instalados em `~/.claude/` pela skill `aplicar` |
| `docs/como-funciona.md` | para quem mantém: peças, decisões dos hooks, skills, testes e publicação (o README é para quem usa) |
| `AGENT_LEARNINGS.md` | erros do agente neste repositório e a abordagem certa; lido sob demanda (modelo e `docs/agente/padrao-*.md` em `skills/aplicar/modelos/`) |

## Regras

- Scripts em sh/bash POSIX com awk e sed; no Windows rodam no **Git Bash**. `jq` é
  obrigatório: sem ele a trava fecha os agentes que só leem e a conferência do padrão se cala —
  mantenha esse comportamento (falhar fechado).
- Python só biblioteca padrão, 3.9+, sempre via `scripts/py.sh`.
- `version` no `.claude-plugin/plugin.json`: o aviso de versão nova compara com ela.
  Toda mudança publicada sobe a `version` (semver). O `marketplace.json` da raiz
  publica este mesmo diretório (`source: "./"`).
- Repositório público, licença MIT (`LICENSE`). `statusline/statusline.py` é código de
  terceiro (Jhonatan de Souza), usado com permissão e fora da MIT: mantenha o crédito.
- Settings de plugin descartam `model` e `effortLevel`; por isso a skill `aplicar`
  grava no `.claude/settings.json` do projeto.
- Mudou `claude-md.md` ou `agente/padrao-*.md` em `skills/aplicar/modelos/`: suba o carimbo
  `modelo X` da 1ª linha para a versão nova e registre-o com a soma em `scripts/testar.sh` (o
  teste cobra). O hook de abertura compara só o carimbo: sem subir, projeto antigo não é avisado.
- Arquivos em LF (`.gitattributes`).
- `AGENT_LEARNINGS.md` não carrega sozinho: leia antes de tarefa que altera arquivos; quando um
  erro seu custar retrabalho, registre-o lá no formato do arquivo.

## Testes

`bash scripts/testar.sh`: confere as decisões dos
três hooks (inclusive sem `jq`; o `conferir-padrao.sh` com HOME falso), as duas status
lines, que nenhum modelo mudou sem subir o carimbo, que o inventário não imprime valor do `env`
e as contas do `medir-modelos.py` (tokens, custo a preço de lista, faixas de contexto). Não cobre
o texto das skills. Depois: `claude plugin validate .`. O CI (`.github/workflows/testes.yml`)
roda o `testar.sh` no Ubuntu: lá o sh é dash e o awk pode ser mawk. As skills se testam de ponta
a ponta num sandbox: roteiro em `docs/como-funciona.md#testes`.
