{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.local.gpg;
  minsToSecs = mins: mins * 60;
  hoursToSecs = hours: hours * 60 * 60;
in
{
  options.local.gpg = {
    enable = lib.mkEnableOption "GPG configuration";
  };

  config = lib.mkIf cfg.enable {
    services = {
      gpg-agent = {
        enable = true;
        enableExtraSocket = false;
        enableScDaemon = true;
        defaultCacheTtl = minsToSecs 10;
        maxCacheTtl = hoursToSecs 1; # 1 hour
        enableZshIntegration = true;
        pinentry.package = pkgs.pinentry-gnome3;
      };
    };

    programs = {

      gpg = {
        enable = true;

        settings = {
          auto-key-locate = "keyserver";
          keyserver = "hkps://keyserver.ubuntu.com";
          keyserver-options = "no-honor-keyserver-url";
          use-agent = true;

          personal-cipher-preferences = "AES256 AES192 AES CAST5";
          personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
          default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed";

          cert-digest-algo = "SHA512";
          s2k-digest-algo = "SHA512";
          s2k-cipher-algo = "AES256";

          charset = "utf-8";
          fixed-list-mode = true;
          no-comments = true;
          no-emit-version = true;
          keyid-format = "0xlong";
          list-options = "show-uid-validity";
          verify-options = "show-uid-validity";
          with-fingerprint = true;
        };
      };
    };
  };
}
