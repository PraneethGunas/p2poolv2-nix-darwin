{
  config,
  inputs,
  lib,
  pkgs,
  local,
  ...
}:

let
  network = import ../../networks/testnet5.nix {
    inherit pkgs;
    bitcoinSource = inputs.bitcoin-testnet5;
  };
  inherit (local) node miner;
  nodeName = "main";
  rpcUser = "p2pool-${nodeName}";
  rpcMethods = [
    "decoderawtransaction"
    "getblockchaininfo"
    "getblocktemplate"
    "getdifficulty"
    "submitblock"
  ];
  credentials = config.services.p2poolv2RpcCredentials;
  nodeSource = inputs.${node.source};
  dataDir = config.services.p2poolv2.instances.${nodeName}.dataDir;
in
{
  imports = [
    ../../modules/services/bitcoind.nix
    ../../modules/services/mujina.nix
    ../../modules/services/p2poolv2.nix
    ../../modules/services/rpc-credentials.nix
  ];

  assertions = [
    {
      assertion = lib.allUnique [
        network.p2pPort
        network.rpcPort
        network.zmqHashBlockPort
        node.p2pPort
        node.stratumPort
        node.apiPort
        node.electrumPort
      ];
      message = "Ports must be unique across bitcoind and the P2Poolv2 node.";
    }
  ];

  services = {
    p2poolv2RpcCredentials = {
      enable = true;
      rpcauthScript = "${network.bitcoinSource}/share/rpcauth/rpcauth.py";
      bitcoindGroup = config.services.bitcoind.group;
      environmentFileOwner = config.services.p2poolv2.user;
      users.${rpcUser} = rpcMethods;
    };

    bitcoind = {
      enable = true;
      inherit (network) name;
      package = network.bitcoindPackage;
      extraConfig = ''
        includeconf=${credentials.bitcoindConfFile}
      '';
      extraArgs = network.bitcoindFlags ++ [
        "-rpcbind=127.0.0.1"
        "-rpcallowip=127.0.0.1"
        "-zmqpubhashblock=tcp://127.0.0.1:${toString network.zmqHashBlockPort}"
        # P2Poolv2 needs block templates and block submission, not block
        # history, a transaction index or a wallet.
        "-prune=550"
        "-dbcache=100"
        "-maxmempool=50"
        "-maxconnections=16"
        "-disablewallet"
      ];
      requiredPaths = [ credentials.bitcoindConfFile ];
    };

    p2poolv2.instances.${nodeName} = {
      package = nodeSource.packages.${pkgs.stdenv.hostPlatform.system}.p2poolv2_node;
      staticDir = "${nodeSource}/p2poolv2_api/static";
      environmentFile = credentials.environmentFile rpcUser;
      requiredPaths = [ (credentials.environmentFile rpcUser) ];
      settings = {
        network = {
          listen_address = "/ip4/0.0.0.0/tcp/${toString node.p2pPort}";
          dial_peers = [ ];
          dns_seed = true;
          max_pending_incoming = 10;
          max_pending_outgoing = 10;
          max_established_incoming = 50;
          max_established_outgoing = 50;
          max_established_per_peer = 2;
          max_workbase_per_second = 10;
          max_userworkbase_per_second = 10;
          max_miningshare_per_second = 100;
          max_inventory_per_second = 100;
          max_transaction_per_second = 100;
          max_requests_per_second = 100;
          dial_timeout_secs = 30;
        };
        store = {
          path = "${dataDir}/store.db";
          pplns_ttl_days = 7;
        };
        stratum = {
          hostname = "127.0.0.1";
          port = node.stratumPort;
          start_difficulty = 10000;
          minimum_difficulty = 100;
          solo_address = node.soloAddress;
          bootstrap_address = node.bootstrapAddress;
          miner_address = node.minerAddress;
          zmqpubhashblock = "tcp://127.0.0.1:${toString network.zmqHashBlockPort}";
          network = network.p2poolNetwork;
          version_mask = "1fffe000";
          pool_signature = "P2Poolv2";
        };
        bitcoinrpc = {
          url = "http://127.0.0.1:${toString network.rpcPort}";
        };
        logging = {
          file = "${dataDir}/logs/p2pool.log";
          console = false;
          level = "info";
          stats_dir = "${dataDir}/logs/stats";
        };
        api = {
          hostname = "127.0.0.1";
          port = node.apiPort;
        };
        electrum = {
          enabled = true;
          hostname = "127.0.0.1";
          port = node.electrumPort;
          max_connections = 64;
        };
      };
    };

    mujina = {
      inherit (miner) enable;
      package = pkgs.callPackage ../../pkgs/mujina/package.nix { src = inputs.mujina; };
      poolUrl = "stratum+tcp://127.0.0.1:${toString node.stratumPort}";
      poolUser = miner.payoutAddress;
    };
  };
}
