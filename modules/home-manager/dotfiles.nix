{
  config,
  lib,
  ...
}:

let
  cfg = config.local.dotfiles;
  home = config.home.homeDirectory;
  data = config.xdg.dataHome;
  pictures = config.xdg.userDirs.pictures;

  mkSourcePath =
    relativeFilepathFromDotsSubPath:
    config.lib.file.mkOutOfStoreSymlink "${cfg.dotsPath}/${relativeFilepathFromDotsSubPath}";

  homeLinks = {
    ".claude/CLAUDE.md".source = mkSourcePath "claude-code/CLAUDE.md";
    # Temporarily managed by home.activation.linkClaudeSettings below.
    # ".claude/settings.json".source = mkSourcePath "claude-code/settings.json";
    ".ghci".source = mkSourcePath "haskell/.ghci";
    ".noti.yaml".source = mkSourcePath "noti/noti.yaml";
    ".stack/config.yaml".source = mkSourcePath "stack/config.yaml";
  };

  configLinks = {
    "kitty/current-theme.conf".source = mkSourcePath "kitty/current-theme.conf";
    "kitty/kitty-dark.png".source = mkSourcePath "kitty/kitty-dark.png";
    "kitty/kitty.conf".source = mkSourcePath "kitty/kitty.conf";
    "lazydocker/config.yml".source = mkSourcePath "lazydocker/config.yml";
    "yt-dlp/config".source = mkSourcePath "yt-dlp/config";
  };

in
{
  options.local.dotfiles = {
    enable = lib.mkEnableOption "links to the host-scoped dotfiles checkout";

    dotsPath = lib.mkOption {
      type = lib.types.str;
      example = "\${config.home.homeDirectory}/../dotfiles/<hostname>/nixos";
      description = ''
        Path to user dotfiles directory
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = homeLinks;

    # Temporary workaround for https://github.com/anthropics/claude-code/issues/78162.
    # Claude's settings writer reportedly resolves only one symlink hop before
    # creating its temporary file. Home Manager's intermediate store link makes
    # that write fail with EROFS even though the final dotfile is writable.
    # Link directly after Home Manager removes the old managed link. Once fixed
    # upstream, remove this activation step and restore the home.file entry above.
    home.activation.linkClaudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      claudeSettingsTarget=${lib.escapeShellArg "${home}/.claude/settings.json"}
      if [[ -e "$claudeSettingsTarget" && ! -L "$claudeSettingsTarget" ]]; then
        echo "Refusing to replace non-symlink $claudeSettingsTarget" >&2
        exit 1
      fi
      run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg "${home}/.claude"}
      run ln -sfnT $VERBOSE_ARG ${lib.escapeShellArg "${cfg.dotsPath}/claude-code/settings.json"} "$claudeSettingsTarget"
    '';

    home.sessionVariables = {
      DOTS = cfg.dotsPath;
      SYS_BAK_DIR_NOT_UNDER_GIT = "${home}/sys-bak";
      SYS_BAK_DIR_UNDER_GIT = "${cfg.dotsPath}/system";
      WALLPAPERS_DIR = "${pictures}/wallpapers";
      THEMES_DIR = "${data}/themes";
      CUSTOM_BIN_DIR = "${home}/.local/bin";
      CUSTOM_MAN_PATH = "${data}/man";
      FONT_DIR = "${data}/fonts";
      NAVI_PATH = "${cfg.dotsPath}/navi/cheats";
      NAVI_CONFIG_PATH = "${cfg.dotsPath}/navi/config.yaml";
      # zoxide's default XDG location, made explicit. The database is mutable
      # runtime state, so it belongs outside the dotfiles repo; it's captured
      # by backups instead (see deja-dup.nix).
      _ZO_DATA_DIR = "${data}/zoxide";
      TEALDEER_CONFIG_DIR = "${cfg.dotsPath}/tldr";
      STARSHIP_CONFIG = "${cfg.dotsPath}/starship/starship.toml";
    };

    xdg.configFile = configLinks;
  };
}
