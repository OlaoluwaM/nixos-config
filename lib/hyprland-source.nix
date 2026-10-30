# Where the Hyprland profile's compositor and portal come from: the one place
# to switch it. modules/nixos/hyprland.nix installs `hyprland` and
# `xdg-desktop-portal-hyprland` from the returned set, and compositor.nix takes
# hyprctl from the same `hyprland`, so the NixOS and standalone Home Manager
# entrypoints always agree.
#
# A plain function instead of a module option because both entrypoints need
# the answer, and standalone Home Manager can't read a NixOS option. Both
# callers already receive `inputs` and `unstable` through specialArgs.
#
# Both nixpkgs sets name the packages the same way, so switching between them
# is a one-word change to the line below:
#   unstable  nixos-unstable, which moves with each update, minor releases included (today)
#   pkgs      stable nixpkgs
# Upstream's tag-pinned flake uses the same names too: re-add the `hyprland`
# input and return inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.
{
  inputs,
  unstable,
  pkgs,
}:
unstable
