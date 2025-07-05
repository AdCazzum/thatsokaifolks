{ config, pkgs, ... }: {

  environment.systemPackages = [
    # Add here packages you want on your image
    pkgs.ncdu
    pkgs.git
  ];

  # Root has passwordless login
  users.users.root.initialPassword = "cicer1";

  networking.firewall.enable = false;

  # To run ubuntu packages (sui, walrus)
  programs.nix-ld.enable = true;

  services.sshd.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";

  system.stateVersion = "25.05";
}
