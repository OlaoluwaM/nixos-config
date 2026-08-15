{ lib, ... }:

{
  imports = [
    ./modules/applications.nix
    ./modules/desktop.nix
    ./modules/extensions.nix
    ./modules/keybindings.nix
    ./modules/shell.nix
  ];

  options.local.gnome = {
    enable = lib.mkEnableOption "Gnome configuration";
  };
}
