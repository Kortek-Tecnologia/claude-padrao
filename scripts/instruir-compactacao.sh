#!/bin/sh
# PreCompact: o que o resumo da compactação tem de preservar. O Claude Code usa o stdout
# deste hook (saída 0, sem bloquear) como instrução do resumo. Vale na sessão principal e
# nos subagents (a entrada do subagent traz `agent_type`), na compactação automática e no
# `/compact`.
#
# - Sessão principal: a mesma lista da seção `Compact instructions` do bloco do CLAUDE.md,
#   que é texto e depende de o modelo que resume segui-la; aqui ela chega na hora.
# - Subagent: o que ele já coletou ou fez. O coletor e o leitor compactam aos 100K
#   (`autoCompactWindow` no frontmatter: acima disso o Haiku paga a requisição inteira no
#   preço alto), e um resumo que solta os fatos já lidos devolve a coleta pela metade.
# - `/compact <foco>` (o usuário passou instrução: `custom_instructions` não é null) → cala:
#   o foco pedido vale sozinho.
# - Nunca bloqueia nem falha: sem entrada legível, imprime a lista da sessão do mesmo jeito.
#   No hooks.json leva `onFailure: "continue"`.
# Sem jq e sem abrir processo: a entrada é lida com o `read` do shell.
nl='
'
entrada=
while IFS= read -r linha || [ -n "$linha" ]; do entrada="$entrada$linha$nl"; done
case "$entrada" in
  *'"custom_instructions":null'* | *'"custom_instructions": null'*) ;;
  *'"custom_instructions"'*) exit 0 ;;
esac
case "$entrada" in
  *'"agent_type"'*)
    printf '%s\n' 'Ao resumir, preserve por extenso e sem parafrasear: a tarefa recebida, com o formato de resposta pedido; cada fato ja coletado, com arquivo:linha e o trecho exato; o que ja foi alterado e a saida real das verificacoes; e a lista do que ainda falta ler ou fazer.'
    ;;
  *)
    printf '%s\n' 'Ao resumir, preserve por extenso: o plano aprovado e o que falta dele; as decisoes tomadas, com as que o usuario pode querer desfazer; os arquivos alterados; a saida real da ultima verificacao (comando e resultado); e as autorizacoes que o usuario deu (commit, push, deploy), com o escopo de cada uma.'
    ;;
esac
exit 0
