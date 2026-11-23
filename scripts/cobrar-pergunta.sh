#!/bin/sh
# Pendência em aberto no fim do turno. A regra "ao encerrar, pendência vira pergunta com
# opções, a recomendada primeiro" foi sondada só como texto no bloco do CLAUDE.md, em três
# redações: em 6 de 6 sessões o Claude encerrou com "não fiz commit" ou "quer que eu…?" em
# frase solta. O que tem hora certa para acontecer vai em hook; este cobra a pergunta na
# hora em que o turno fecha (evento Stop, só da sessão principal).
#
# - A resposta final (`last_assistant_message`, sem os trechos de código) traz oferta ou
#   pendência em aberto → recusa UMA vez (`decision: block`), mandando perguntar no
#   AskUserQuestion. Só perguntar: na 1ª versão o texto mandava também "fazer o que é
#   reversível", e na sondagem o Claude aplicou sugestão de revisão e rodou script sem pedido.
# - "Não executei", "não rodei", "não testei" não contam: são relato do que foi feito, e
#   dispararam numa resposta que só lia um arquivo.
# - `stop_hook_active` (o turno já continua por causa de um hook Stop) → passa: é lembrete,
#   não trava, e a segunda parada do mesmo turno sempre segue.
# - A detecção é por frases, em português e inglês: erra para os dois lados. Por isso o
#   texto da recusa deixa o Claude encerrar de novo quando não há pendência de verdade.
#
# Falha ABERTA, como o lembrete da documentação: sem jq, entrada inválida ou jq com erro,
# o hook se cala e o turno fecha. No hooks.json leva `onFailure: "continue"`.
# Roda em todo fim de turno: lê a entrada com o `read` do shell e só abre o jq quando
# alguma das palavras aparece (no Windows cada processo pesa).
nl='
'
entrada=
while IFS= read -r linha || [ -n "$linha" ]; do entrada="$entrada$linha$nl"; done
case "$entrada" in *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;; esac
# Pré-filtro só com trechos ASCII (o texto pode vir com acento cru ou em \uXXXX).
case "$entrada" in
  *[Qq]uer\ que* | *[Ss]e\ quiser* | *[Ss]e\ preferir* | *[Ss]e\ voc* | *[Pp]osso\ * | *[Dd]evo\ * | \
  *[Mm]e\ diga* | *[Mm]e\ avise* | *[Mm]e\ fal* | *pedir* | *[Ss]ugiro* | *[Rr]ecomendo* | *fiz* | \
  *commitei* | *[Pp]end* | *passo* | *[Ff]alta* | *[Ss]em\ commit* | *[Ww]ant\ me* | *[Ww]ould\ you* | *[Ss]hall\ I* | \
  *[Ss]hould\ I* | *[Ll]et\ me\ know* | *[Ii]f\ you* | *I\ can\ also* | *[Ss]uggest* | \
  *[Rr]ecommend* | *[Nn]ext\ step* | *committed* | *[Dd]id* | *[Hh]aven*) ;;
  *) exit 0 ;;
esac
command -v jq >/dev/null 2>&1 || exit 0

# Oferta ("quer que eu…?", "posso…", "se quiser") ou pendência ("não fiz commit", "falta
# decidir", "próximos passos", "sugiro"). Frase nova entra aqui e no testar.sh, com um caso
# que casa e um que não casa.
re='(quer que (eu|a gente)|se (voc[êe] )?(quiser|preferir)|posso (fazer|rodar|aplicar|commitar|seguir|continuar|criar|ajustar|corrigir|abrir|subir|incluir|adicionar|remover|atualizar|tamb[ée]m)|devo (fazer|rodar|aplicar|commitar|seguir|continuar)|me (diga|avise|fale|fala) (se|qual|o que|como|quando)|[ée] s[óo] (pedir|falar|dizer|avisar)|sugiro|recomendo que|n[ãa]o (fiz|commitei)|nem fiz (o )?commit|sem commit|fic(ou|aram|a|am) pendentes?|pend[êe]ncias?:|pr[óo]ximos? passos?|o que falta|faltam? (fazer|rodar|commitar|decidir|definir)|want me to|would you like|shall i |should i |let me know (if|whether|which|how)|if you(.d| would)? like|if you want|i can also|i suggest|i recommend|next steps?|not committed|did(n.t| not) (commit|run|test)|haven.t (committed|run|tested))'
# O Claude Code mostra a recusa como retorno de hook: o texto diz que é rotina, para o
# modelo não a registrar como erro no AGENT_LEARNINGS (como no lembrete da documentação).
# O medir conta a cobrança por "a resposta termina com oferta ou item em aberto": mudou a
# frase, mude o PENDENCIA do medir-modelos.py.
motivo='padrao: lembrete de rotina, nao e erro nem vai para o AGENT_LEARNINGS: a resposta termina com oferta ou item em aberto em frase solta (como "nao fiz commit", "quer que eu...?", "sugiro..."). Nao faca mais nada por conta propria: chame agora o AskUserQuestion, uma pergunta por item em aberto, com a opcao que voce recomenda em primeiro lugar e "(Recomendado)" no rotulo dela, e "deixar como esta" entre as opcoes; depois aja conforme a resposta. Sem a ferramenta (claude -p), liste as opcoes com a recomendada marcada. So encerre sem perguntar se a frase era citacao ou explicacao, e nao um item em aberto: o lembrete sai uma vez por turno.'
printf '%s' "$entrada" | jq -c --arg re "$re" --arg r "$motivo" '
  if .stop_hook_active == true then empty
  else
    ((.last_assistant_message // "") | tostring
      | gsub("```[\\s\\S]*?```"; " ") | gsub("`[^`\\n]*`"; " ")) as $t
    | if ($t | test($re; "i")) then {decision: "block", reason: $r} else empty end
  end' 2>/dev/null
exit 0
