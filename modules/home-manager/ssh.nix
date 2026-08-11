{
  config,
  lib,
  ...
}:

let
  cfg = config.local.ssh;
in
{
  options.local.ssh.enable = lib.mkEnableOption "SSH configuration";

  config = lib.mkIf cfg.enable {
    services.ssh-agent.enable = true;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings."*" = {
        AddKeysToAgent = "yes";
      };
    };
  };
}
