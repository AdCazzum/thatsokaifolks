{
  description = "ThatsOkAI - Blockchain-based distributed ML platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, flake-utils, nixos-generators }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ nix git pkgs.nixos-generators ];
        };
      }) // {

        packages.x86_64-linux.default = nixos-generators.nixosGenerate {
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

        nixosConfigurations.vm-preview = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
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

