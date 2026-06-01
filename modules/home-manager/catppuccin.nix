# https://nix.catppuccin.com

{
  config,
  lib,
  ...
}:

let
  cfg = config.local.catppuccin;
in
{
  options.local.catppuccin = {
    # NOTE: Enabling or disabling this should only be done in theme.nix unless we aren't using theme.nix then we should re-evaluate this comment
    enable = lib.mkEnableOption "Opinionated Catppuccin Nix Configuration";
  };

  # There seems to be some inconsistency in the wiring of "catppuccin.enable" across the different options of catppuccin nix so we're creating our own to help normalize things
  config = lib.mkIf cfg.enable {
    catppuccin = {
      accent = "lavender";
      enable = true;
      flavor = "mocha";

      # Disabling cursors because we already have them configured in desktop.nix
      cursors.enable = false;

      # Some items would require too much work to port to nix for catppuccin-nix theming so just disable them
      # They are all already themed in my dotfiles anyway
      starship.enable = false;
      hyprland.enable = false;
      kitty.enable = false;
      neovim.enable = false;
    };
  };
}
