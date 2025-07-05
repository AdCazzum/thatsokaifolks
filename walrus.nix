{ lib, rustPlatform, fetchFromGitHub, }:
rustPlatform.buildRustPackage rec {
  pname = "walrus";
  version = "1.28.1";

  src = fetchFromGitHub {
    owner = "MystenLabs";
    repo = "walrus";
    rev = "testnet-v${version}";
    hash = "sha256-9bM1Dypl/z7vOi76HsaIXIBOQ7D3B+20JbDwKh3aILY=";
  };

  cargoHash = "";

  # cargoLock = {
  #   lockFile = ./Cargo.lock;
  #   outputHashes = {
  #     "anemo-0.0.0" = "sha256-HqXtkLe4+2xb2rrW1WBqWLYUwzM0Bd7SjHbGzVHcVBA=";
  #     "async-task-4.3.0" =
  #       "sha256-zMTWeeW6yXikZlF94w9I93O3oyZYHGQDwyNTyHUqH8g=";
  #     "axum-server-0.6.1" =
  #       "sha256-sJLPtFIJAeO6e6he7r9yJOExo8ANS5+tf3IIUkZQXoA=";
  #     "bin-version-1.50.1" =
  #       "sha256-+TTExgvpe2azpxGKn/msluBOQz5ZgS/Kh058tphnBxU=";
  #     "fastcrypto-0.1.8" =
  #       "sha256-SL7Qf8yf466t+86yG4MwL9ni4VcRWxnLpEZe11GTp0o=";
  #     "json_to_table-0.6.0" =
  #       "sha256-UKMTa/9WZgM58ChkvQWs1iKWTs8qk71gG+Q/U/4D4x4=";
  #     "msim-0.1.0" = "sha256-6UBL8axhPW+iuJzPpX3EfquC+0u/LyTDaRmX5x1n4u0=";
  #     "prometheus-parse-0.2.3" =
  #       "sha256-TGiTdewA9uMJ3C+tB+KQJICRW3dSVI0Xcf3YQMfUo6Q=";
  #     "real_tokio-1.43.0" =
  #       "sha256-7lIpa5wf4Hb19tXi9X8kV+YsHUGDiPWza123fr6lZMI=";
  #     "sui-crypto-0.0.4" =
  #       "sha256-aHwOuzThEvIddEFo2BVAQk0mPh9GE6yyW+9rNyihZIM=";
  #   };
  # };

  meta = {
    description = "Walrus storage";
    homepage = "https://github.com/MystenLabs/walrus";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "walrus";
  };
}
