{ config, pkgs, ... }: {

  age.secrets = { rootpass.file = ../secrets/rootpass.age; };

  environment.systemPackages = [
    # Add here packages you want on your image
    pkgs.ncdu
    pkgs.git
  ];

  # Don't do this...
  users.users.root.initialPassword = "cicer1";
  # ...do something like this.
  # users.users.root.hashedPasswordFile = config.age.secrets.rootpass.path;
  # Or just use ssh keys and don't set a password.
  # users.users.root.openssh.authorizedKeys.keys = [ ... ];

  networking.firewall.enable = false;

  # To run ubuntu packages (sui, walrus)
  programs.nix-ld.enable = true;

  services.sshd.enable = true;
  # Unsafe, here for demo purposes
  services.openssh.settings.PermitRootLogin = "yes";

  system.stateVersion = "25.05";
}
