#!/usr/bin/env bash
# Removes the trio script. Does not touch system packages.
set -euo pipefail
BIN="${PREFIX:-$HOME/.local}/bin/trio"
if [ -f "$BIN" ]; then
  rm -f "$BIN"
  echo "removed $BIN"
else
  echo "nothing to remove at $BIN"
fi
echo "Dependencies were left alone. To remove textual on Arch: sudo pacman -Rns python-textual"
echo "A warm 'opencode serve' started by trio exits with it; if one is stuck: pkill -f 'opencode serve'"
