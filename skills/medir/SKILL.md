---
name: medir
description: Mede se a política de modelos pegou — chamadas de subagent por tipo × modelo em que rodou, correções e recusas do hook, tokens, turnos e custo estimado por modelo, contexto por requisição, dos transcripts locais deste projeto.
disable-model-invocation: true
---

# Medir o uso de modelos

Rode do diretório do projeto (`<plugin>` = dois níveis acima desta skill; o `py.sh` acha
`python3`/`python`/`py`, no Windows e no Linux):

    sh <plugin>/scripts/py.sh <diretório desta skill>/medir-modelos.py --dias 14

Leitura:
- `haiku` em zero com sessões longas = coleta feita pelo Opus ou pelo Sonnet.
- Sessão sem delegação não é falha: tarefa que se resolve em poucas chamadas não deve delegar.
  Preocupa a sessão longa, de muitos turnos de Opus, sem nenhuma.
- O modelo de cada chamada é o que rodou pela regra atual do hook: papel fixo (`Plan`, `Explore`,
  agentes `padrao:*`) já no modelo travado; `sonnet (env)` = `general-purpose` sem `model`, no
  `CLAUDE_CODE_SUBAGENT_MODEL`; `(frontmatter)` = agente de outro plugin, com o modelo no arquivo;
  `(sem model)` = outro agente, no modelo da própria definição. O modelo real aparece em "turnos
  dos subagents".
- Correções = chamadas de papel fixo que o Opus fez com outro `model` (ou `Explore`/`Plan` sem
  `model`) e o hook trocou. Muitas = a delegação está pedindo o modelo errado.
- Tokens: o custo está em "entrada" e "saída"; "cache lido" sai bem mais barato. Opus com muita
  entrada e haiku perto de zero = leitura que devia ir ao coletor.
- Custo: estimativa a preço de lista; em assinatura não é cobrança, é o peso relativo de cada
  modelo (modelo sem preço na tabela fica fora da conta, listado à parte).
- Contexto: cada requisição relê o contexto inteiro, e requisição grande na sessão principal é o
  que mais custa. Haiku acima de 100K paga a requisição inteira cinco vezes mais (o sobrepreço).
- Os transcripts duram o `cleanupPeriodDays` do padrão (14 dias): `--dias` maior não acha mais.
  O número é desta máquina (os transcripts são locais).
