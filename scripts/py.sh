#!/bin/sh
# Roda Python isolado (-I) com o interpretador que existir: `python3` no
# Linux/macOS; no Windows o `python3` costuma ser o atalho da Microsoft Store,
# que não roda — daí o teste com -c antes de escolher.
#
#   sh <plugin>/scripts/py.sh script.py [args...]
for py in python3 python py; do
  command -v "$py" >/dev/null 2>&1 && "$py" -I -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1 &&
    exec "$py" -I "$@"
done
echo "Python 3.9+ nao encontrado (tentei python3, python, py)" >&2
exit 127
