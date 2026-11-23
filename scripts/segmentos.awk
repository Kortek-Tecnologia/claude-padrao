# Segmentador dos hooks PreToolUse, num arquivo só para as travas não divergirem.
# Usado por so-le.awk (a trava de leitura) e por segmentos.sh (o `segmentar` do
# cobrar-docs.sh). POSIX awk: roda em gawk, mawk e busybox — sem gensub, sem
# classes [[:...:]] e sem intervalo {n}.
#
# segmentar(T, SEG): corta o comando T nos comandos simples que o shell rodaria e
# devolve quantos; SEG[1..n] traz um por posição. Acompanha o shell caractere a
# caractere, porque a trava decide em cima do corte — onde ele errava para menos,
# um comando passava sem ser visto (`"$(cat "a b"; touch f)"`, um `'` em
# comentário, `\2>&1;`):
# - aspas simples, aspas duplas e barra invertida: `;&|(){}` e quebra de linha só
#   partem FORA de aspas (senão o `(escopo)` de uma mensagem de commit vira
#   segmento);
# - `$(...)` abre um comando novo, também dentro de aspas duplas, e fecha no `)`
#   dele: o de dentro vira segmento e o de fora segue inteiro, com M_SUB no lugar
#   da substituição (quem lê sabe que ali entra texto que o shell ainda vai gerar);
# - comentário (`#` em começo de palavra, fora de aspas) some até o fim da linha;
# - redirecionamento inofensivo fora de aspas some (2>&1, >&2, >/dev/null). O alvo
#   precisa terminar a palavra: `>/dev/nullX` e `>&1x` gravam arquivo. Todo `>`
#   que sobra fora de aspas é escrita em arquivo; o de dentro de aspas é texto e
#   sai como M_GT, para ninguém o confundir com redirecionamento.
#
# O que o corte não acompanha fica anotado em SEG_RUIM (vazio = nada): crase,
# heredoc (`<<`), `$'...'`, `$"..."`, `${...}` com operador e barra invertida no
# fim da linha. A trava nega o comando inteiro; o cobrar-docs.sh ignora a anotação, e
# para ele o corte segue o de sempre (parte na crase e nas chaves).
#
# Com -v listar=1 o arquivo funciona sozinho: lê o comando da entrada e imprime
# um segmento por linha, sem as marcas.

BEGIN { M_GT = "\001"; M_SUB = "\002" }

function ruim(porque) { if (SEG_RUIM == "") SEG_RUIM = porque }

# inofensivo(RESTO): RESTO começa num `>` fora de aspas. Devolve quantos
# caracteres o redirecionamento inofensivo ocupa (sem o que termina a palavra),
# ou 0 se não é um.
function inofensivo(resto,    fim) {
  if (!match(resto, /^(>>?[ \t]*\/dev\/null|>&([0-9]+|-))([ \t\r\n;&|)]|$)/)) return 0
  fim = substr(resto, RLENGTH, 1)
  return index(" \t\r\n;&|)", fim) ? RLENGTH - 1 : RLENGTH
}

