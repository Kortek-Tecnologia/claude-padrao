# shellcheck shell=sh
# Biblioteca dos hooks PreToolUse (sourced; não é hook). O corte em segmentos
# mora em segmentos.awk, no mesmo diretório — o mesmo arquivo que a trava de
# leitura (so-le.awk) usa, para as duas não divergirem.
#
# Quem dá source define antes SEGMENTOS_DIR, a pasta deste arquivo (um script
# lido por source não sabe onde está).
#
# segmentar CMD: imprime um segmento por linha, respeitando aspas. As regras do
# corte estão no cabeçalho de segmentos.awk.
segmentar() {
  printf '%s\n' "$1" | awk -v listar=1 -f "${SEGMENTOS_DIR:-.}/segmentos.awk"
}
