{ unstable, ... }:

{
  programs.vscode = {
    # This doesn't mean that we now have to completely declaratively setup our vscode.
    # It's all good
    enable = true;
    # vscode-fhs uses a user namespace that maps only this user's UID.
    # Unmapped Nix store owners appear as nobody, so OpenSSH rejects Home
    # Manager's Nix-store-backed ~/.ssh/config.
    package = unstable.vscode.override {
      # Hyprland is not reliably detected by Electron when choosing a Linux
      # credential store. Force VS Code to use GNOME Keyring via Secret Service.
      # We are not using the argvSettings option because it makes argv.json unwritable from vscode's
      # perspective which causes vscode to throw a warning. This approach avoids that situation
      commandLineArgs = "--password-store=gnome-libsecret";
    };
  };
}
