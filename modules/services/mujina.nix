{
  config,
  lib,
  ...
}:

let
  cfg = config.services.mujina;
  logFile = "/var/log/mujina.log";
in
{
  options.services.mujina = {
    enable = lib.mkEnableOption "the Mujina miner as the `mujina` launchd daemon";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Package providing the `mujina-minerd` binary.";
    };

    poolUrl = lib.mkOption {
      type = lib.types.str;
      example = "stratum+tcp://127.0.0.1:3333";
      description = "Stratum v1 pool the miner connects to.";
    };

    poolUser = lib.mkOption {
      type = lib.types.str;
      description = "Stratum username.";
    };

    apiListen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:7785";
      description = "Address of the REST API, which has no authentication.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "_mujina";
      readOnly = true;
      description = "User the daemon runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "_mujina";
      readOnly = true;
      description = "Group the daemon runs as.";
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      knownUsers = [ cfg.user ];
      knownGroups = [ cfg.group ];
      users.${cfg.user} = {
        uid = 422;
        gid = 422;
        home = "/var/empty";
        isHidden = true;
        description = "Mujina";
      };
      groups.${cfg.group} = {
        gid = 422;
        description = "Mujina";
      };
    };

    system.activationScripts.postActivation.text = ''
      /usr/bin/touch ${logFile}
      /usr/sbin/chown ${cfg.user}:${cfg.group} ${logFile}
      /bin/chmod 0640 ${logFile}
    '';

    launchd.daemons.mujina = {
      command = lib.getExe' cfg.package "mujina-minerd";
      environment = {
        MUJINA_POOL_URL = cfg.poolUrl;
        MUJINA_POOL_USER = cfg.poolUser;
        MUJINA_API_LISTEN = cfg.apiListen;
      };
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
