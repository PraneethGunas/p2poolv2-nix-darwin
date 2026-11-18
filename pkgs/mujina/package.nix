{
  lib,
  stdenv,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
  udev,
  src,
}:

let
  # utoipa-swagger-ui 10.0.2 downloads this archive in its build script. The
  # Nix build has no network, so the archive is fetched here instead.
  swaggerUi = fetchurl {
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v5.32.6.zip";
    hash = "sha256-s8B+CRVZtZqDP2ZUfrH8GPKJb5bj8flT4vHvsyiqM5Q=";
  };
in
rustPlatform.buildRustPackage {
  pname = "mujina";
  inherit ((lib.importTOML "${src}/mujina-miner/Cargo.toml").package) version;
  inherit src;

  # Drives a Bitaxe Gamma Duo (650). A single-chip Bitaxe Gamma fails chip
  # enumeration with this patch.
  patches = [ ./gamma-duo.patch ];

  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "--bin"
    "mujina-minerd"
  ];

  env.SWAGGER_UI_DOWNLOAD_URL = "file://${swaggerUi}";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ udev ];

  doCheck = false;

  meta = {
    description = "Open-source Bitcoin mining firmware";
    homepage = "https://github.com/256foundation/mujina";
    license = lib.licenses.gpl3Plus;
    mainProgram = "mujina-minerd";
  };
}
