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

    histFilePath = lib.mkOption {
      type = lib.types.str;
      example = "\${config.home.homeDirectory}/.zsh_history";
      description = ''
        Path to zsh history file.
      '';
    };

    zshrcConfigPath = lib.mkOption {
      type = lib.types.str;
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
      # Home Manager sources zsh-autosuggestions directly; no need to also load it as an oh-my-zsh plugin.
      autosuggestion.enable = true;

      sessionVariables = {
        NVM_DIR = cfg.nvmDir;
        HISTFILE = cfg.histFilePath;
      };

      oh-my-zsh = {
        enable = true;
        plugins = cfg.ohMyZshPlugins;

        extraConfig = ''
          zstyle :omz:plugins:nvm autoload yes
          zstyle :omz:plugins:nvm silent-autoload yes
        '';
      };

      initContent = lib.mkIf (cfg.zshrcConfigPath != null) (
        lib.mkAfter ''
          if [[ -f "${cfg.zshrcConfigPath}" ]]; then
            source "${cfg.zshrcConfigPath}"
          fi
        ''
      );
    };
  };
}
