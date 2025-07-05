{ self, lib, ... }: {
  description = "Pulls training data from walrus";
  serviceConfig = {
    Type = "oneshot"; # We run it and exit
    RemainAfterExit = true;
    Restart = "on-failure";
    RestartSec = "30s";
  };
  script = ''
    # Exit immediately if something fails
    set -euo pipefail

    ${
      lib.getExe self.packages.x86_64-linux.do-walrus-get
    } l2y--QBVILrMBnnzo0trCMkB0BF7zhKOIHyeBvUooO8 /tmp/iris.csv

    echo "Data is ready to be used"
    ${lib.getExe self.packages.x86_64-linux.do-notify} training "data pulled"
  '';

  wants = [ "network-online.target" ];
  after = [ "network-online.target" ];
  wantedBy = [ "multi-user.target" ];
}
