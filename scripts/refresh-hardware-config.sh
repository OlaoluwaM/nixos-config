#!/usr/bin/env bash
set -euo pipefail

host="${1:-$(hostname)}"

repo_root="$(git rev-parse --show-toplevel)"
target_dir="$repo_root/hosts/$host"
target="$target_dir/hardware-configuration.nix"

if [[ ! -d "$target_dir" ]]; then
  echo "error: host directory does not exist: $target_dir" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Generating hardware configuration for '$host'..."

sudo nixos-generate-config --show-hardware-config > "$tmp"

if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
  echo "Hardware configuration is already up to date."
  exit 0
fi

if [[ -f "$target" ]]; then
  echo
  echo "Changes:"
  diff --color=auto -u "$target" "$tmp" || true
  echo
fi

mv "$tmp" "$target"
trap - EXIT

echo "Updated:"
echo "  $target"
