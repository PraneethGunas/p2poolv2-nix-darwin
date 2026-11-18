{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.p2poolv2;
  settingsFormat = pkgs.formats.toml { };
  logFile = name: "/var/log/p2poolv2-${name}.log";

  instanceModule =
    { name, ... }:
    {
      options = {
        package = lib.mkOption {
          type = lib.types.package;
          description = "Package providing the `p2poolv2` binary.";
        };

        settings = lib.mkOption {
          inherit (settingsFormat) type;
          default = { };
          description = "P2Poolv2 configuration, rendered as TOML.";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Environment file of `P2POOL_<SECTION>__<KEY>=value` overrides, read
            at runtime so secrets stay out of the Nix store.
          '';
        };

        staticDir = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Static files for the API dashboard.";
        };

        requiredPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Paths the daemon waits for before starting.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/p2poolv2-${name}";
          readOnly = true;
          description = "State directory for the store and logs.";
        };
      };
    };

  mkDaemon =
    name: instance:
    let
      configFile = settingsFormat.generate "p2poolv2-${name}.toml" instance.settings;
    in
    lib.nameValuePair "p2poolv2-${name}" {
      # launchd has no environment file setting, so the script exports it.
      script = ''
        ${lib.concatMapStrings (path: "/bin/wait4path ${path}\n") instance.requiredPaths}
        ${lib.optionalString (instance.environmentFile != null) ''
          set -a
          . ${instance.environmentFile}
          set +a
        ''}
        exec ${lib.getExe' instance.package "p2poolv2"} --config ${configFile}
      '';
      environment = lib.optionalAttrs (instance.staticDir != null) {
        P2POOL_STATIC_DIR = "${instance.staticDir}";
      };
      serviceConfig = {
        UserName = cfg.user;
        GroupName = cfg.group;
        WorkingDirectory = instance.dataDir;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        SoftResourceLimits.NumberOfFiles = 65536;
        StandardOutPath = logFile name;
        StandardErrorPath = logFile name;
      };
    };
in
{
  options.services.p2poolv2 = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = "P2Poolv2 nodes, each run as the `p2poolv2-<name>` launchd daemon.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "_p2poolv2";
      readOnly = true;
      description = "User every node runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "_p2poolv2";
      readOnly = true;
      description = "Group every node runs as.";
    };
  };

  config = lib.mkIf (cfg.instances != { }) {
    users = {
      knownUsers = [ cfg.user ];
      knownGroups = [ cfg.group ];
      users.${cfg.user} = {
        uid = 421;
        gid = 421;
        home = "/var/empty";
        isHidden = true;
        description = "P2Poolv2";
      };
      groups.${cfg.group} = {
        gid = 421;
        description = "P2Poolv2";
      };
    };

    system.activationScripts.postActivation.text = lib.concatStrings (
      lib.mapAttrsToList (name: instance: ''
        /usr/bin/install -d -m 0750 -o ${cfg.user} -g ${cfg.group} ${instance.dataDir}
        /usr/bin/touch ${logFile name}
        /usr/sbin/chown ${cfg.user}:${cfg.group} ${logFile name}
        /bin/chmod 0640 ${logFile name}
      '') cfg.instances
    );

    launchd.daemons = lib.mapAttrs' mkDaemon cfg.instances;
  };
}
