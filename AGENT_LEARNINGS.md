# AGENT_LEARNINGS

Erros que o agente já cometeu neste projeto e o jeito certo de fazer. Não carrega sozinho: o
índice do `CLAUDE.md` manda ler antes de tarefa que altera arquivos — curto se lê inteiro.

Registre quando um erro custou retrabalho: o usuário corrigiu, um comando ou teste falhou por
suposição errada, um hook recusou, algo foi refeito. Deslize que não mudou nada não entra.

- Uma entrada por padrão, no formato abaixo. "Faça assim" vale mais que "não faça".
- Antes de acrescentar, procure entrada parecida: atualize-a em vez de duplicar.
- Entrada que o código ou o `CLAUDE.md` já cobrem, ou que ficou falsa, sai.
- Teto de ~40 entradas: passou disso, junte as parecidas e corte as velhas sem recorrência.
- Nada pessoal nem sigiloso (token, senha, dado de pessoa).

<!-- Formato:
### <assunto curto> (AAAA-MM-DD)
- Erro: o que aconteceu, em uma linha.
- Evitar: o padrão que levou a ele.
- Fazer: a abordagem certa, concreta (comando, arquivo, passo).
-->

## Entradas

### Renomear seção citada por script (2026-10-21)
- Erro: renomeei a seção de modelos do bloco do CLAUDE.md e a mensagem de recusa do hook de modelo continuou apontando para o nome antigo.
- Evitar: mudar título ou caminho de documento sem procurar quem o cita fora dos .md.
- Fazer: antes de renomear, `grep -rn '<nome antigo>' scripts skills agents hooks` e corrija junto.

### jq no Windows grava CRLF (2026-10-21)
- Erro: `jq ... > arquivo && mv` no Git Bash deixou hooks.json e settings.json com CRLF; o repositório exige LF.
- Evitar: reescrever arquivo do repositório com saída de programa Windows sem conferir o fim de linha.
- Fazer: depois de gerar, `sed -i 's/\r$//' <arquivo>`; temporários no scratchpad da sessão, não em /tmp.
