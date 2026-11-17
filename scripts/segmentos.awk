# Segmentador dos hooks PreToolUse, num arquivo só para as travas não divergirem.
# Usado por so-le.awk (a trava de leitura) e por segmentos.sh (o `segmentar` do
# cobrar-docs.sh). POSIX awk: roda em gawk, mawk e busybox — sem gensub, sem
# classes [[:...:]] e sem intervalo {n}.
#
# segmentar(T, SEG): corta o comando T em segmentos e devolve quantos; SEG[1..n]
# traz um por posição, sem o espaço da frente. `;&|(){}` e quebra de linha só
# partem FORA de aspas (senão o `(escopo)` de uma mensagem de commit vira
# segmento); `$(` e crase partem também dentro de aspas duplas, porque lá ainda
# executam. Quebra de linha dentro de aspas simples também parte: sobra um
# pedaço que não é comando de leitura, e a trava nega (errar para esse lado é
# seguro). Antes do corte somem os redirecionamentos inofensivos (2>&1,
# >/dev/null), que partiriam o segmento no `&`. O /dev/null precisa terminar a
# palavra: `>/dev/nullX` grava arquivo (no Git Bash, de verdade). Todo `>` que
# sobra é escrita em arquivo.
#
# Com -v listar=1 o arquivo funciona sozinho: lê o comando da entrada e imprime
# um segmento por linha.

function sem_redirecionamento_inofensivo(t,    r, m) {
  gsub(/[0-9]*>&[0-9-]/, "", t)
  r = ""
  while (match(t, /(&|[0-9]*)>>?[ \t]*\/dev\/null([ \t\r\n;&|)]|$)/)) {
    m = substr(t, RSTART, RLENGTH)
    # o que termina a palavra (espaço, `;`, `)`…) fica; no fim do texto não há
    r = r substr(t, 1, RSTART - 1) (m ~ /null$/ ? "" : substr(m, length(m)))
    t = substr(t, RSTART + RLENGTH)
  }
  return r t
}

function segmentar(t, seg,    i, c, q, s, bruto, nb, k, n, linha, nl, j) {
  t = sem_redirecionamento_inofensivo(t)
  q = ""; s = ""; nb = 0
  for (i = 1; i <= length(t); i++) {
    c = substr(t, i, 1)
    if (q == "\047") { if (c == "\047") q = ""; s = s c; continue }
    if (c == "\\") { s = s c substr(t, i + 1, 1); i++; continue }
    if (c == "`" || (c == "$" && substr(t, i + 1, 1) == "(")) {
      bruto[++nb] = s; s = ""; if (c == "$") i++; continue
    }
    if (q == "\"") { if (c == "\"") q = ""; s = s (c == "\n" ? " " : c); continue }
    if (c == "\047" || c == "\"") { q = c; s = s c; continue }
    if (index(";&|(){}\n", c)) { bruto[++nb] = s; s = ""; continue }
    s = s c
  }
  bruto[++nb] = s
  n = 0
  for (k = 1; k <= nb; k++) {
    nl = split(bruto[k], linha, "\n")
    if (nl == 0) { seg[++n] = ""; continue }
    for (j = 1; j <= nl; j++) { sub(/^[ \t\r\f\v]+/, "", linha[j]); seg[++n] = linha[j] }
  }
  return n
}

listar { texto_listar = texto_listar $0 "\n" }
END {
  if (listar) {
    total_listar = segmentar(texto_listar, seg_listar)
    for (i_listar = 1; i_listar <= total_listar; i_listar++) print seg_listar[i_listar]
  }
}
