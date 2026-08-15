#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"
host="${1:-$(hostname)}"

if [[ "$host" == */* ]]; then
  echo "error: host name must not contain '/'" >&2
  exit 1
fi

host_dir="$repo_root/hosts/$host"
hardware_config="$host_dir/hardware-configuration.nix"

# Make sure this machine has a corresponding host configuration before asking
# for sudo or generating any output.
if [[ ! -d "$host_dir" ]]; then
  echo "error: no NixOS configuration found for host '$host'" >&2
  echo "expected: $host_dir" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
generated_config="$tmp_dir/hardware-configuration.nix"
parsed_generated_config="$tmp_dir/generated.nix.parse"
parsed_current_config="$tmp_dir/current.nix.parse"

echo "==> Generating hardware configuration for '$host'..."
sudo nixos-generate-config --show-hardware-config | tee "$generated_config" > /dev/null

if ! nix-instantiate --parse "$generated_config" > "$parsed_generated_config"; then
  echo "error: nixos-generate-config produced invalid Nix" >&2
  exit 1
fi

if [[ -f "$hardware_config" ]]; then
  if cmp -s "$generated_config" "$hardware_config"; then
    echo "==> Hardware configuration is already up to date."
    exit 0
  fi

  if ! nix-instantiate --parse "$hardware_config" > "$parsed_current_config"; then
    echo "error: current hardware configuration is invalid Nix: $hardware_config" >&2
    exit 1
  fi

  if cmp -s "$parsed_generated_config" "$parsed_current_config"; then
    echo "==> Hardware configuration is semantically up to date."
    echo "    Only formatting or comments differ; no replacement is needed."
    exit 0
  fi
fi

echo
echo "Hardware configuration differs from the current system."

if [[ -f "$hardware_config" ]]; then
  echo
  echo "Diff:"
  echo
  diff --color=auto -u "$hardware_config" "$generated_config" || true
else
  echo
  echo "No existing hardware-configuration.nix was found."
fi

echo
read -r -p "Replace hardware-configuration.nix with the generated version? [y/N] " response

case "$response" in
  [yY] | [yY][eE][sS])
    install -m 0644 "$generated_config" "$hardware_config"
    echo
    echo "==> Updated:"
    echo "    $hardware_config"
    ;;
  *)
    echo
    echo "Hardware configuration was not changed."
    exit 1
    ;;
esac
