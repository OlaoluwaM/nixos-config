{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.hyprland;
  commands = cfg.commands;

  # The shell owns the countdown and the eventual shutdown. If it cannot
  # show that confirmation, report the failure without ending the session.
  powerRequestScript = pkgs.writeShellApplication {
    name = "hypr-shell-power-request";
    runtimeInputs = [
      commands.quickshellPackage
      pkgs.coreutils
      # Keep the compositor notification available when the shell is down.
      pkgs.hyprland
      pkgs.libnotify
    ];
    # Target the same packaged shell.qml that the shell service starts.
    runtimeEnv.SILERE_SHELL_QML = "${commands.silereShellPackage}/share/silere-shell/shell.qml";
    text = builtins.readFile ../scripts/hypr-shell-power-request.sh;
  };

  powerRequest = action: {
    # The shell's countdown is the confirmation for these commands.
    confirm = false;
    customProgram = lib.escapeShellArgs [
      (lib.getExe powerRequestScript)
      action
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    programs.vicinae.settings.providers.power.entrypoints = {
      reboot.preferences = powerRequest "reboot";
      "power-off".preferences = powerRequest "poweroff";
      logout.preferences = powerRequest "logout";
    };
  };
}
