{
  config,
  lib,
  ...
}:

let
  cfg = config.local.direnv;
in
{
  options.local.direnv = {
    enable = lib.mkEnableOption "direnv configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;

      # Redundant while zsh is enabled (it defaults to true), but explicit
      # because this hook is what makes direnv fire on every prompt — and it
      # replaces the oh-my-zsh "direnv" plugin that used to provide it.
      enableZshIntegration = true;

      # Swaps direnv's built-in `use nix`/`use flake` for nix-direnv's cached
      # implementation: environments are cached in each project's .direnv/
      # (instant re-entry; only re-evaluates when flake.nix/flake.lock/.envrc
      # change) and registered as GC roots so `nix-collect-garbage` doesn't
      # delete dev shells. Inert for non-nix .envrc files, so it's safe while
      # still on Fedora.
      nix-direnv.enable = true;
    };
  };
}
