{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.p2poolv2RpcCredentials;
  jq = lib.getExe pkgs.jq;

  writeUser = user: methods: ''
    credentials=${cfg.directory}/${user}.json
    if [ ! -s "$credentials" ]; then
      ${lib.getExe pkgs.python3} ${cfg.rpcauthScript} --json ${lib.escapeShellArg user} > "$credentials.tmp"
      mv "$credentials.tmp" "$credentials"
    fi
    printf 'rpcauth=%s\n' "$(${jq} -r .rpcauth "$credentials")" >> "$conf"
    printf 'rpcwhitelist=%s:%s\n' ${lib.escapeShellArg user} ${lib.escapeShellArg (lib.concatStringsSep "," methods)} >> "$conf"
    environment=${cfg.environmentFile user}
    printf 'P2POOL_BITCOINRPC__USERNAME=%s\nP2POOL_BITCOINRPC__PASSWORD=%s\n' \
      "$(${jq} -r .username "$credentials")" \
      "$(${jq} -r .password "$credentials")" > "$environment.tmp"
    /usr/sbin/chown ${cfg.environmentFileOwner} "$environment.tmp"
    /bin/chmod 0400 "$environment.tmp"
    mv "$environment.tmp" "$environment"
  '';
in
{
  options.services.p2poolv2RpcCredentials = {
    enable = lib.mkEnableOption "generating bitcoind RPC credentials for P2Poolv2 nodes on activation";

    rpcauthScript = lib.mkOption {
      type = lib.types.path;
      description = "Bitcoin Core's `share/rpcauth/rpcauth.py`.";
    };

    users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "RPC methods each user may call, keyed by user name.";
    };

    bitcoindGroup = lib.mkOption {
      type = lib.types.str;
      description = "Group allowed to read the generated bitcoind config.";
    };

    environmentFileOwner = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to read the generated environment files.";
    };

    directory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/p2poolv2-rpc";
      readOnly = true;
      description = "Directory holding the generated credentials.";
    };

    bitcoindConfFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.directory}/bitcoind-rpc.conf";
      readOnly = true;
      description = "bitcoind config with the generated `rpcauth` and `rpcwhitelist` lines.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = user: "${cfg.directory}/${user}.env";
      readOnly = true;
      description = "Environment file with a user's P2Poolv2 RPC credentials.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Credentials persist across activations. The directory is traversable but
    # not listable, so each service opens only the file its permissions allow.
    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -m 0711 -o root -g wheel ${cfg.directory}
      (
        umask 077
        conf=${cfg.bitcoindConfFile}.tmp
        # Users without an rpcwhitelist line, including the cookie user, keep full access.
        printf 'rpcwhitelistdefault=0\n' > "$conf"
        ${lib.concatStrings (lib.mapAttrsToList writeUser cfg.users)}
        /usr/bin/chgrp ${cfg.bitcoindGroup} "$conf"
        /bin/chmod 0640 "$conf"
        mv "$conf" ${cfg.bitcoindConfFile}
      )
    '';
  };
}
