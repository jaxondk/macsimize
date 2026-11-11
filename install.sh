#!/usr/bin/env bash
# macsimize installer — fetch the tool and put `macsimize` on your PATH.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/jaxondk/macsimize/main/install.sh | bash
#
# What it does (and nothing else — it changes no power/network settings):
#   1. downloads macsimize into a stable directory
#   2. symlinks the `macsimize` entrypoint into a bin dir on your PATH
#   3. tells you to run `macsimize setup` when you're ready
#
# Everything is overridable by environment variable:
#   MACSIMIZE_PREFIX   where the tree lives   (default: ~/.local/share/macsimize)
#   MACSIMIZE_BIN      where the link goes    (default: ~/.local/bin)
#   MACSIMIZE_REF      git branch/tag to use  (default: main)
#   MACSIMIZE_REPO     source repo            (default: jaxondk/macsimize)
set -euo pipefail

REPO="${MACSIMIZE_REPO:-jaxondk/macsimize}"
REF="${MACSIMIZE_REF:-main}"
PREFIX="${MACSIMIZE_PREFIX:-$HOME/.local/share/macsimize}"
BIN_DIR="${MACSIMIZE_BIN:-$HOME/.local/bin}"

# --- pretty output -----------------------------------------------------------
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; X=$'\033[0m'
else B=''; G=''; Y=''; R=''; X=''; fi
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$G" "$X" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$X" "$*"; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$X" >&2; exit 1; }

say "${B}macsimize installer${X}"

# --- sanity checks -----------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "macsimize is macOS-only (this is $(uname -s))."
command -v curl >/dev/null 2>&1 || die "curl is required but not found."

# --- fetch -------------------------------------------------------------------
# Prefer git (gives you `git pull` updates + a clean PR workflow). Fall back to
# a tarball so a bare Mac without the Xcode CLT still works.
fetch_git() {
  if [ -d "$PREFIX/.git" ]; then
    say "Updating existing checkout in $PREFIX …"
    git -C "$PREFIX" fetch --quiet origin "$REF"
    git -C "$PREFIX" checkout --quiet "$REF"
    git -C "$PREFIX" reset --hard --quiet "origin/$REF" 2>/dev/null \
      || git -C "$PREFIX" reset --hard --quiet "$REF"
  else
    say "Cloning $REPO ($REF) into $PREFIX …"
    rm -rf "$PREFIX"
    mkdir -p "$(dirname "$PREFIX")"
    git clone --quiet --branch "$REF" "https://github.com/$REPO.git" "$PREFIX"
  fi
}

fetch_tarball() {
  say "Downloading $REPO ($REF) tarball into $PREFIX …"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" -o "$tmp/src.tar.gz" \
    || curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/tags/$REF" -o "$tmp/src.tar.gz" \
    || die "could not download $REPO@$REF."
  tar -xzf "$tmp/src.tar.gz" -C "$tmp"
  local extracted
  extracted="$(find "$tmp" -maxdepth 1 -type d -name 'macsimize-*' | head -1)"
  [ -n "$extracted" ] || die "unexpected tarball layout."
  rm -rf "$PREFIX"
  mkdir -p "$(dirname "$PREFIX")"
  mv "$extracted" "$PREFIX"
}

if command -v git >/dev/null 2>&1; then
  fetch_git
else
  fetch_tarball
fi

[ -f "$PREFIX/bin/macsimize" ] || die "install looks incomplete: $PREFIX/bin/macsimize missing."
chmod +x "$PREFIX/bin/macsimize" 2>/dev/null || true
ok "macsimize installed at $PREFIX"

# --- link onto PATH ----------------------------------------------------------
mkdir -p "$BIN_DIR"
ln -sf "$PREFIX/bin/macsimize" "$BIN_DIR/macsimize"
ok "linked $BIN_DIR/macsimize"

# --- PATH guidance -----------------------------------------------------------
on_path=false
case ":$PATH:" in *":$BIN_DIR:"*) on_path=true ;; esac

say ""
if $on_path; then
  ok "$BIN_DIR is on your PATH — you're ready."
  say "Run: ${B}macsimize setup${X}"
else
  warn "$BIN_DIR is not on your PATH yet."
  # Pick the rc file for the current login shell.
  case "${SHELL##*/}" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *)    rc="your shell profile" ;;
  esac
  line="export PATH=\"$BIN_DIR:\$PATH\""
  say "Add it with:"
  say "  ${B}echo '$line' >> $rc${X}"
  say "  ${B}source $rc${X}"
  say ""
  say "Then run: ${B}macsimize setup${X}"
  say "(or run it right now as: ${B}$BIN_DIR/macsimize setup${X})"
fi
