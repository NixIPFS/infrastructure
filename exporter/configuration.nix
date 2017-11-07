{ config, pkgs, ... }:
let
  nameservers = [ "8.8.8.8" ];
in
{
  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 80 443 873 ];
    };
    nat = {
      enable = true;
      externalInterface = "eth0";
      externalIP = "a.b.c.d";
      internalIPs = [ "10.0.48.0/30" "10.0.48.4/30" "10.0.48.8/30" ];
      internalInterfaces = [
        "ve-exporter"
        "ve-cache"
      ];
      forwardPorts = [
        # http + https
        { sourcePort = 80; destination = "10.0.48.14"; }
        { sourcePort = 443; destination = "10.0.48.14"; }
        # rsync
        { sourcePort = 873; destination = "10.0.48.14"; }
      ];
    };
  };

  containers.exporter = {
    privateNetwork = true;
    hostAddress = "10.0.48.13";
    localAddress = "10.0.48.14";
    autoStart = true;
    bindMounts = {
      # See containers.cache.config.folder
      "/srv/"          = { hostPath = "/some/big/volume/cache"; isReadOnly = true; };
    };
    config =
    { config, pkgs, ... }:
    {
      networking.firewall.allowedTCPPorts = [ 80 443 873 ];
      services.nginx = {
        enable = true;
        statusPage = true;
        virtualHosts = {
          "tarballs.example.com" = {
            forceSSL = true;
            enableACME = true;
            root = "/srv/tarballs";
            locations."/" = {
              extraConfig = ''
                autoindex on;
              '';
            };
          };
          "cache.example.com" = {
            forceSSL = true;
            enableACME = true;
            root = "/srv/binary_cache";
          };
          "channels.example.com" = {
            forceSSL = true;
            enableACME = true;
            root = "/srv/channels";
            locations."/" = {
              extraConfig = ''
                autoindex on;
              '';
            };
          };
        };
      };
      services.rsyncd = {
        enable = true;
        motd = "Welcome at cache.example.com";
        modules = {
          nixos = { path = "/srv";
                    "read only" = "yes";
                    "filter" = "- nixos-files.sqlite - .cache/***";
                    comment = "NixOS releases";
                  };
        };
      };
    };
  };

  containers.cache = {
    privateNetwork = true;
    hostAddress = "10.0.48.9";
    localAddress = "10.0.48.10";
    autoStart = true;
    bindMounts = {
      "/srv"          = { hostPath = "/some/big/volume"; isReadOnly = false; };
    };
    config =
    { config, pkgs, ... }: let
      nixipfs-scripts = import (pkgs.fetchFromGitHub {
        owner = "nixipfs";
        repo = "nixipfs-scripts";
        rev = "d3131fe42efb7aca8ebcccf873dfa81f25fb7847";
        sha256 = "0f36wqp89k4z470vs9ahhqjs8clwldgvm28y4gsxvj34w275m13x";
      }) { inherit pkgs; };
      folder = "/srv/cache";
    in {
      networking.nameservers = nameservers;
      users.extraUsers.nixipfs = { home = folder; group = "nixipfs"; };
      users.extraGroups.nixipfs = {};
      systemd.tmpfiles.rules = [ "d ${folder} 0755 nixipfs nixipfs -" ];

      systemd.timers."update-nixos-release" = {
        description = "Sync with cache.nixos.org";
        wantedBy = [ "timers.target" ];
        partOf = [ "update-nixos-release.service" ];
        timerConfig = {
          OnCalendar = "hourly";
        };
      };

      systemd.services."update-nixos-release" = {
        path = [ pkgs.bash pkgs.ipfs nixipfs-scripts.generate_programs_index ];
        environment.SHELL = "${pkgs.bash}/bin/bash";
        serviceConfig = {
          Type = "oneshot";
          PermissionsStartOnly = true;
          TimeoutStartSec = 21600; # 6 hours
          User = "nixipfs";
          Group = "nixipfs";
          ExecStart = let
            releaseCfg = pkgs.writeText "nixos_release.json" (builtins.toJSON {
              hydra = "https://hydra.nixos.org";
              cache = "https://cache.nixos.org";
              target_cache = "https://cache.nixos.community";
              repo = "https://github.com/NixOS/nixpkgs.git";
              max_threads = 69;
              releases = [
                {
                  "channel" = "nixos-17.03-small";
                  "project" = "nixos";
                  "jobset" = "release-17.03-small";
                  "job"    = "tested";
                  "keep" =  7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixos-17.03";
                  "project" = "nixos";
                  "jobset" = "release-17.03";
                  "job"    = "tested";
                  "keep" = 7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixos-17.09-small";
                  "project" = "nixos";
                  "jobset" = "release-17.09-small";
                  "job"    = "tested";
                  "keep" =  7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixos-17.09";
                  "project" = "nixos";
                  "jobset" = "release-17.09";
                  "job"    = "tested";
                  "keep" = 7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixos-unstable-small";
                  "project" = "nixos";
                  "jobset" = "unstable-small";
                  "job"    = "tested";
                  "keep" = 7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixos-unstable";
                  "project" = "nixos";
                  "jobset" = "trunk-combined";
                  "job"    = "tested";
                  "keep" = 7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixpkgs-unstable";
                  "project" = "nixpkgs";
                  "jobset" = "trunk";
                  "job"    = "unstable";
                  "keep" = 7;
                  "mirror" =  true;
                }
                {
                  "channel" = "nixpkgs-17.09-darwin";
                  "project" = "nixpkgs";
                  "jobset" = "nixpkgs-17.09-darwin";
                  "job"    = "darwin-tested";
                  "keep" = 7;
                  "mirror" =  true;
                }
              ];
            });
          in "${nixipfs-scripts.nixipfs}/bin/release_nixos --config ${releaseCfg} --ipfsapi 127.0.0.1 5001 --dir ${folder} --tmpdir /tmp --no_ipfs --gc";
          PrivateTmp = true;
          PrivateDevices = true;
          WorkingDirectory = folder;
        };
      };
    };
  };

}
