{ self, lib, pkgs, ... }: {
  description = "Trains ML model on the downloaded data";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  script = ''
    set -euo pipefail

    echo "Starting model training..."
    ${
      pkgs.python3.withPackages (ps: with ps; [ scikit-learn polars ])
    }/bin/python3 ${../src/train_iris_model.py} /tmp/iris.csv --output-dir /tmp

    echo "Model training completed successfully"

    ${lib.getExe self.packages.x86_64-linux.do-notify} training finished
  '';

  after = [ "walrus-puller.service" ];
  wants = [ "walrus-puller.service" ];
  wantedBy = [ "multi-user.target" ];
}
