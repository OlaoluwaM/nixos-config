#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
host="${1:-$(hostname)}"

host_dir="$repo_root/hosts/$host"
hardware_config="$host_dir/hardware-configuration.nix"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Make sure this machine has a corresponding host configuration.
if [[ ! -d "$host_dir" ]]; then
  echo "error: no NixOS configuration found for host '$host'" >&2
  echo "expected: $host_dir" >&2
  exit 1
fi

echo "==> Checking hardware configuration for '$host'..."

sudo nixos-generate-config --show-hardware-config > "$tmp"

# Compare the generated configuration against the version in the repo.
if [[ ! -f "$hardware_config" ]] || ! cmp -s "$tmp" "$hardware_config"; then
  echo
  echo "Hardware configuration differs from the current system."

  if [[ -f "$hardware_config" ]]; then
    echo
    echo "Diff:"
    echo

    diff --color=auto -u \
      "$hardware_config" \
      "$tmp" || true
  else
    echo
    echo "No existing hardware-configuration.nix was found."
  fi

  echo
  read -r -p "Replace hardware-configuration.nix with the generated version? [y/N] " response

  case "$response" in
    [yY]|[yY][eE][sS])
      cp "$tmp" "$hardware_config"
      echo
      echo "==> Updated:"
      echo "    $hardware_config"
      ;;
    *)
      echo
      echo "Aborting rebuild."
      echo "The checked-in hardware configuration does not match the current system."
      exit 1
      ;;
  esac
else
  echo "==> Hardware configuration is up to date."
fi

echo
echo "==> Rebuilding '$host'..."

sudo nixos-rebuild switch --flake "$repo_root#$host"
