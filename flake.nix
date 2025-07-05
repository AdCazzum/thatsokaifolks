{
  description = "ThatsOkAI - Blockchain-based distributed ML platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
        pkgs = nixpkgs.legacyPackages.${system};

        # Walrus endpoints
        aggregator = "https://aggregator.walrus-testnet.walrus.space";
        publisher = "https://publisher.walrus-testnet.walrus.space";

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

        packages.sui-testnet = pkgs.stdenv.mkDerivation {
          name = "sui-testnet";
          version = "1.51.2";

          src = sui-ubuntu-bin;

          # LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

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
            # you can include your own nixos configuration here, i.e.
            ./configuration.nix
          ];
          format = "qcow";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.git
            pkgs.nixos-generators

            self.packages.${system}.sui-testnet
            self.packages.${system}.walrus
            self.packages.${system}.do-walrus-put
            self.packages.${system}.do-walrus-get
          ];
        };
      }) // {
        nixosConfigurations.vm-preview = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            # Base configuration
            ./configuration.nix

            # Add sui and walrus from this flake
            ({
              environment.systemPackages = [
                self.packages.x86_64-linux.walrus
                self.packages.x86_64-linux.sui-testnet
                self.packages.x86_64-linux.do-walrus-put
                self.packages.x86_64-linux.do-walrus-get
              ];
            })

            # Add a service that fetches data from walrus upon boot
            ({ lib, ... }: {
              systemd.services.walrus-puller = {
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
                '';

                wants = [ "network-online.target" ];
                after = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];
              };
            })
          ];
        };

        apps.x86_64-linux = {
          vm-preview = {
            type = "app";
            program =
              "${self.nixosConfigurations.vm-preview.config.system.build.vm}/bin/run-nixos-vm";
          };
        };
      };
}

