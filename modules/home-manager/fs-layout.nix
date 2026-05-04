{ config, lib, ... }:

let
  data = config.xdg.dataHome;

  dirs = [
    "${config.xdg.userDirs.desktop}/dev"
    "${config.xdg.userDirs.download}/isos"
    "${data}/icons"
    "${data}/themes"
    "${data}/fonts"
    "${config.xdg.userDirs.videos}/Screencasts"
    "${config.xdg.userDirs.pictures}/Screenshots"
  ];

in
{
  # "writeBoundary" represents the point where file system changes are allowed during the lifecycle of activating a generation
  home.activation.createPersonalDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG ${lib.escapeShellArgs dirs}
  '';

  home.activation.createLegacyXdgLinks = lib.hm.dag.entryAfter [ "createPersonalDirs" ] ''
    [[ -e "$HOME/.icons" || -L "$HOME/.icons" ]] || run ln -sf $VERBOSE_ARG "$XDG_DATA_HOME/icons" "$HOME/.icons"
    [[ -e "$HOME/.themes" || -L "$HOME/.themes" ]] || run ln -sf $VERBOSE_ARG "$XDG_DATA_HOME/themes" "$HOME/.themes"
    [[ -e "$HOME/.fonts" || -L "$HOME/.fonts" ]] || run ln -sf $VERBOSE_ARG "$XDG_DATA_HOME/fonts" "$HOME/.fonts"
  '';
}
