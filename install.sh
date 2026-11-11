#!/usr/bin/env bash
# macsimize installer — fetch a released version and put `macsimize` on PATH.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/jaxondk/macsimize/main/install.sh | bash
#
# What it does (and nothing else — it changes no power/network settings):
#   1. downloads a pinned macsimize release tarball (default: latest release)
#   2. unpacks it into a stable directory
#   3. symlinks the `macsimize` entrypoint into a bin dir on your PATH
#   4. tells you to run `macsimize setup` when you're ready
#
# Overridable by environment variable:
#   MACSIMIZE_VERSION  release tag to install  (default: latest release, e.g. v0.1.0)
#   MACSIMIZE_PREFIX   where the tree lives     (default: ~/.local/share/macsimize)
#   MACSIMIZE_BIN      where the link goes       (default: ~/.local/bin)
#   MACSIMIZE_REPO     source repo               (default: jaxondk/macsimize)
set -euo pipefail

REPO="${MACSIMIZE_REPO:-jaxondk/macsimize}"
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
command -v tar  >/dev/null 2>&1 || die "tar is required but not found."

# --- resolve version ---------------------------------------------------------
# Default to the latest published release so the one-liner always pulls a real,
# versioned tarball (not a moving branch). Override with MACSIMIZE_VERSION.
VERSION="${MACSIMIZE_VERSION:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$VERSION" ] || die "no release found for $REPO. Set MACSIMIZE_VERSION=<tag> to pin one."

# --- download + unpack -------------------------------------------------------
say "Installing $REPO $VERSION into $PREFIX …"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz" -o "$tmp/src.tar.gz" \
  || die "could not download $REPO $VERSION."
tar -xzf "$tmp/src.tar.gz" -C "$tmp"
src="$(find "$tmp" -maxdepth 1 -type d -name 'macsimize-*' | head -1)"
[ -n "$src" ] || die "unexpected tarball layout."
[ -f "$src/bin/macsimize" ] || die "tarball is missing bin/macsimize."

rm -rf "$PREFIX"
mkdir -p "$(dirname "$PREFIX")"
mv "$src" "$PREFIX"
chmod +x "$PREFIX/bin/macsimize" 2>/dev/null || true
ok "macsimize $VERSION installed at $PREFIX"

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
