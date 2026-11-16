---
name: code-mode
description: Liga ou desliga o Code Mode (experimental) do Claude Code nesta máquina e mostra o estado — nele o Claude escreve JavaScript que faz várias chamadas de ferramenta num passo só. Grava a variável no ~/.claude/settings.json, o único settings em que ela vale.
argument-hint: "[ligar | desligar — vazio mostra o estado]"
disable-model-invocation: true
---

# Code Mode: ligar e desligar

No Code Mode o Claude escreve um JavaScript que faz várias chamadas de ferramenta num passo só
(buscar, filtrar, editar, testar) e devolve só o que precisa ler: menos requisições relendo o
contexto inteiro. É experimental, vem desligado e é **opcional**: o padrão não o liga.

Quem liga é `env.CLAUDE_CODE_EXPERIMENTAL_CODE_MODE: "1"`, e o Claude Code só aceita essa
variável do shell, do `~/.claude/settings.json` ou de um `--settings`; do settings do projeto e
do local ele a descarta (repositório clonado não liga o Code Mode por você). Por isso ela é a
única chave de `env` que o padrão deixa no global: o hook de abertura a deixa passar e o
`/padrao:aplicar` não a tira.

Pedido: **$ARGUMENTS** (vazio = só o estado). `<plugin>` = dois níveis acima desta skill:

    sh <plugin>/scripts/py.sh <plugin>/scripts/opcional.py code-mode [ligar|desligar]

O script grava só essa chave (desligar a tira, e o `env` que ficar vazio) e não toca em JSON
inválido. Se ele parar com erro, mostre o erro e pare: não conserte o global à mão sem OK.

Depois de rodar, diga o estado em uma linha e, se mudou, o que vale saber:

- **Vale a partir da próxima sessão, em todas as pastas desta máquina.** Não é por projeto, e a
  sessão aberta não muda.
- **Ao ligar:** a primeira sessão pede confirmação (**Yes, turn on Code Mode**) e mostra
  `Code Mode (experimental) is on` no topo. Se vier `isn't available`, o motivo está na mesma
  linha e no `/status`. Pede Claude Code v2.1.323+, build nativo e sessão interativa no terminal
  (não roda em `claude -p`, VS Code, Desktop nem nuvem), sem gateway; não abre com
  `DISABLE_TELEMETRY`, exportação OpenTelemetry ou agent teams ligados.
- **Retomada:** sessão aberta com Code Mode só volta (`--continue`, `--resume`) com ele ligado, e
  só no terminal. Antes de desligar, feche o que ainda quer retomar — ou religue para retomar.
- **Ao desligar:** se a próxima sessão ainda abrir com Code Mode, a variável também está no shell.
- **Os hooks do padrão seguem valendo:** cada chamada feita de dentro do código passa pelos
  hooks com o nome normal da ferramenta (modelo do subagent, trava de leitura e lembrete da
  documentação conferidos em sessão real). O código aparece no `Ctrl+O`, na linha **Code**.
- **Se compensa neste projeto, meça:** o `/padrao:medir` mostra requisições, cache lido e custo
  da sessão principal; compare sessões com e sem ele na mesma tarefa.
