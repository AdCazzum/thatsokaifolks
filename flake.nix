{
  description = "ThatsOkAI - Blockchain-based distributed ML platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This can be moved into a fetchzip
    sui-ubuntu-bin = {
      url =
        "https://github.com/MystenLabs/sui/releases/download/testnet-v1.51.2/sui-testnet-v1.51.2-ubuntu-x86_64.tgz";
      flake = false;
    };

    walrus-ubuntu-bin = {
      url =
        "https://github.com/MystenLabs/walrus/releases/download/testnet-v1.28.1/walrus-testnet-v1.28.1-ubuntu-x86_64.tgz";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators, sui-ubuntu-bin
    , walrus-ubuntu-bin }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Walrus endpoints, using testnet at the moment
        aggregator = "https://aggregator.walrus-testnet.walrus.space";
        publisher = "https://publisher.walrus-testnet.walrus.space";

        pkgs = nixpkgs.legacyPackages.${system};
      in {
        # Uploads a file to walrus for 5 epochs
        packages.do-walrus-put = pkgs.writeScriptBin "do-walrus-put" ''
          set -euo pipefail

          if [ $# -ne 1 ]; then
            echo "Usage: do-walrus-put <file>"
            echo "Uploads a file to Walrus storage for 5 epochs"
            exit 1
          fi

          if [ ! -f "$1" ]; then
            echo "Error: File '$1' does not exist"
            exit 1
          fi

          echo "Uploading file '$1' to Walrus..."
          ${
            pkgs.lib.getExe pkgs.curl
          } -X PUT "${publisher}/v1/blobs?epochs=5" --upload-file "$1"
        '';

        # Downloads a blob from walrus
        packages.do-walrus-get = pkgs.writeScriptBin "do-walrus-get" ''
          set -euo pipefail

          if [ $# -ne 2 ]; then
            echo "Usage: do-walrus-get <blob_id> <output_file>"
            echo "Downloads a blob from Walrus storage"
            exit 1
          fi

          if [ -z "$1" ]; then
            echo "Error: Blob ID cannot be empty"
            exit 1
          fi

          if [ -z "$2" ]; then
            echo "Error: Output file path cannot be empty"
            exit 1
          fi

          # Check if output directory exists
          output_dir=$(dirname "$2")
          if [ ! -d "$output_dir" ]; then
            echo "Error: Directory '$output_dir' does not exist"
            exit 1
          fi

          echo "Downloading blob '$1' to '$2'..."
          ${pkgs.lib.getExe pkgs.curl} "${aggregator}/v1/blobs/$1" -o "$2"
        '';

        # Sends a notification via Telegram
        packages.do-notify = pkgs.writeScriptBin "do-notify" ''
          set -euo pipefail

          if [ $# -lt 2 ]; then
            echo "Usage: do-notify <topic_uuid> <message> [endpoint]"
            echo "Sends a notification via bot"
            exit 1
          fi

          TOPIC_UUID="$1"
          MESSAGE="$2"
          BOT_URL="''${3:-https://ethglobal.ale.re:8080/api}"

          if [ -z "$TOPIC_UUID" ]; then
            echo "Error: Topic UUID cannot be empty"
            exit 1
          fi

          if [ -z "$MESSAGE" ]; then
            echo "Error: Message cannot be empty"
            exit 1
          fi

          echo "Sending notification to topic $TOPIC_UUID..."
          ${pkgs.lib.getExe pkgs.curl} -X POST \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"$MESSAGE\"}" \
            "$BOT_URL/$TOPIC_UUID"
        '';

        # The sui-testnet binary, this relies nix-ld
        packages.sui-testnet = pkgs.stdenv.mkDerivation {
          name = "sui-testnet";
          version = "1.51.2";

          src = sui-ubuntu-bin;

          installPhase = ''
            mkdir -p $out/bin
            for b in *; do
              if [ -f "$b" ] && [ -x "$b" ]; then
                cp "$b" $out/bin/
                chmod +x $out/bin/"$b"
              fi
            done
          '';
        };

        # The sui-testnet binary, this relies nix-ld
        packages.walrus = pkgs.stdenv.mkDerivation {
          name = "walrus";
          version = "1.28.1";

          src = walrus-ubuntu-bin;

          installPhase = ''
            mkdir -p $out/bin
            ls *
            for b in *; do
              if [ -f "$b" ] && [ -x "$b" ]; then
                cp "$b" $out/bin/
                chmod +x $out/bin/"$b"
              fi
            done
          '';
        };

        # This is always an x86_64-linux image
        packages.default = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            self.nixosModules.walrus
            self.nixosModules.web3-trainer
          ];
          # format = "qcow";
          format = "kubevirt";
        };

        # To develop this project, run `nix develop`
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.git
            pkgs.nixos-generators

            (pkgs.python3.withPackages (ps:
              with ps; [
                scikit-learn
                polars
                aiohttp
                python-telegram-bot
              ]))

            self.packages.${system}.sui-testnet
            self.packages.${system}.walrus
            self.packages.${system}.do-walrus-put
            self.packages.${system}.do-walrus-get
            self.packages.${system}.do-notify
          ];
        };
      }) // {
        # Add sui and walrus from this flake
        nixosModules.walrus = ({
          environment.systemPackages = [
            self.packages.x86_64-linux.walrus
            self.packages.x86_64-linux.sui-testnet
            self.packages.x86_64-linux.do-walrus-put
            self.packages.x86_64-linux.do-walrus-get
            self.packages.x86_64-linux.do-notify
          ];
        });

        # Module with services to fetch, train and publish
        nixosModules.web3-trainer = ({ lib, pkgs, ... }: {

          systemd.services.walrus-puller =
            import ./walrus-puller.nix { inherit self lib pkgs; };

          systemd.services.model-trainer =
            import ./model-trainer.nix { inherit self lib; };

          systemd.services.walrus-pusher =
            import ./walrus-pusher.nix { inherit self lib pkgs; };
        });

        nixosConfigurations.vm-image = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            self.nixosModules.walrus
            self.nixosModules.web3-trainer
          ];
        };

        apps.x86_64-linux = {
          vm-preview = {
            type = "app";
            program =
              "${self.nixosConfigurations.vm-image.config.system.build.vm}/bin/run-nixos-vm";
          };
        };
      };
}

