{
  config,
  lib,
  ...
}:

let
  cfg = config.local.fsLayout;
  home = config.home.homeDirectory;
  data = config.xdg.dataHome;
  pictures = config.xdg.userDirs.pictures;

  dirs = [
    "${config.xdg.userDirs.desktop}/${cfg.devDirname}"
    "${config.xdg.userDirs.download}/isos"
    "${data}/icons"
    "${data}/themes"
    "${data}/fonts"
    "${config.xdg.userDirs.videos}/Screencasts"
    "${pictures}/Screenshots"
    "${pictures}/Wallpapers"
    "${home}/sys-bak"
  ];

in
{
  options.local.fsLayout = {
    devDirname = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      example = "dev";
      description = ''
        Name of the development directory created under the XDG desktop directory.
      '';
    };
  };

  config = {
    # "writeBoundary" represents the point where file system changes are allowed during the lifecycle of activating a generation
    home.activation.createPersonalDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $VERBOSE_ARG ${lib.escapeShellArgs dirs}
    '';

    home.activation.createLegacyXdgLinks = lib.hm.dag.entryAfter [ "createPersonalDirs" ] ''
      [[ -e "$HOME/.icons" || -L "$HOME/.icons" ]] || run ln -sf $VERBOSE_ARG "${data}/icons" "$HOME/.icons"
      [[ -e "$HOME/.themes" || -L "$HOME/.themes" ]] || run ln -sf $VERBOSE_ARG "${data}/themes" "$HOME/.themes"
      [[ -e "$HOME/.fonts" || -L "$HOME/.fonts" ]] || run ln -sf $VERBOSE_ARG "${data}/fonts" "$HOME/.fonts"
    '';
  };
}
