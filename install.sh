#!/usr/bin/env bash
# trio installer: installs dependencies and copies `trio` to ~/.local/bin
#   ./install.sh                 normal install
#   PREFIX=/usr/local sudo -E ./install.sh   install somewhere else
#   SKIP_DEPS=1 ./install.sh     skip the dependency step
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"

if [ -t 1 ]; then B=$'\033[1;34m'; G=$'\033[1;32m'; Y=$'\033[1;33m'; R=$'\033[1;31m'; N=$'\033[0m'; else B=; G=; Y=; R=; N=; fi
say()  { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '%s ok%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%swarn:%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%serror:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[ -f "$DIR/trio" ] || die "can't find the 'trio' file next to install.sh"
command -v python3 >/dev/null 2>&1 || die "python3 not found."
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
  || die "Python 3.10+ is required (found $(python3 --version 2>&1))."
command -v git >/dev/null 2>&1 || warn "git not found. CODE mode needs it."

is_arch() {
  [ -r /etc/os-release ] && grep -qiE '^(ID|ID_LIKE)=.*(arch|cachyos|manjaro|endeavouros)' /etc/os-release
}

install_deps() {
  if python3 -c 'import textual' >/dev/null 2>&1; then
    ok "textual already installed"
    return
  fi
  if is_arch; then
    say "Installing python-textual with pacman (needs sudo)"
    sudo pacman -S --needed python-textual
  else
    warn "Not an Arch-based system."
    say "Trying: python3 -m pip install --user textual"
    python3 -m pip install --user textual || die $'pip install failed. Try one of:\n  python3 -m pip install --user --break-system-packages textual\n  your distro package for textual (e.g. apt install python3-textual)'
  fi
}

if [ "${SKIP_DEPS:-0}" != "1" ]; then install_deps; fi

install -Dm755 "$DIR/trio" "$BIN_DIR/trio"
ok "installed $BIN_DIR/trio"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    warn "$BIN_DIR is not in your PATH. Add it:"
    printf '    bash/zsh:  echo '\''export PATH="%s:$PATH"'\'' >> ~/.bashrc   (or ~/.zshrc)\n' "$BIN_DIR"
    printf '    fish:      fish_add_path %s\n' "$BIN_DIR"
    ;;
esac

if python3 -c 'import textual' >/dev/null 2>&1; then
  ok "python can import textual"
else
  die "python cannot import textual. See the Troubleshooting section of the README."
fi

if command -v opencode >/dev/null 2>&1; then
  ok "opencode found: $(command -v opencode)"
else
  warn "opencode is not in your PATH. Install it from https://opencode.ai and log in to a provider."
fi

printf '\n%sDone.%s Run %strio%s inside any project folder.\n' "$G" "$N" "$B" "$N"
