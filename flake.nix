{
  description = "ThatsOkAI - Blockchain-based distributed ML platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sui-overlay = { url = "github:akiross/sui-overlay"; };

    naersk.url = "github:nix-community/naersk";

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
    , naersk, walrus-ubuntu-bin }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # overlays = [ sui-overlay.overlays.${system}.default ];
        # pkgs = import nixpkgs { inherit system overlays; };
        pkgs = nixpkgs.legacyPackages.${system};
        #naersk' = pkgs.callPackage naersk { };

        # Walrus endpoints
        aggregator = "https://aggregator.walrus-testnet.walrus.space";
        publisher = "https://publisher.walrus-testnet.walrus.space";

      in {
        # Uploads a file to walrus for 5 epochs
        packages.do-walrus-put = pkgs.writeShellScriptBin "walrus-put" ''
          ${
            pkgs.lib.getExe pkgs.curl
          } -X PUT "${publisher}/v1/blobs?epochs=5" --upload-file "$1"
        '';

        # Downloads a blob from walrus
        packages.do-walrus-get = pkgs.writeShellScriptBin "walrus-get" ''
          ${pkgs.lib.getExe pkgs.curl} "${aggregator}/v1/blobs/$1" -o $2
        '';

        packages.sui-testnet = pkgs.stdenv.mkDerivation {
          name = "sui-testnet";
          version = "1.51.2";

          src = sui-ubuntu-bin;

          LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

          #  pkgs.fetchzip {
          #    # stripRoot = false;
          #    curlOpts = "-L";
          #    url =
          #      "https://github.com/MystenLabs/sui/releases/download/testnet-v${version}/sui-testnet-v${version}-ubuntu-x86_64.tgz";

          #    sha256 = "";
          #  };

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

          # optional arguments:
          # explicit nixpkgs and lib:
          # pkgs = nixpkgs.legacyPackages.x86_64-linux;
          # lib = nixpkgs.legacyPackages.x86_64-linux.lib;
          # additional arguments to pass to modules:
          # specialArgs = { myExtraArg = "foobar"; };

          # you can also define your own custom formats
          # customFormats = { "myFormat" = <myFormatModule>; ... };
          # format = "myFormat";
        };

        # This fails, unsure why
        # packages.walrus = pkgs.callPackage ./walrus.nix { };
        # This fails with cargo workspace stuff, unsure why
        # packages.walrus = naersk'.buildPackage {
        #   src = pkgs.fetchFromGitHub {
        #     owner = "MystenLabs";
        #     repo = "walrus";
        #     rev = "testnet-v1.26.4";
        #     hash =
        #       "sha256-r3JlebRGh6SIYzzuy4Oa9RLe2Z2Q00gcAyv7XkxMLBo="; # sha256-9bM1Dypl/z7vOi76HsaIXIBOQ7D3B+20JbDwKh3aILY=";
        #   };
        # };

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

        #packages.x86_64-linux.sui-testnet =
        # nixpkgs.legacyPackages.x86_64-linux.callPackage ./sui-testnet.nix { };

        nixosConfigurations.vm-preview = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
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

