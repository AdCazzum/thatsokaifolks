{
  description = "ThatsOkAI - Blockchain-based distributed ML platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ nix git nixos-generators ];
        };
      }) // {
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