# ip = começo de palavra (onde `#` abre comentário); wi = tamanho de s quando a
# palavra atual começou (o número colado antes de um `>` é o descritor, e some
# com ele). ps/pq/pp/pw = a pilha das substituições abertas: o comando de fora,
# as aspas dele, os parênteses abertos dentro dela e o wi de fora.
function segmentar(t, seg,    i, c, d, k, q, s, n, ip, wi, np, ps, pq, pp, pw) {
  SEG_RUIM = ""
  gsub("[" M_GT M_SUB "]", "", t)
  q = ""; s = ""; n = 0; np = 0; ip = 1; wi = 0
  for (i = 1; i <= length(t); i++) {
    c = substr(t, i, 1)
    if (q == "\047") {
      if (c == "\047") q = ""
      s = s (c == ">" ? M_GT : c)
      continue
    }
    if (c == "\\") {
      d = substr(t, i + 1, 1)
      if (d == "\n") ruim("barra invertida no fim da linha (escreva numa linha so)")
      s = s c d; i++; ip = 0
      continue
    }
    if (c == "`") {
      ruim("crase (use $(...))")
      seg[++n] = s; s = ""; ip = 1; wi = 0
      continue
    }
    if (c == "$") {
      d = substr(t, i + 1, 1)
      if (d == "(") {
        np++; ps[np] = s M_SUB; pq[np] = q; pp[np] = 0; pw[np] = wi
        s = ""; q = ""; ip = 1; wi = 0; i++
        continue
      }
      # Fora `${NOME}`, o que segue não é acompanhado. `$"..."` é a aspa de tradução
      # do bash: ele entrega só o texto, sem o `$` (`sort $"-o" f` roda `sort -o f`),
      # e quem lê a palavra veria `$-o`.
      if (d == "{") {
        if (match(substr(t, i + 2), /^[A-Za-z_][A-Za-z0-9_]*[}]/)) {
          s = s substr(t, i, RLENGTH + 2); i += RLENGTH + 1; ip = 0
          continue
        }
        ruim("${...} com operador")
      } else if (d == "\047" && q == "") ruim("$'...'")
      else if (d == "\"" && q == "") ruim("$ colado em aspas duplas (o bash entrega so o texto: tire o $)")
    }
    if (q == "\"") {
      if (c == "\"") q = ""
      s = s (c == "\n" ? " " : c == ">" ? M_GT : c)
      continue
    }
    if (c == "\047" || c == "\"") { q = c; s = s c; ip = 0; continue }
    if (c == "#" && ip) {
      k = index(substr(t, i), "\n")
      i = k ? i + k - 2 : length(t)
      continue
    }
    if (c == ">") {
      k = inofensivo(substr(t, i))
      if (k) {
        if (substr(s, wi + 1) ~ /^[0-9]+$/) s = substr(s, 1, wi)
        i += k - 1
        continue
      }
      s = s c; ip = 1; wi = length(s)
      continue
    }
    if (c == "<") {
      # `<<<` (here-string) é só entrada; `<<` abre heredoc, e o corpo dele não é comando
      if (substr(t, i + 1, 2) == "<<") { s = s "<<"; i += 2 }
      else if (substr(t, i + 1, 1) == "<") ruim("heredoc (<<)")
      s = s c; ip = 1; wi = length(s)
      continue
    }
    if (c == "&" && substr(t, i + 1, 1) == ">" && substr(t, i + 2, 1) != "&") {
      k = inofensivo(substr(t, i + 1))
      if (k) { i += k; continue }
    }
    if (np && c == "(") pp[np]++
    if (np && c == ")") {
      if (pp[np] > 0) pp[np]--
      else {
        seg[++n] = s; s = ps[np]; q = pq[np]; wi = pw[np]; np--; ip = 0
        continue
      }
    }
    if (index(";&|(){}\n", c)) {
      seg[++n] = s; s = ""; wi = 0; ip = (c != "{" && c != "}")
      continue
    }
    s = s c
    if (c == " " || c == "\t") { ip = 1; wi = length(s) } else ip = 0
  }
  seg[++n] = s
  # substituição que não fechou: o shell recusaria; cada pedaço segue para quem lê
  while (np) seg[++n] = ps[np--]
  return n
}

listar { texto_listar = texto_listar $0 "\n" }
END {
  if (listar) {
    total_listar = segmentar(texto_listar, seg_listar)
    for (i_listar = 1; i_listar <= total_listar; i_listar++) {
      s_listar = seg_listar[i_listar]
      gsub(M_SUB, "", s_listar); gsub(M_GT, ">", s_listar)
      nl_listar = split(s_listar, linha_listar, "\n")
      if (nl_listar == 0) { print ""; continue }
      for (j_listar = 1; j_listar <= nl_listar; j_listar++) {
        sub(/^[ \t\r\f\v]+/, "", linha_listar[j_listar])
        print linha_listar[j_listar]
      }
    }
  }
}
