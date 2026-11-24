#!/bin/sh
# Roda Python isolado (-I) com o interpretador que existir: `python3` no
# Linux/macOS; no Windows o `python3` costuma ser o atalho da Microsoft Store,
# que não roda — daí o teste com -c antes de escolher.
#
# O atalho da Store (pasta WindowsApps) fica por último mesmo quando roda: ele
# abre o Python em ~250 ms, contra ~105 ms do instalado (medido em 2026-11-24),
# e o interpretador que sai daqui é o que o `aplicar` grava na status line.
#
#   sh <plugin>/scripts/py.sh script.py [args...]
serve() { "$1" -I -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; }
adiados=
for py in python3 python py; do
  onde=$(command -v "$py" 2>/dev/null) || continue
  case "$onde" in */WindowsApps/*) adiados="$adiados $py"; continue ;; esac
  serve "$py" && exec "$py" -I "$@"
done
for py in $adiados; do
  serve "$py" && exec "$py" -I "$@"
done
echo "Python 3.9+ nao encontrado (tentei python3, python, py)" >&2
exit 127
