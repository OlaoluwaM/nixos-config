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
    "catppuccin.gitconfig".source = mkSourcePath "git/catppuccin.gitconfig";
    ".claude/CLAUDE.md".source = mkSourcePath "claude-code/CLAUDE.md";
    ".claude/settings.json".source = mkSourcePath "claude-code/settings.json";
    ".codex/config.toml".source = mkSourcePath "codex/config.toml";
    ".ghci".source = mkSourcePath "haskell/.ghci";
    "gitCommitConventionTemplate.txt".source = mkSourcePath "git/gitCommitConventionTemplate.txt";
    ".gitconfig".source = mkSourcePath "git/.gitconfig";
    ".githelpers".source = mkSourcePath "git/.githelpers";
    ".gitignore_global".source = mkSourcePath "git/.gitignore_global";
    ".noti.yaml".source = mkSourcePath "noti/noti.yaml";
    ".shell-env".source = mkSourcePath "shell/.shell-env";
    ".profile".source = mkSourcePath "shell/.profile";
    ".stack/config.yaml".source = mkSourcePath "stack/config.yaml";
    ".zshrc.nix.zsh".source = mkSourcePath "shell/.zshrc.nix.zsh";
  };

  configLinks = {
    "bat/config".source = mkSourcePath "bat/config";
    "bat/themes/Catppuccin Mocha.tmTheme".source = mkSourcePath "bat/Catppuccin Mocha.tmTheme";
    "fsh/catppuccin-mocha.ini".source = mkSourcePath "fsh/catppuccin-mocha.ini";
    "kitty/current-theme.conf".source = mkSourcePath "kitty/current-theme.conf";
    "kitty/kitty-dark.png".source = mkSourcePath "kitty/kitty-dark.png";
    "kitty/kitty.conf".source = mkSourcePath "kitty/kitty.conf";
    "lazydocker/config.yml".source = mkSourcePath "lazydocker/config.yml";
    "yazi/Catppuccin Mocha.tmTheme".source = mkSourcePath "yazi/Catppuccin Mocha.tmTheme";
    "yazi/theme.toml".source = mkSourcePath "yazi/theme.toml";
    "yazi/yazi.toml".source = mkSourcePath "yazi/yazi.toml";
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

    home.sessionVariables = {
      DOTS = cfg.dotsPath;
      SHELL_ENV = "${home}/.shell-env";
      SYS_BAK_DIR_NOT_UNDER_GIT = "${home}/sys-bak";
      SYS_BAK_DIR_UNDER_GIT = "${cfg.dotsPath}/system";
      WALLPAPERS_DIR = "${pictures}/Wallpapers";
      THEMES_DIR = "${data}/themes";
      CUSTOM_BIN_DIR = "${home}/.local/bin";
      CUSTOM_MAN_PATH = "${data}/man";
      FONT_DIR = "${data}/fonts";
      NAVI_PATH = "${cfg.dotsPath}/navi/cheats";
      NAVI_CONFIG_PATH = "${cfg.dotsPath}/navi/config.yaml";
      ATUIN_CONFIG_DIR = "${cfg.dotsPath}/atuin";
      _ZO_DATA_DIR = "${cfg.dotsPath}/zoxide";
      TEALDEER_CONFIG_DIR = "${cfg.dotsPath}/tldr";
      STARSHIP_CONFIG = "${cfg.dotsPath}/starship/starship.toml";
    };

    xdg.configFile = configLinks;
  };
}
