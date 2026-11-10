<!-- gerado pelo plugin padrao (/padrao:aplicar), modelo 2.2.0; edite no plugin, não aqui -->
# Modelos e delegação

Tudo na família **5.5, com 1M de contexto** (nativo nela), fixado no `.claude/settings.json`:
a sessão principal é Opus 5.5 1M effort medium; subagents Sonnet 5.5 e Haiku 5.5 effort medium.
A compactação automática do Opus acontece aos 400K
(`modelSettings["claude-opus-5-5"].autoCompactWindow`), não perto de 1M: cada requisição relê o
contexto inteiro. Sessão que precisar de mais abre com `claude --autocompact 1M`.
Sem a chave `fallbackModel`, indisponibilidade não troca de modelo; a única troca automática é a
de segurança: mensagem sinalizada (cibersegurança, biologia) é refeita num modelo anterior, com
aviso no transcript (`switchModelsOnFlag: false` no `settings.local.json` faz perguntar antes).
Os aliases apontam para `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5` e
`claude-fable-5-2` (`env.ANTHROPIC_DEFAULT_*_MODEL`), então `model: haiku` é Haiku 5.5 1M — e não
muda sozinho quando sair versão nova. Subagent sem `model` roda em sonnet
(`CLAUDE_CODE_SUBAGENT_MODEL`), não no Opus da sessão; agente com `model:` no frontmatter usa o
dele; o `fork` roda no da sessão. Coleta pede `haiku` explícito. O hook corrige `Plan` para opus,
`Explore`, coletor e leitor para haiku, revisor e executor para sonnet, e recusa `model` fora de
`haiku|sonnet|opus`.

## Quando a tarefa pede mais

Toda sessão abre no Opus em medium — o projeto vence o global. Suba um degrau por vez, na
própria sessão; a próxima volta ao padrão:

1. **Verificação que roda** (teste, build, script). Sem ela, mais effort só gasta mais.
2. **Um nível de effort:** `/effort high` (com `s` no seletor nem grava no global) para bug em
   código antigo ou caso de borda; `ultrathink` no prompt sobe só aquele turno. Mais effort não
   conserta abordagem errada: aí replaneje.
3. **Passou de high, troque de modelo** em vez de ir a xhigh ou max: abra `/model`, escolha o
   Fable e tecle `s` (só a sessão; Enter ou `/model fable` gravam no global, e o hook de abertura
   acusa). No Fable, medium para o trabalho interativo e high para a parte difícil ou longa sem
   supervisão: quase todo o ganho dele já está em high, e xhigh rende pouco por muito mais
   tokens — só com ganho medido. Serve a refactor ou migração grande e a arquitetura. Custa o
   dobro do Opus em entrada e saída (o cache lido custa o mesmo) e, conforme o plano, consome
   créditos de uso (o seletor avisa). Troque numa pausa, depois de `/compact` ou em sessão nova
   com o plano: o cache é por modelo, e a primeira resposta no Fable relê a conversa inteira sem
   cache. Em subagent o Fable segue recusado.

## Quem faz o quê

| Papel | Modelo | Agente |
|---|---|---|
| decidir e o difícil — plano, arquitetura, revisão de invariante, bug sem pista; a mudança de poucas chamadas de ferramenta, em sessão ainda curta | `opus` | a sessão; `Plan` |
| executar lote com ficha fechada (arquivos, mudança, critério de aceite, verificação que roda): o de muitos passos, e todo lote quando a sessão já está longa | `sonnet` | `padrao:executor` |
| revisar diff grande ou arriscado contra plano e critério de aceite | `sonnet` | `padrao:revisor` (só lê) |
| coletar — busca, leitura, resumo de log, saída de CI | `haiku` | `padrao:coletor` (só lê); `Explore` |

Travados no hook: `Plan` em opus; `Explore`, coletor e leitor em haiku; revisor e executor
em sonnet. Coletor, leitor, revisor e `Explore` só LEEM: o Bash deles passa por uma trava que
recusa gravar, redirecionar e executar programa (sed e awk só com `--sandbox` logo após o nome);
PowerShell, MCP e as ferramentas que executam ou gravam (Monitor, Workflow, CronCreate…)
fechados. Coleta que exige julgamento ou escrita vai num `general-purpose` com sonnet.

Decisão fica na sessão; execução com ficha fechada vai para o executor. Cada requisição da
sessão relê o contexto inteiro dela, e o que um lote lê e escreve fica nesse contexto dali em
diante: o mesmo lote sai mais barato num subagent de contexto pequeno, e a diferença cresce com
o tamanho da sessão. Em sessão ainda curta, o lote de poucas chamadas você mesmo faz: abrir o
subagent custaria mais que ele. Modelo menor vai para o que tem erro barato de notar (achar
arquivo, rodar teste, ler log) ou para ficha fechada com verificação. Não delegue mudança
acoplada ao que acabou de ler nem o que pede decisão no meio. Um subagent basta? Use um; lotes em
paralelo, só com arquivos disjuntos. Subagent não abre subagent
(`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`). Gatilhos de delegar:

1. CI reprovou, saída de teste/medição, log longo → `padrao:coletor` devolve a falha com `arquivo:linha`.
2. Plano aprovado → `padrao:executor` implementa o lote com ficha fechada (arquivos, mudança,
   critério de aceite, verificação que roda) quando ele tem muitos passos ou a sessão já está
   longa (muita leitura, muitos turnos). Lote de poucas chamadas em sessão curta, mudança
   acoplada ao que você acabou de ler ou com decisão no meio: faça você.
3. Diff grande (passa de ~200 linhas ou de 5 arquivos) ou arriscado (segurança, permissão, dado
   persistente, contrato público, concorrência) → `padrao:revisor` antes do commit, quem quer
   que tenha escrito. Diff pequeno segue sem ele.

- **Opus → executor:** arquivos, o que muda, critério de aceite, os comandos de verificação e as
  entradas de `AGENT_LEARNINGS.md` que valem para a tarefa (subagent não lê esse arquivo
  sozinho). Faltando, o sonnet decide — e decidir é do Opus.
- **Coletor coleta, não conclui:** peça fatos com `arquivo:linha`; o Opus confere a linha antes de agir.
- **Achado do revisor é insumo, não ordem:** o Opus decide o que entra; o diff não cresce só para
  a revisão passar, e problema que já existia antes do diff não segura o commit. Três rodadas
  achando a mesma família de bug: o problema está no desenho.
- **Subagent em segundo plano que encerrou o turno terminou**, mesmo dizendo "aguardando": não
  volta sozinho. Use o resultado ou mande mensagem (`SendMessage`) se precisar de mais.
- **`fork` herda a conversa inteira:** cada requisição dele relê todo o contexto da sessão, no
  modelo da sessão. Use só quando o subagent precisa da conversa; senão, um agente com ficha.
- **Workflow:** nomeie o modelo de cada `agent()` (`haiku` na coleta) — sem ele o agente cai no
  `CLAUDE_CODE_SUBAGENT_MODEL` (sonnet), e não há garantia de que o hook de modelo alcance dentro
  do Workflow.
- **Medir:** `/padrao:medir` (haiku em zero = coleta não delegada).
