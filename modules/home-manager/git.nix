{
  config,
  hostConfig,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.local.git;
  dotfiles = config.local.dotfiles;
  home = config.home.homeDirectory;

  mkDotfileSource =
    relativeFilepathFromDotsSubPath:
    config.lib.file.mkOutOfStoreSymlink "${dotfiles.dotsPath}/${relativeFilepathFromDotsSubPath}";
in
{
  options.local.git = {
    enable = lib.mkEnableOption "git configuration";
  };

  config = lib.mkIf cfg.enable {
    # git-adjacent tooling is owned here rather than in home.packages;
    # programs.git has no extraPackages option, hence the manual entry.
    home.packages = [ pkgs.git-extras ];

    home.file = {
      ".githelpers".source = mkDotfileSource "git/.githelpers";
      ".gitignore_global".source = mkDotfileSource "git/.gitignore_global";
      "gitCommitConventionTemplate.txt".source = mkDotfileSource "git/gitCommitConventionTemplate.txt";
    };

    programs.git = {
      enable = true;
      package = unstable.git.override {
        withSsh = true;
        withLibsecret = true;
      };

      signing = {
        format = "openpgp";
        key = "C16B79DB8BEBD0AA";
        signByDefault = true;
        signer = "gpg2";
      };

      settings = {
        user = {
          email = "37044906+OlaoluwaM@users.noreply.github.com";
          name = hostConfig.userFullName;
        };

        core = {
          excludesfile = "${home}/.gitignore_global";
          editor = "nvim";
        };

        commit = {
          template = "${home}/gitCommitConventionTemplate.txt";
        };

        help = {
          autocorrect = 50;
        };

        color = {
          ui = true;
        };

        push = {
          default = "simple";
        };

        alias = {
          cp = "cherry-pick";
          d = "diff";
          d1 = "diff HEAD~1";
          d2 = "diff HEAD~2";
          d3 = "diff HEAD~3";
          dn = "diff --name-status";
          d1n = "diff HEAD~1 --name-status";
          d2n = "diff HEAD~2 --name-status";
          d3n = "diff HEAD~3 --name-status";
          st = "status";
          lg = "!git l -G $1 -- $2";
          c = "commit";
          ch = "checkout";
          deleteRemote = "push -d";
          setUpstreamTo = "branch --set-upstream-to";
          fix = "commit --amend";
          amend = "commit --amend --no-edit";
          tree = ''log --graph --full-history --all --color --pretty=tformat:"%x1b[31m%h%x09%x1b[32m%d%x1b[0m%x20%s%x20%x1b[33m(%an)%x1b[0m"'';
          renameBranch = "branch -m";
          unsetUpstream = "branch --unset-upstream";
          checkUpstream = "status -sb";
          p = "push";
          listBranches = "branch -l";
          deleteBranch = "branch -D";
          summary = "!which onefetch && onefetch";
          sw = "switch";
          rmr = "rm -r";
          f = "fetch";
          l = "!. ~/.githelpers && pretty_git_log";
          la = "!git l --all";
          lr = "!git l -30";
          lra = "!git lr --all";
          ap = "add -p";
          lo = "log --oneline --decorate";
        };

        credential = {
          helper = "libsecret";
        };

        init = {
          defaultBranch = "main";
        };

        diff = {
          colorMoved = "default";
        };

        merge = {
          tool = "code";
          conflictstyle = "diff3";
        };

        mergetool."code" = {
          cmd = "code --wait --merge $REMOTE $LOCAL $BASE $MERGED";
        };

        # Enforce SSH (https://stackoverflow.com/questions/11200237/how-do-i-get-git-to-default-to-ssh-and-not-https-for-new-repositories)

        # Tells git to use SSH by default when connecting to github
        url = {
          "ssh://git@github.com/" = {
            insteadOf = "https://github.com/";
          };
          "ssh://git@gitlab.com/" = {
            insteadOf = "https://gitlab.com/";
          };
          "ssh://git@bitbucket.org/" = {
            insteadOf = "https://bitbucket.org/";
          };
        };
      };

      lfs.enable = true;
    };
  };
}
