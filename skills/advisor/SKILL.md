---
name: advisor
description: Liga ou desliga o Fable 5.2 como advisor neste projeto e mostra o estado — o modelo da sessão segue trabalhando e consulta o Fable nos pontos de decisão. Grava advisorModel no .claude/settings.local.json do projeto (pessoal, fora do git), e não no global, onde o /advisor grava.
argument-hint: "[ligar | desligar — vazio mostra o estado]"
disable-model-invocation: true
---

# Fable como advisor: ligar e desligar

Com o advisor ligado, o modelo da sessão segue fazendo o trabalho e consulta o Fable 5.2 nos
pontos de decisão: antes de fechar uma abordagem, quando um erro se repete, antes de dar a tarefa
por pronta. Quem decide a hora é o modelo, e não há teto de consultas. É experimental e
**opcional**: fica fora da política de modelos do padrão, que não o liga.

O `/advisor` do Claude Code grava `advisorModel` no global. A chave vale em qualquer settings,
então esta skill a grava no `.claude/settings.local.json` do projeto: pessoal e fora do git,
porque o Fable custa o dobro do Opus e, conforme o plano, consome créditos de uso de quem ligou.
O valor é o ID que o padrão fixa (`claude-fable-5-2`, do `env.ANTHROPIC_DEFAULT_FABLE_MODEL`), não
o alias `fable`, que acompanha a versão do Claude Code.

Pedido: **$ARGUMENTS** (vazio = só o estado). Rode do diretório do projeto (do home o script
recusa: lá o arquivo seria global). `<plugin>` = dois níveis acima desta skill:

    sh <plugin>/scripts/py.sh <plugin>/scripts/opcional.py advisor [ligar|desligar]

O script grava só essa chave e não toca em JSON inválido. Se ele parar com erro, mostre o erro
e pare. Repasse os avisos que ele imprimir (`advisorModel` no global, arquivo fora do
`.gitignore`).

Depois de rodar, diga o estado em uma linha e, se mudou, o que vale saber:

- **Vale a partir da próxima sessão deste projeto**, que abre com
  `Advisor Tool (experimental) is on`. Para uma sessão só, sem gravar nada:
  `claude --advisor fable` ao abrir.
- **Custo:** cada consulta relê a conversa inteira no preço do Fable, sem cache — em sessão
  longa é a parte cara. Medido numa sessão curta do Opus: uns US$ 0,50 por consulta; ligado e
  sem consulta, custo nenhum. Ligar ou desligar não invalida o cache do modelo da sessão. A
  consulta aparece no transcript como `Advising` (`Ctrl+O` mostra a orientação) e entra no
  `/usage`; o `/padrao:medir` mostra as consultas e o custo delas à parte.
- **Os subagents herdam o advisor:** executor, revisor e coletor também podem consultar o Fable.
  O hook de modelo não vê isso, porque o advisor não é o `model` da chamada. Onde isso pesar,
  desligue.
- **Créditos de uso:** em plano que cobra o Fable em créditos, o advisor só entra depois do
  consentimento — `/model fable` uma vez. Isso grava o Fable como modelo no global: o projeto
  reabre no Opus, e o hook de abertura avisa até o `/padrao:aplicar` limpar.
- **Não use o `/advisor` para ligar:** ele grava no global, e o hook de abertura acusa. O
  `/padrao:aplicar` leva o `advisorModel` de lá para o projeto.
- Pede Claude Code v2.1.321+ e a API da Anthropic (não roda em Bedrock, Agent Platform do Google
  Cloud nem Foundry).
