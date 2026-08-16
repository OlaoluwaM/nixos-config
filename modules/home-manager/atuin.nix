{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.atuin;
in
{
  options.local.atuin = {
    enable = lib.mkEnableOption "atuin configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.atuin.enable = true;

    programs.atuin = {
      enable = true;
      package = unstable.atuin;

      enableZshIntegration = true;

      # Atuin eagerly writes its default config; take ownership on first HM activation.
      forceOverwriteSettings = true;

      settings = {
        history_filter = [
          "(sk-[a-zA-Z0-9]{1,48})|(sk-ant-api03-[a-zA-Z0-9-]{1,24})"
        ];
        search_mode = "daemon-fuzzy";

        sync.records = true;
        ai.enabled = true;
        auto_sync = false;
        sync_frequency = "1h";

        daemon = {
          enabled = true;
          autostart = true;
        };
      };

      daemon.enable = true;
    };
  };
}
