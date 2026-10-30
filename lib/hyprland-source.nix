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
# nixpkgs names both packages the way the flake does, so switching is a
# one-word change to the line below:
#   inputs.hyprland.packages.${system}  upstream's flake, tag-pinned (today)
#   unstable                             nixos-unstable, which picks up patch releases
#   pkgs                                 stable nixpkgs
{
  inputs,
  unstable,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
inputs.hyprland.packages.${system}
