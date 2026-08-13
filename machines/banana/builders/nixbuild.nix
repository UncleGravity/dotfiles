{
  config,
  lib,
  ...
}: let
  nixbuildHost = "nixbuild-builder";
  nixbuildCache = "unclegravity-nix";
  nixbuildSubstituters = lib.concatStringsSep "," config.nix.settings.substituters;
  nixbuildTrustedPublicKeys = lib.concatStringsSep "," config.nix.settings.trusted-public-keys;
  nixbuildSshEnvironment = [
    "NIXBUILDNET_ACCESS_TOKENS=cachix://${nixbuildCache}=WRITE:${config.sops.placeholder."vars/cachix/auth-token"}"
    "NIXBUILDNET_CACHES=cachix://${nixbuildCache}"
    "NIXBUILDNET_SUBSTITUTERS=${nixbuildSubstituters}"
    "NIXBUILDNET_TRUSTED_PUBLIC_KEYS=${nixbuildTrustedPublicKeys}"
  ];
in {
  sops = {
    secrets = {
      "nixbuild/ssh-key" = {
        sopsFile = ../secrets.yaml;
        mode = "0400";
      };
    };

    templates."nixbuild-ssh.conf" = {
      content = ''
        Host ${nixbuildHost}
          HostName eu.nixbuild.net
          HostKeyAlias eu.nixbuild.net
          IdentityFile ${config.sops.secrets."nixbuild/ssh-key".path}
          IdentitiesOnly yes
          PubkeyAcceptedKeyTypes ssh-ed25519
          ServerAliveInterval 60
          IPQoS throughput
          SetEnv ${lib.concatStringsSep " " nixbuildSshEnvironment}
      '';
      mode = "0400";
    };
  };

  programs.ssh = {
    knownHosts."nixbuild.net" = {
      hostNames = ["eu.nixbuild.net"];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };

    extraConfig = ''
      Host eu.nixbuild.net
        PubkeyAcceptedKeyTypes ssh-ed25519
        ServerAliveInterval 60
    '';
  };

  launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables.NIX_SSHOPTS = "-F ${config.sops.templates."nixbuild-ssh.conf".path}";

  nix.buildMachines = [
    {
      hostName = nixbuildHost;
      protocol = "ssh-ng";
      system = "aarch64-linux";
      sshKey = config.sops.secrets."nixbuild/ssh-key".path;
      maxJobs = 100;
      supportedFeatures = ["benchmark" "big-parallel"];
    }
    {
      hostName = nixbuildHost;
      protocol = "ssh-ng";
      system = "x86_64-linux";
      sshKey = config.sops.secrets."nixbuild/ssh-key".path;
      maxJobs = 100;
      supportedFeatures = ["benchmark" "big-parallel"];
    }
  ];
}
