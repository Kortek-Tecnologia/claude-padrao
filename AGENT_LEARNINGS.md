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

### Caminho de base vazio em script (2026-11-03)
- Erro: `cygpath -u -l` falhou (o `-l` só vale com `-w`/`-m`), a variável saiu vazia e o sandbox de teste foi criado em `/sandbox` (C:\Program Files\Git\sandbox).
- Evitar: montar caminho de trabalho com a saída de um comando sem conferir.
- Fazer: `S="${B:?}/sandbox"` e conferir o prefixo (`case "$S" in */scratchpad/*)`) antes de criar ou apagar; caminho longo com `cygpath -m -l`.

### Caminho acima de 260 caracteres no Windows (2026-11-03)
- Erro: no sandbox (HOME falso no scratchpad), `inventariar.py`, `medir-modelos.py` e o `jq` não acharam `~/.claude/projects/<chave>/...`; o Bash achava.
- Evitar: concluir "não existe" pela saída de Python ou jq nativos em caminho fundo.
- Fazer: para testar `medir`/`inventariar`, copie os transcripts para um HOME curto e use `--projeto` curto; ler arquivo fundo, `cat arquivo | jq`.

### Política de modelos mudada só por artigo (2026-11-10)
- Erro: troquei a regra de delegação e o lema com base num post ("o Opus edita por padrão") e tive de voltar atrás em ~10 arquivos quando o histórico das sessões mostrou o contrário.
- Evitar: mudar regra de modelo, delegação ou custo apoiado só em documentação ou artigo.
- Fazer: antes de mexer, medir no histórico local (`/padrao:medir` mostra custo e contexto por requisição) e, se a dúvida for de qualidade, rodar o mesmo lote nos dois modelos com o teste de aceite escrito antes.

### Marcador de bloco casado sem âncora (2026-11-10)
- Erro: o hook de abertura achava o carimbo pela primeira linha que continha `padrao:inicio`; prosa do projeto citando o marcador dava aviso falso em toda sessão, e o teste não pegava.
- Evitar: casar por substring um marcador em arquivo que o usuário edita (`CLAUDE.md`, docs).
- Fazer: ancorar no começo da linha (`^<!-- padrao:inicio`) e pôr no teste um caso com o marcador citado em prosa antes do bloco.
