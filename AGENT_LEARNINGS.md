# AGENT_LEARNINGS

Erros que o agente já cometeu neste projeto e o jeito certo de fazer. Não carrega sozinho: o
índice do `.claude/CLAUDE.md` manda ler antes de tarefa que altera arquivos — curto se lê inteiro.

Registre quando um erro custou retrabalho: o usuário corrigiu, um comando ou teste falhou por
suposição errada, um hook recusou, algo foi refeito. Deslize que não mudou nada não entra.

- Uma entrada por padrão, no formato abaixo. "Faça assim" vale mais que "não faça".
- Antes de acrescentar, procure entrada parecida: atualize-a em vez de duplicar.
- Entrada que o código ou o `CLAUDE.md` já cobrem, que ficou falsa ou cujo motivo deixou de
  valer, sai: cautela velha continua sendo seguida e trava trabalho que hoje é rotina.
- Teto de ~40 entradas: passou disso, junte as parecidas e corte as velhas sem recorrência.
- Nada pessoal nem sigiloso (token, senha, dado de pessoa).

<!-- Formato:
### <assunto curto> (AAAA-MM-DD)
- Erro: o que aconteceu, em uma linha.
- Evitar: o padrão que levou a ele, com o escopo (em que situação vale); sem escopo, vira proibição geral.
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
- Fazer: ler arquivo fundo, `cat arquivo | jq`; o `medir` já abre a pasta com o prefixo `\\?\` (2.13.1), o `inventariar` não. Teste de caminho longo: rode-o sem a correção para ver reprovar — o primeiro passou à toa, porque o `cygpath -m` de um HOME acima de 260 já devolve `//?/C:/...`; o HOME tem de ficar abaixo do limite e só a pasta final acima.

### Política de modelos mudada só por artigo (2026-11-10)
- Erro: troquei a regra de delegação e o lema com base num post ("o Opus edita por padrão") e tive de voltar atrás em ~10 arquivos quando o histórico das sessões mostrou o contrário.
- Evitar: mudar regra de modelo, delegação ou custo apoiado só em documentação ou artigo.
- Fazer: antes de mexer, medir no histórico local (`/padrao:medir` mostra custo e contexto por requisição) e, se a dúvida for de qualidade, rodar o mesmo lote nos dois modelos com o teste de aceite escrito antes. Texto novo de regra no bloco do `CLAUDE.md`: sondar em sessão real (`claude -p` no sandbox) com um caso de cada lado da regra — "pequena" sem critério foi lida de um jeito que só a sondagem mostrou.

### Comportamento novo só como texto no bloco (2026-11-23)
- Erro: pus a regra "pendência vira pergunta com opções" no bloco do `CLAUDE.md` e sondei três redações: em 6 de 6 sessões o Claude não abriu o `AskUserQuestion`. No hook, a primeira cobrança mandava também "fazer o reversível", e o Claude rodou script e aplicou sugestão sem pedido.
- Evitar: esperar que texto no bloco mude o que o modelo faz num momento fixo (fim de turno, antes do commit), ou pôr duas ordens na mesma cobrança de hook.
- Fazer: o que tem hora certa vai em hook que lembra uma vez e falha aberto; a cobrança pede uma ação só; sondar em sessão interativa (pseudo-terminal: no `claude -p` não há `AskUserQuestion`) um caso que deve disparar e um que não deve.

### Marcador de bloco casado sem âncora (2026-11-10)
- Erro: o hook de abertura achava o carimbo pela primeira linha que continha `padrao:inicio`; prosa do projeto citando o marcador dava aviso falso em toda sessão, e o teste não pegava.
- Evitar: casar por substring um marcador em arquivo que o usuário edita (`CLAUDE.md`, docs).
- Fazer: ancorar no começo da linha (`^<!-- padrao:inicio`) e pôr no teste um caso com o marcador citado em prosa antes do bloco.

### Segmentador da trava reusado para reconhecer comando (2026-11-10)
- Erro: o `cobrar-docs.sh` achava o `git commit` com o `segmentar` do `segmentos.sh`, que parte na crase; um `cat <<'EOF'` cujo texto citava `git commit` entre crases foi recusado como commit, e só o teste de ponta a ponta mostrou.
- Evitar: tratar o corte da trava como parser de shell em hook que precisa acertar (ele corta a mais de propósito: na trava, errar para o lado de negar é seguro).
- Fazer: tirar o corpo dos heredocs antes do corte (`sem_heredoc` no script) e pôr no `testar.sh` um caso com o comando citado em texto; hook novo passa por sessão real no sandbox antes de fechar.

### Argumento que começa por barra no Git Bash (2026-11-16)
- Erro: rodei `claude -p "/advisor"` pelo Git Bash; o MSYS trocou o argumento por `C:/Program Files/Git/advisor`, o comando virou prompt comum e a sondagem (paga) teve de ser repetida. Repeti logo depois, com `/exit` passado a um script Node que digitava na sessão.
- Evitar: passar a programa nativo do Windows (`claude`, `node`, `python`), pelo Git Bash, argumento que começa por `/` e não é caminho (slash command, opção no estilo `/x`).
- Fazer: `MSYS_NO_PATHCONV=1` no comando (ou rodar pelo PowerShell) e conferir a saída antes de concluir.

