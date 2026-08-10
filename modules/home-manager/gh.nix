{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.gh;

  # gh resolves extensions as <data-dir>/gh/extensions/<name>/<name>;
  # home-manager builds that tree from packages whose pname matches the
  # extension name and whose executable sits at $out/bin/<pname>. Most of the
  # extensions used here are plain shell scripts that aren't in nixpkgs, so
  # they are packaged inline, pinned to the revisions that were installed
  # imperatively on Fedora.
  mkShellExtension =
    {
      owner,
      repo,
      rev,
      hash,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = repo;
      version = builtins.substring 0 7 rev;
      src = pkgs.fetchFromGitHub {
        inherit
          owner
          repo
          rev
          hash
          ;
      };
      dontBuild = true;
      installPhase = ''
        install -Dm755 ${repo} $out/bin/${repo}
      '';
    };

  # Relies on fzf at runtime, provided globally via fzf.nix
  gh-branch = mkShellExtension {
    owner = "mislav";
    repo = "gh-branch";
    rev = "7ed0aff7601dc4162e0cac8835ecd73409d8a009";
    hash = "sha256-yiRSXU/jLi067i+gBb3cEHTOuo+w3oEVsGL0NN6shl8=";
  };

  gh-download = mkShellExtension {
    owner = "yuler";
    repo = "gh-download";
    rev = "62b5926510d3a587c26e17ac6f7cab6110a2ff64";
    hash = "sha256-thaAkam5oC0+m7B9yGpOU8V8wyF0R3BOCGz8fko+QQk=";
  };

  gh-fire = mkShellExtension {
    owner = "maximousblk";
    repo = "gh-fire";
    rev = "72b9c9da912404414744697c05de99b199d68f02";
    hash = "sha256-ZKKBx+fCkq+zJK6y2LzCsjkiwKqJtc98rIrkrFuKRo4=";
  };

  gh-gitignore = mkShellExtension {
    owner = "ymmmtym";
    repo = "gh-gitignore";
    rev = "386096b4fac5d8850701a23d05de5ce171ab4b08";
    hash = "sha256-O5gOOa/nvI5ZeZKDyRrPUFr1F7/fHvmM+Hae1Az9mlg=";
  };

  gh-stashes = mkShellExtension {
    owner = "QWYNG";
    repo = "gh-stashes";
    rev = "c3662b4d9fd81b423eac4feef4500c5400573f51";
    hash = "sha256-vwiDW8Rd+Emvzk5Bhq2E8yeOr8BamGB1B+tKENSHAsc=";
  };

  gh-tidy = mkShellExtension {
    owner = "HaywardMorihara";
    repo = "gh-tidy";
    rev = "b07fcad4b014bdc36c9e2c377db0321f33a05b35";
    hash = "sha256-iOjDbuGNCYRYnTmovpaDYmCYz0djGY8gp80SqeS/FZk=";
  };
in
{
  options.local.gh = {
    enable = lib.mkEnableOption "GitHub CLI configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      package = unstable.gh;

      # git already reaches GitHub over SSH with libsecret as its credential
      # helper (see git.nix); letting gh also register itself as a git
      # credential helper would shadow that setup. gh's own auth lives in
      # hosts.yml, which stays imperative (`gh auth login`) since it holds
      # an oauth token that doesn't belong in the store.
      gitCredentialHelper.enable = false;

      settings = {
        # SSH so remotes written by gh (clone, fork, pr checkout) match how
        # git actually authenticates, rather than leaning on the https->ssh
        # insteadOf rewrites in git.nix.
        git_protocol = "ssh";

        aliases = {
          co = "pr checkout";
          b = "branch";
          bugs = "issue list --label=bug";
          d = "download";
          features = "issue list --label=enhancement";
          igrep = ''!gh issue list --label="$1" | grep "$2"'';
          pc = "pr create -w";
          pv = "pr view -w";
          screen = "screensaver";
          view = "repo view -w";
        };
      };

      extensions = [
        gh-branch
        gh-download
        gh-fire
        gh-gitignore
        gh-stashes
        gh-tidy
        unstable.gh-screensaver
      ];
    };
  };
}
