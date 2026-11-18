{
  lib,
  bitcoind,
  src,
}:

let
  cmakeLines = lib.splitString "\n" (builtins.readFile "${src}/CMakeLists.txt");
  versionPart =
    name:
    lib.pipe cmakeLines [
      (lib.findFirst (lib.hasPrefix "set(CLIENT_VERSION_${name} ") null)
      (builtins.match "set\\(CLIENT_VERSION_${name} ([0-9]+)\\)")
      builtins.head
    ];
in
(bitcoind.override { withWallet = true; }).overrideAttrs {
  pname = "bitcoind-testnet5";
  # The version the source declares, which `bitcoin-cli --version` prints.
  version = "${versionPart "MAJOR"}.${versionPart "MINOR"}";
  inherit src;
  # Release signature verification applies only to release tarballs.
  preUnpack = "";
  doCheck = false;
}
