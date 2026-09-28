#!/usr/bin/env bash
# Installa i binari scelti in ~/.local/bin con backup del precedente.
# usage: install.sh <build-dir> [--no-bench]
set -euo pipefail

build="${1:?usage: install.sh <build-dir> [--no-bench]}"
build="$(cd "$build" && pwd)"
bindir="$HOME/.local/bin"

[[ -x "$build/bin/llama" ]] || { echo "non trovato: $build/bin/llama" >&2; exit 1; }

ts="$(date +%Y%m%d-%H%M%S)"

if [[ -f "$bindir/llama" && ! -f "$bindir/llama-vulkan-old" ]]; then
  cp -a "$bindir/llama" "$bindir/llama-vulkan-old"
  echo "backup: $bindir/llama -> $bindir/llama-vulkan-old"
fi
# backup versionato ad ogni run (rollback immediato)
cp -a "$bindir/llama" "$bindir/llama.bak-$ts" 2>/dev/null || true

install -m 755 "$build/bin/llama" "$bindir/llama"
echo "installato: $bindir/llama ($(du -h "$build/bin/llama" | cut -f1))"

if [[ "${2:-}" != "--no-bench" && -x "$build/bin/llama-bench" ]]; then
  install -m 755 "$build/bin/llama-bench" "$bindir/llama-bench"
  echo "installato: $bindir/llama-bench"
fi

echo
echo "rollback:  cp -a $bindir/llama-vulkan-old $bindir/llama"
