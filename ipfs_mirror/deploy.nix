{
  nixipfs = { pkgs, ... }: let
    nixipfs-scripts = import (pkgs.fetchFromGitHub {
      owner = "nixipfs";
      repo = "nixipfs-scripts";
      rev = "e3b786503a51b190333d5dbca90a196b488fda5f";
      sha256 = "13y5w2qa4838p1qr856qpkihkvps55hq05svh99m2hx66rn66dq6";
    }) { inherit pkgs; };
  in {
    deployment.targetEnv = "container";
    #deployment.container.host = "your.host.if.not.localhost";

    nixpkgs.config.packageOverrides = pkgs: {
      # generate_programs_index only builds with an old nixUnstable
      nixUnstable = pkgs.nixUnstable.overrideDerivation (oldAttrs: {
        name = "nix-1.12pre4997_1351b0d";
        src = pkgs.fetchFromGitHub {
          owner = "NixOS";
          repo = "nix";
          rev = "1351b0df87a0984914769c5dc76489618b3a3fec";
          sha256 = "09zvphzik9pypi1bnjs0v83qwgl5cfb5w0c788jlr5wbd8x3crv1";
        };
      });
    };

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
                    "jobset": "release-17.03-small"
                  },
                  {
                    "channel": "nixos-17.03",
                    "project": "nixos",
                    "jobset": "release-17.03"
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
