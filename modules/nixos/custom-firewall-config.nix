{ config, pkgs, ... }:

{
  # Unblock ports for localsend. Localsend uses port 53317 for both TCP and UDP. NixOS firewall blocks unsolicited incoming connections by default, so we need to allow this port for localsend to work properly.
  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };
}
