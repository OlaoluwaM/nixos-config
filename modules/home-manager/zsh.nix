{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.zsh;
in
{
  options.local.zsh = {
    enable = lib.mkEnableOption "Opinionated Zsh configuration";

    histFilePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "\${config.home.homeDirectory}/.zsh_history";
      description = ''
        Path to zsh history file.
      '';
    };

    zshrcConfigPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "\${config.home.homeDirectory}/.zshrc";
      description = ''
        Path to an extra Zsh config file to source after Home Manager
        and oh-my-zsh initialization.
      '';
    };

    nvmDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/nvm";
      description = "NVM directory used by the oh-my-zsh nvm plugin.";
    };

    extraOhMyZshPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Oh My Zsh plugins to load.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      # Home Manager sources zsh-autosuggestions directly; no need to also load it as an oh-my-zsh plugin.
      autosuggestion.enable = true;

      sessionVariables =
        {
          NVM_DIR = cfg.nvmDir;
        }
        // lib.optionalAttrs (cfg.histFilePath != null) {
          HISTFILE = cfg.histFilePath;
        };

      oh-my-zsh = {
        enable = true;
        plugins = [
        "git"
        "command-not-found"
        "git-escape-magic"
        "safe-paste"
        "gh"
        "zoxide"
        "nvm"
        "direnv"
      ] ++ cfg.extraOhMyZshPlugins;

        extraConfig = ''
          zstyle :omz:plugins:nvm autoload yes
          zstyle :omz:plugins:nvm silent-autoload yes
        '';
      };

      plugins = [
        {
          name = "you-should-use";
          src = pkgs.zsh-you-should-use.src;
        }

        {
          name = "fast-syntax-highlighting";
          src = pkgs.zsh-fast-syntax-highlighting.src;
        }
      ];

      initContent = lib.mkIf (cfg.zshrcConfigPath != null) (
        # This way, the zshrc file in our dotfiles for nixos will be sourced before OMZ is loaded
        lib.mkOrder 790 ''
          if [[ -f "${cfg.zshrcConfigPath}" ]]; then
            source "${cfg.zshrcConfigPath}"
          fi
        ''
      );
    };
  };
}
