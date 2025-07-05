let
  akiross =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXbm0gzsVHUiuA6fiLv2hPA4KDzJj421pdj+SfNF++d";
in { "rootpass.age".publicKeys = [ akiross ]; }