### Saída de comando pago passada por filtro (2026-11-10)
- Erro: rodei o `claude plugin eval` com a saída num `| sed …` de expressão errada; o `sed` morreu, a saída sumiu e a rodada (paga) teve de ser repetida.
- Evitar: encadear filtro novo direto na saída de comando que custa dinheiro ou demora (sessão aninhada, eval, suíte).
- Fazer: gravar a saída num arquivo do scratchpad (`> saida.log 2>&1`) e filtrar depois, do arquivo.

### Validador lido só pela última linha (2026-11-17)
- Erro: em quatro rodadas li só o fim do `claude plugin validate .` ("passed with warnings") e não vi o aviso de que o `subagentStatusLine` está obsoleto; só apareceu quando o usuário perguntou por pendências.
- Evitar: dar um validador ou linter por conferido pela linha de resultado, sem ler quais são os avisos.
- Fazer: ler os avisos (`claude plugin validate . 2>&1 | grep -n '❯\|⚠'`) e dizer quais são; a cada versão nova do Claude Code, a saída inteira.

### Opção que grava ou executa casada pelo nome inteiro (2026-11-17)
- Erro: a trava de leitura barrava `--output`, `--in-place`, `--profile` e `-O` pelo nome exato; o GNU e o git aceitam a forma abreviada (`sort --outp`, `sed --in-pl`, `git grep --op=./prog`, `git grep -nO./prog`), e um agente que só lê conseguia gravar e executar programa.
- Evitar: regra de bloqueio que casa a opção longa inteira, ou a curta só no começo do grupo, em comando que usa getopt.
- Fazer: casar o menor prefixo que já não é ambíguo e a letra em qualquer posição do grupo de opções curtas; cada regra nova entra no `testar.sh` com a forma abreviada e com a colada, e rode o comando de verdade num sandbox para ver se grava.

### Trava decidida sobre o texto do comando, não sobre o que o shell roda (2026-11-23)
- Erro: a trava de leitura casava opção no texto cru e cortava sem acompanhar o shell; `sort "-o" f`, `$(echo touch f)`, `echo "$(cat "a b"; touch f)"`, um `'` em comentário e `cat a \2>&1; touch f` passavam e gravavam. Na revisão só as aspas apareceram; o resto veio ao desenhar o conserto.
- Evitar: regra de bloqueio sobre o texto escrito, ou corte que simplifica o shell (tirar trecho do texto antes de cortar, tratar `$(` dentro de aspas como texto).
- Fazer: decidir sobre as palavras como o shell as entrega e negar o comando inteiro na forma que o corte não acompanha; para cada regra, tentar no sandbox as formas com aspas, barra, variável, `$(…)`, comentário e várias linhas, rodando de verdade o que a trava deixar passar (`estado` antes e depois).

### Edição por script inline no Bash (2026-11-17)
- Erro: três vezes um `python - <<'EOF'` com texto em português e aspas não aplicou a edição: erro de sintaxe do shell, stdin fora de UTF-8 e um caractere ESC cru gravado no arquivo.
- Evitar: editar vários arquivos por script passado em heredoc ou em `-c` pelo Git Bash.
- Fazer: gravar o script num arquivo do scratchpad e rodar `python -I arquivo.py`; substituição exata que confere a contagem (`s.count(antigo) == 1`) antes de gravar, para falhar sem deixar arquivo pela metade.

### Script de shell conferido só com `sh -n` (2026-11-17)
- Erro: reescrevi o hook de abertura, conferi a sintaxe com `sh -n` e pus a suíte para rodar em segundo plano; um laço `while read -r _ || [ -n "$_" ]` não terminava (`$_` nunca fica vazia) e a rodada ficou travada até o usuário perguntar.
- Evitar: mandar para segundo plano, sem limite de tempo, um script de shell que só passou pela checagem de sintaxe.
- Fazer: rodar o script uma vez à mão com `timeout 60` e comparar a saída com a da versão anterior antes da rodada longa; todo comando de segundo plano que chama código novo leva `timeout`.

### Tempo de hook medido uma vez só (2026-11-17)
- Erro: medi a trava de leitura em 4 a 6 s por comando com a máquina carregada e, horas depois, a mesma versão levava 1,3 a 1,6 s; quatro sessões pagas em paralelo estouraram os 10 s do hook em 5 de 12.
- Evitar: concluir sobre o tempo de um hook por uma medição, ou comparar medições de horas diferentes (no Windows abrir um processo varia de 100 a 800 ms).
- Fazer: medir a versão antiga e a nova lado a lado, na mesma hora, cinco vezes cada, com `sh -c true` como régua do custo de abrir processo; sessão paga em paralelo, no máximo duas enquanto o hook não tiver folga.
