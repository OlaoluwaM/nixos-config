{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.neovim;
in
{
  options.local.neovim = {
    enable = lib.mkEnableOption "neovim configuration";
  };

  config = lib.mkIf cfg.enable {

    programs.neovim = {
      enable = true;
      package = unstable.neovim-unwrapped;

      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      # https://search.nixos.org/options?channel=26.05&query=neovim&source=home_manager&type=options#show=home-manager-option%253Aprograms.neovim.sideloadInitLua So we can manage our init.lua separately from the main configuration via our nvim-setup repo which uses AstroNvim imperatively
      sideloadInitLua = true;

      extraPackages = [
        unstable.tree-sitter
        unstable.neovim-node-client
      ];
    };
  };
}
