# padrao — padrão de Claude Code (desenvolvimento)

Plugin **sem MCP**: hooks, agents, skills e status line que aplicam a política de
modelos (Opus decide, Sonnet executa, Haiku coleta) e a regra "tudo no projeto,
global limpo". Uso, instalação e migrações: `README.md`.

## Mapa

| Caminho | Conteúdo |
|---|---|
| `hooks/hooks.json` | SessionStart → `conferir-padrao.sh`; PreToolUse `Agent` → `travar-modelo-subagent.sh`; PreToolUse `Bash\|PowerShell` → `trava-leitura.sh` |
| `scripts/conferir-padrao.sh` | só avisa (nunca corrige): global sujo, modelos fora da 5.5, conectores/plugins do app claude.ai ligados, auto memory ligado ou `fallbackModel` no projeto, versão nova no marketplace |
| `scripts/travar-modelo-subagent.sh` | corrige `Plan`=opus e `Explore`, `padrao:coletor` e `padrao:leitor`=haiku (`updatedInput`); recusa `model` fora de haiku/sonnet/opus; sem `model` vale o `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`; `fork` passa |
| `scripts/trava-leitura.sh`, `so-le.sh`, `segmentos.sh` | trava de leitura dos agentes que só leem (coletor, revisor, leitor, `Explore`): Bash por segmento contra uma lista de comandos de leitura, PowerShell fechado |
| `scripts/py.sh` | acha `python3`/`python`/`py` 3.9+ e roda com `-I` |
| `agents/` | `coletor` (haiku), `leitor` (haiku, sem CLAUDE.md), `revisor` (sonnet), `executor` (sonnet) |
| `skills/` | `aplicar` (+ `inventariar.py`, `modelos/`), `atualizar-docs`, `auditar`, `enxugar-docs`, `executar-lote`, `medir` (+ `medir-modelos.py`) |
| `statusline/` | `statusline.py` (principal) e `subagent-statusline.py`; instalados em `~/.claude/` pela skill `aplicar` |
| `AGENT_LEARNINGS.md` | erros do agente neste repositório e a abordagem certa; lido sob demanda (modelo e `docs/agente/padrao-*.md` em `skills/aplicar/modelos/`) |

## Regras

- Scripts em sh/bash POSIX com awk e sed; no Windows rodam no **Git Bash**. `jq` é
  obrigatório: sem ele a trava fecha os agentes que só leem e a conferência do padrão se cala —
  mantenha esse comportamento (falhar fechado).
- Python só biblioteca padrão, 3.9+, sempre via `scripts/py.sh`.
- `version` no `.claude-plugin/plugin.json`: o aviso de versão nova compara com ela.
  Toda mudança publicada sobe a `version` (semver). O `marketplace.json` da raiz
  publica este mesmo diretório (`source: "./"`).
- `statusline/statusline.py` é código de terceiro (Jhonatan de Souza) sem licença
  declarada: mantenha o crédito e não publique o repositório.
- Settings de plugin descartam `model` e `effortLevel`; por isso a skill `aplicar`
  grava no `.claude/settings.json` do projeto.
- Arquivos em LF (`.gitattributes`).
- `AGENT_LEARNINGS.md` não carrega sozinho: leia antes de tarefa que altera arquivos; quando um
  erro seu custar retrabalho, registre-o lá no formato do arquivo.

## Testes

`bash scripts/testar.sh`: confere as decisões dos
três hooks (inclusive sem `jq`; o `conferir-padrao.sh` com HOME falso) e as duas status
lines. Não cobre `inventariar.py`, `medir-modelos.py` nem o texto das skills.
Depois: `claude plugin validate .`.
