{ config, pkgs, ... }: {

  environment.systemPackages = [ pkgs.ncdu ];

  # Root has passwordless login
  users.users.root.initialPassword = "cicer1";

  networking.firewall.enable = false;

  services.sshd.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  system.stateVersion = "25.05";
}
