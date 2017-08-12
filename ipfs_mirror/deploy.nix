{
  nixipfs = { pkgs, ... }: let
    nixipfs-scripts = import (pkgs.fetchFromGitHub {
      owner = "nixipfs";
      repo = "nixipfs-scripts";
      rev = "4021e7db8436625122e388d0c5d6cc5d30a13309";
      sha256 = "1fqaq7k1q4f55q7rd2dlyxjm8dv4r4675dnqmywydddlvnmrmlkk";
    }) { inherit pkgs; };
  in {
    deployment.targetEnv = "container";
    #deployment.container.host = "your.host.if.not.localhost";

    environment.systemPackages = [ pkgs.ipfs pkgs.tmux pkgs.iftop pkgs.atop ];
    users.extraUsers.nixipfs = { home = "/srv"; group = "nixipfs"; };
    users.extraGroups.nixipfs = {};

    networking.firewall = {
      allowedTCPPorts = [ 4001 ];
    };

    services.ipfs = {
      enable = true;
      emptyRepo = true;
    };

    systemd.services."update-nixos-release" = {
      path = [ pkgs.bash pkgs.ipfs nixipfs-scripts.generate_programs_index ];
      environment.SHELL = "${pkgs.bash}/bin/bash";
      preStart = "mkdir -p /srv && chown -R nixipfs:nixipfs /srv";
      serviceConfig = {
        Type = "oneshot";
        PermissionsStartOnly = true;
        User = "nixipfs";
        Group = "nixipfs";
        ExecStart = let
          releaseCfg = pkgs.writeText "nixos_release.json"
            ''
              {
                "hydra":"https://hydra.nixos.org",
                "cache":"https://cache.nixos.org",
                "target_cache": "http://cache.nixos.community",
                "max_threads": 69,
                "releases": [
                  {
                    "channel": "nixos-17.03-small",
                    "project": "nixos",
                    "jobset": "release-17.03-small",
                    "keep": 7
                  },
                  {
                    "channel": "nixos-17.03",
                    "project": "nixos",
                    "jobset": "release-17.03",
                    "keep": 7
                  }
                ]
              }
            '';
            in "${nixipfs-scripts.nixipfs}/bin/release_nixos --config ${releaseCfg} --ipfsapi 127.0.0.1 5001 --dir /srv --tmpdir /tmp";
          PrivateTmp = true;
          PrivateDevices = true;
          WorkingDirectory = "/srv";
        };
      };
  };
}
 
