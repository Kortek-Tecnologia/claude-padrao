# shellcheck shell=sh
# Biblioteca dos hooks PreToolUse (sourced; não é hook). Usada por so-le.sh —
# a trava decide por SEGMENTO de comando, e o segmentador fica num arquivo só
# para outras travas poderem reaproveitá-lo sem divergir.
#
# segmentar CMD: imprime um segmento por linha, respeitando aspas. `;&|(){}` e
# quebra de linha só partem FORA de aspas (senão o `(escopo)` de uma mensagem
# de commit vira segmento); `$(` e crase partem também dentro de aspas duplas,
# porque lá ainda executam. Antes, some com os redirecionamentos inofensivos
# (2>&1, >/dev/null), que partiriam o segmento no `&`. Todo `>` que sobra é
# escrita em arquivo.
segmentar() {
  printf '%s\n' "$1" |
    sed -E -e 's/[0-9]*>&[0-9-]//g' -e 's/(&|[0-9]*)>>?[[:space:]]*\/dev\/null//g' |
    awk '
      { t = t $0 "\n" }
      END {
        q = ""; s = ""
        for (i = 1; i <= length(t); i++) {
          c = substr(t, i, 1)
          if (q == "\047") { if (c == "\047") q = ""; s = s c; continue }
          if (c == "\\") { s = s c substr(t, i + 1, 1); i++; continue }
          if (c == "`" || (c == "$" && substr(t, i + 1, 1) == "(")) {
            print s; s = ""; if (c == "$") i++; continue
          }
          if (q == "\"") { if (c == "\"") q = ""; s = s (c == "\n" ? " " : c); continue }
          if (c == "\047" || c == "\"") { q = c; s = s c; continue }
          if (index(";&|(){}\n", c)) { print s; s = ""; continue }
          s = s c
        }
        print s
      }' |
    sed -E 's/^[[:space:]]+//'
}
