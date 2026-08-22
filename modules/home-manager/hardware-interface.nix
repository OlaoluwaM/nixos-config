# The purpose behind this module is to provide an interface through which home-manager modules can query and utilize hardware capabilities of the target system. This avoids coupling home-manager modules directly to specific hardware mechanisms or configurations.
{ lib, ... }:

{
  options.local.capabilities = {
    graphics.cuda = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether the target system provides CUDA support that Home Manager
        modules may use.
      '';
    };
    hardware.asusRog = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether the target system is an ASUS ROG device whose hardware controls
        Home Manager modules may use.
      '';
    };
  };
}
