# linux-builder.nix
#
# Nix module to configure a Linux VM builder on nix-darwin
{username, ...}: {
  # Ensure virtualization tools are available on the host
  # environment.systemPackages = lib.mkDefault [pkgs.qemu]; # qemu provides necessary tools

  nix = {
    # -----------------
    linux-builder = {
      enable = false;
      ephemeral = true;
      config = {
        virtualisation = {
          darwin-builder = {
            # hostPort = 22;
            diskSize = 40 * 1024; # 40GB
            memorySize = 16 * 1024; # 8GB
          };
          cores = 4;
        };
      };
    };
    # -----------------
    distributedBuilds = true;
    # -----------------
    settings = {
      substituters = ["https://virby-nix-darwin.cachix.org"];
      trusted-public-keys = [
        "virby-nix-darwin.cachix.org-1:z9GiEZeBU5bEeoDQjyfHPMGPBaIQJOOvYOOjGMKIlLo="
      ];
      trusted-users = ["@admin" username];
      builders-use-substitutes = true;
    };
    # -----------------
  };

  # Enable virby Linux builder
  # Service org.nixos.virbyd
  services.virby = {
    enable = true;
    cores = 12;
    memory = 16384; # 16GB
    # onDemand = {
    #   enable = true;
    #   ttl = 180; # Idle timeout in minutes
    # };
    rosetta = true; # REQUIRES ROSETTA ENABLED MANUALLY: softwareupdate --install-rosetta --agree-to-license
    debug = true;
  };
}
