{ pkgs, bitcoinSource }:

{
  name = "testnet5";
  p2poolNetwork = "testnet5";
  inherit bitcoinSource;
  bitcoindPackage = pkgs.callPackage ../pkgs/bitcoind-testnet5/package.nix { src = bitcoinSource; };
  bitcoindFlags = [
    "-testnet5"
    "-addnode=lapis.erisian.com.au:18353"
    "-addnode=tn5.21m.dev:18353"
  ];
  p2pPort = 18353;
  rpcPort = 18352;
  zmqHashBlockPort = 28335;
}
