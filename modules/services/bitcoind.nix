{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bitcoind;
  label = "bitcoind-${cfg.name}";
  configFile = pkgs.writeText "${label}.conf" cfg.extraConfig;
  logFile = "/var/log/${label}.log";
in
{
  options.services.bitcoind = {
    enable = lib.mkEnableOption "bitcoind as the `bitcoind-<name>` launchd daemon";

    name = lib.mkOption {
      type = lib.types.str;
      description = "Network name, used in the daemon label and data directory.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "Package providing the `bitcoind` binary.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Command line options.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Contents of the config file passed with `-conf`.";
    };

    requiredPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths the daemon waits for before starting.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "_bitcoind";
      readOnly = true;
      description = "User the daemon runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "_bitcoind";
      readOnly = true;
      description = "Group the daemon runs as.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${label}";
      readOnly = true;
      description = "Data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      knownUsers = [ cfg.user ];
      knownGroups = [ cfg.group ];
      users.${cfg.user} = {
        uid = 420;
        gid = 420;
        home = cfg.dataDir;
        isHidden = true;
        description = "bitcoind";
      };
      groups.${cfg.group} = {
        gid = 420;
        description = "bitcoind";
      };
    };

    system.activationScripts.postActivation.text = ''
      /usr/bin/install -d -m 0750 -o ${cfg.user} -g ${cfg.group} ${cfg.dataDir}
      /usr/bin/touch ${logFile}
      /usr/sbin/chown ${cfg.user}:${cfg.group} ${logFile}
      /bin/chmod 0640 ${logFile}
    '';

    launchd.daemons.${label} = {
      script = ''
        ${lib.concatMapStrings (path: "/bin/wait4path ${path}\n") cfg.requiredPaths}
        exec ${lib.getExe' cfg.package "bitcoind"} \
          -datadir=${cfg.dataDir} \
          -conf=${configFile} \
          -printtoconsole=0 \
          ${lib.escapeShellArgs cfg.extraArgs}
      '';
      serviceConfig = {
        UserName = cfg.user;
        GroupName = cfg.group;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
      };
    };
  };
}
