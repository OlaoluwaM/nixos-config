#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"
host="${1:-$(hostname)}"

"$script_dir/regenerate-hardware-configuration.sh" "$host"

echo
echo "==> Rebuilding '$host'..."

sudo nixos-rebuild switch --flake "$repo_root#$host"
