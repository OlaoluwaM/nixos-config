{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.zsh;
  dotfiles = config.local.dotfiles;
  home = config.home.homeDirectory;

  mkDotfileSource =
    relativeFilepathFromDotsSubPath:
    config.lib.file.mkOutOfStoreSymlink "${dotfiles.dotsPath}/${relativeFilepathFromDotsSubPath}";
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
      default = [ ];
      description = "Oh My Zsh plugins to load.";
    };
  };

  config = lib.mkIf cfg.enable {
    catppuccin.zsh-syntax-highlighting.enable = true;

    home = {
      file = {
        ".shell-env".source = mkDotfileSource "shell/.shell-env";
        ".zshrc.nix.zsh".source = mkDotfileSource "shell/.zshrc.nix.zsh";
      };

      sessionVariables = {
        SHELL_ENV = "${home}/.shell-env";
      };

      # zsh writes HISTFILE on exit but never creates its parent directory, so
      # ensure it exists — otherwise history silently fails to persist when
      # HISTFILE points outside the home root (e.g. under XDG data).
      activation = lib.mkIf (cfg.histFilePath != null) {
        ensureZshHistDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg (builtins.dirOf cfg.histFilePath)}
        '';
      };
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      # Home Manager sources zsh-autosuggestions directly; no need to also load it as an oh-my-zsh plugin.
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      sessionVariables = {
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
          # No "direnv" plugin here: the direnv module's enableZshIntegration
          # provides the shell hook, and both together would run it twice.
        ]
        ++ cfg.extraOhMyZshPlugins;

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
      ];

      initContent = lib.mkIf (cfg.zshrcConfigPath != null) (
        # This way, the zshrc file in our dotfiles for nixos will be sourced after OMZ is loaded. There are some scripts that depend on being loaded after OMZ
        lib.mkOrder 900 ''
          if [[ -f "${cfg.zshrcConfigPath}" ]]; then
            source "${cfg.zshrcConfigPath}"
          fi
        ''
      );
    };
  };
}
