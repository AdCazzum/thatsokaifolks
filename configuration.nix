{ config, ... }: {
  # Root has passwordless login
  users.users.root.initialPassword = "";
  system.stateVersion = "25.05";
}
