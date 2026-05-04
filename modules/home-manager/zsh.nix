{
  config,
  lib,
  ...
}:
let
  cfg = config.local.zsh;
in
{
  options.local.zsh = {
    enable = lib.mkEnableOption "opinionated Zsh configuration";

    dotsConfigPath = lib.mkOption {
      type = lib.types.str;
      example = "\${config.home.homeDirectory}/Desktop/dotfiles/<hostname>/nixos";
      description = ''
        Dotfiles config directory.
      '';
    };

    localConfigPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.dotsConfigPath}/shell/.zshrc.nix.zsh";
      example = "\${config.home.homeDirectory}/Desktop/dotfiles/<hostname>/nixos/.zshrc.nix.zsh";
      description = ''
        Runtime path to an extra Zsh config file to source after Home Manager
        and oh-my-zsh have initialized.
      '';
    };

    nvmDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/nvm";
      description = "NVM directory used by the oh-my-zsh nvm plugin.";
    };

    ohMyZshPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "git"
        "command-not-found"
        "git-escape-magic"
        "safe-paste"
        "fast-syntax-highlighting"
        "you-should-use"
        "gh"
        "zoxide"
        "nvm"
        "direnv"
      ];
      description = "Oh My Zsh plugins to load.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      # Home Manager sources zsh-autosuggestions directly; don't also load it via oh-my-zsh.
      autosuggestion.enable = true;

      sessionVariables = {
        NVM_DIR = cfg.nvmDir;
        HISTFILE = "${cfg.dotsConfigPath}/shell/.zsh_history";
      };

      oh-my-zsh = {
        enable = true;
        plugins = cfg.ohMyZshPlugins;

        extraConfig = ''
          zstyle :omz:plugins:nvm autoload yes
          zstyle :omz:plugins:nvm silent-autoload yes
        '';
      };

      initContent = lib.mkIf (cfg.localConfigPath != null) (
        lib.mkAfter ''
          if [[ -f "${cfg.localConfigPath}" ]]; then
            source "${cfg.localConfigPath}"
          fi
        ''
      );
    };
  };
}
