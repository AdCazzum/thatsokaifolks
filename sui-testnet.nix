{ lib, stdenv, fetchFromGitHub, rustPlatform, pkg-config, openssl, cmake
, libclang, postgresql, curl, git, gcc, llvmPackages }:

rustPlatform.buildRustPackage rec {
  pname = "sui-testnet";
  version = "unstable-2024-01-01"; # Update this as needed

  src = fetchFromGitHub {
    owner = "MystenLabs";
    repo = "sui";
    rev = "testnet"; # This will track the testnet branch
    sha256 = "sha256-2Y/B6y5nbDrb8kDgx7IBnQJUs4G6icdvdlDcE/iupIs=";
  };

  # Use cargoHash instead of cargoLock since Cargo.lock might not be in the repo
  cargoHash = "sha256-/5c5yDMSr2eknStT6lUH+tUneOTRUjTBV36sgaKzFV8=";

  nativeBuildInputs = [
    pkg-config
    cmake
    rustPlatform.bindgenHook
    llvmPackages.clang
    llvmPackages.libclang
  ];

  buildInputs = [ openssl postgresql.lib curl git ]
    ++ lib.optionals stdenv.isDarwin [
      # Add macOS-specific dependencies if needed
    ];

  # Set environment variables for the build
  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS =
      "-I${llvmPackages.libclang.lib}/lib/clang/${llvmPackages.libclang.version}/include";
  };

  # Build only the sui binary with tracing features
  cargoBuildFlags = [ "--locked" "--bin" "sui" "--features" "tracing" ];

  # Skip tests as they might require network access or specific setup
  doCheck = false;

  meta = with lib; {
    description = "Sui blockchain CLI tool (testnet branch)";
    homepage = "https://github.com/MystenLabs/sui";
    license = licenses.asl20;
    maintainers = with maintainers; [ ]; # Add your name here
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "sui";
  };
}
