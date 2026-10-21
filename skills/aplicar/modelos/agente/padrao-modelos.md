<!-- gerado pelo plugin padrao (/padrao:aplicar); edite no plugin, não aqui -->
# Modelos e delegação

Tudo na família **5.5, com 1M de contexto** (nativo nela), fixado no `.claude/settings.json`:
a sessão principal é Opus 5.5 1M effort medium; subagents Sonnet 5.5 e Haiku 5.5 effort medium;
sem fallback de modelo (sem a chave `fallbackModel`, nada troca de modelo sozinho). Os aliases
dos subagents apontam para `claude-opus-5-5`, `claude-sonnet-5-5` e `claude-haiku-5-5`
(`env.ANTHROPIC_DEFAULT_*_MODEL`), então `model: haiku` é Haiku 5.5 1M — e não muda sozinho
quando sair versão nova. Subagent sem `model` roda em sonnet (`CLAUDE_CODE_SUBAGENT_MODEL`), não
no Opus da sessão; agente com `model:` no frontmatter usa o dele; o `fork` roda no da sessão.
Coleta pede `haiku` explícito. O hook corrige `Plan` para opus e `Explore`, coletor e leitor
para haiku e recusa `model` fora de `haiku|sonnet|opus`.

| Papel | Modelo | Agente |
|---|---|---|
| decidir e o difícil — plano, arquitetura, revisão de invariante, bug sem pista | `opus` | a sessão; `Plan` |
| executar plano JÁ montado — implementação delimitada | `sonnet` | `padrao:executor` |
| revisar diff contra plano e critério de aceite | `sonnet` | `padrao:revisor` (só lê) |
| coletar — busca, leitura, resumo de log, saída de CI | `haiku` | `padrao:coletor` (só lê); `Explore` |

Travados no hook: `Plan` em opus; `Explore`, coletor e leitor em haiku. Coletor, leitor,
revisor e `Explore` só LEEM: o Bash deles passa por uma trava que recusa gravar, redirecionar e executar programa; PowerShell
fechado. Coleta que exige julgamento ou escrita vai num `general-purpose` com sonnet.

Delegue o que é grande, independente ou barulhento (leitura ampla, log longo, implementação de
plano pronto); não delegue o que você termina em poucas chamadas de ferramenta, nem para conferir
o próprio trabalho. Um subagent basta? Use um. Subagent não abre subagent
(`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`). Gatilhos de delegar:

1. CI reprovou, saída de teste/medição, log longo → `padrao:coletor` devolve a falha com `arquivo:linha`.
2. Plano aprovado → `padrao:executor` implementa; `padrao:revisor` revisa; o Opus decide o que fica.

- **Opus → executor:** arquivos, o que muda, critério de aceite, os comandos de verificação e as
  entradas de `AGENT_LEARNINGS.md` que valem para a tarefa (subagent não lê esse arquivo
  sozinho). Faltando, o sonnet decide — e decidir é do Opus.
- **Coletor coleta, não conclui:** peça fatos com `arquivo:linha`; o Opus confere a linha antes de agir.
- **Workflow:** nomeie o modelo de cada `agent()` — o hook não alcança dentro do Workflow, e sem
  isso o agente herda o Opus.
- **Medir:** `/padrao:medir` (haiku em zero = coleta não delegada).
