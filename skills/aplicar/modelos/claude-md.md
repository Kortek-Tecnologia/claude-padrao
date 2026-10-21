<!-- padrao:inicio — gerado pelo plugin padrao (/padrao:aplicar); edite no plugin, não aqui -->
## Claude Code: padrão do projeto

Configuração só no projeto (`.claude/settings.json` time, `.claude/settings.local.json`
pessoal); global limpo. Se o hook do plugin `padrao` avisar que algo saiu do lugar (o `/model`
grava no global), rode `/padrao:aplicar`.

**Opus decide, Sonnet executa, Haiku coleta** — subagent sem `model` roda em sonnet; coleta pede `haiku`.

| Papel | Agente |
|---|---|
| decidir e o difícil — plano, arquitetura, bug sem pista | a sessão (opus); `Plan` |
| executar plano JÁ montado | `padrao:executor` (sonnet) |
| revisar diff contra o plano | `padrao:revisor` (sonnet, só lê) |
| coletar — busca, leitura, log, saída de CI | `padrao:coletor` (haiku, só lê); `Explore` |

### Contexto sob demanda

Estes arquivos NÃO carregam sozinhos: leia o que a tarefa pedir, quando pedir.

| Arquivo | Leia quando |
|---|---|
| `AGENT_LEARNINGS.md` | antes de tarefa que altera arquivos; e ao errar, para registrar (formato no arquivo) |
| `docs/agente/padrao-modelos.md` | antes de delegar a subagent ou montar Workflow |
| `docs/agente/padrao-configuracao.md` | ao mexer em settings, plugins, MCP, memória ou status line |

Registre em `AGENT_LEARNINGS.md` todo erro que custou retrabalho (o usuário corrigiu, comando ou
teste falhou por suposição errada, hook recusou, algo refeito); subagent devolve o erro e a
sessão registra. Contexto do projeto que não vale em toda sessão não engorda este arquivo: vai
para `docs/agente/<tema>.md`, com uma linha "Leia quando" na seção do projeto
`## Contexto sob demanda` (fora deste bloco); regra presa a caminhos vai para `.claude/rules/`
com `paths:`.
<!-- padrao:fim -->
