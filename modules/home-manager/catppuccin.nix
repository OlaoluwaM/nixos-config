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
      # Keep Catppuccin's upstream global default off. Our local theme preset can
      # still be active, but each Catppuccin port should opt in explicitly so it
      # does not inadvertently overwrite existing custom theming.
      enable = false;
      flavor = "mocha";

      # kvantum is owned by desktop.nix via local.desktop.catppuccinQt.enable,
      # which sets catppuccin.kvantum.enable per profile. Defining it here too
      # would conflict (bool options take one value) the moment that knob is
      # turned off — the two modules would assert true vs false.
      obs.enable = true;

      # Some items would require too much work to port to nix for catppuccin-nix theming so just disable them
      # They are all already themed in my dotfiles anyway
      starship.enable = false;
      hyprland.enable = false;
      kitty.enable = false;
      nvim.enable = false;
      gtk.icon.enable = false; # Catppuccin defaults to the "Papirus" icon theme. We do not want that to clash with the Colloid icon theme we already set
      cursors.enable = false; # Disabling cursors because we already have them configured in desktop.nix
    };
  };
}
