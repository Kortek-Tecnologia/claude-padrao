---
name: medir
description: Mede se a política de modelos pegou — chamadas de subagent por tipo × modelo em que rodou, correções e recusas do hook, commits com a documentação conferida antes, tokens, turnos e custo estimado por modelo, contexto por requisição, dos transcripts locais deste projeto.
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
- Documentação antes do commit: commits da sessão principal (fora os lotes do `arrumar`) e
  quantos tiveram a `padrao:atualizar-docs` desde o commit anterior. Lembrete = o hook recusou a
  primeira tentativa. Commit sem a skill = o Claude repetiu depois do lembrete sem rodá-la (às
  vezes com razão: dois commits do mesmo diff), ou o hook não rodou naquela sessão.
- Verificação antes do commit: dos mesmos commits, quantos tiveram desde o commit anterior um
  teste, build, checagem de tipos ou lint rodado na sessão, uma chamada ao `padrao:revisor` (ou
  skill de revisão) ou um lote pelo `padrao:executor` — um commit pode contar em mais de uma — e
  quantos saíram sem nenhuma. Só mede: não há hook cobrando. O comando é reconhecido pelos nomes
  comuns (`pytest`, `npm test`, `cargo test`, `tsc`, `testar.sh`…); teste do projeto com outro
  nome não entra, e commit só de documentação também aparece como "sem nenhuma". Muitos sem
  nenhuma em diff de código = caso para pedir a verificação na ficha ou um gate.
- Tokens: o custo está em "entrada" e "saída"; "cache lido" sai bem mais barato. Opus com muita
  entrada e haiku perto de zero = leitura que devia ir ao coletor.
- `effort na chamada do subagent` (só aparece se houve): chamadas `Agent` que pediram um
  effort. O hook de modelo não olha esse campo; subagent em `xhigh` ou `max` é escalada que
  o padrão deixa para a sessão.
- Custo: estimativa a preço de lista, da data que o cabeçalho mostra; em assinatura não é cobrança, é o peso relativo de cada
  modelo (modelo sem preço na tabela fica fora da conta, listado à parte).
- Contexto: cada requisição relê o contexto inteiro, e requisição grande na sessão principal é o
  que mais custa. Haiku acima de 100K paga a requisição inteira cinco vezes mais (o sobrepreço).
- Advisor (só aparece se houve consulta, com o `/padrao:advisor` ligado): número de consultas e,
  nas linhas `advisor`, os tokens e o custo do modelo consultado. Cada consulta relê a conversa
  inteira sem cache; muita consulta em sessão longa é a parte cara.
- Os transcripts duram o `cleanupPeriodDays` do padrão (14 dias): `--dias` maior não acha mais.
  O número é desta máquina (os transcripts são locais).
