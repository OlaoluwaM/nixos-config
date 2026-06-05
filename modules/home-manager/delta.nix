{
  config,
  lib,
  unstable,
  ...
}:

let
  cfg = config.local.delta;
in
{
  options.local.delta = {
    enable = lib.mkEnableOption "delta configuration";
  };

  config = lib.mkIf cfg.enable {
    catppuccin.delta.enable = true;

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      package = unstable.delta;
      options = {
        dark = true;
        hyperlinks = true;
        hyperlinks-file-link-format = "vscode://file/{path}:{line}";
        line-numbers = true;
        navigate = true;
        side-by-side = true;
      };
    };
  };
}
