{ self, lib, ... }: {
  description = "Uploads trained model to walrus";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  script = ''
    set -euo pipefail

    echo "Uploading trained model to Walrus..."

    # Capture the JSON output from walrus upload
    upload_result=$(${
      lib.getExe self.packages.x86_64-linux.do-walrus-put
    } /tmp/iris_random_forest_model.pkl)

    echo "Model uploaded successfully"
    echo "Upload result: $upload_result"

    # Use the JSON output as the notification message
    ${lib.getExe self.packages.x86_64-linux.do-notify} training "$upload_result"
  '';

  after = [ "model-trainer.service" ];
  wants = [ "model-trainer.service" ];
  wantedBy = [ "multi-user.target" ];
}
