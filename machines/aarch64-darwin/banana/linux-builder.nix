# linux-builder.nix
#
# Nix module to configure a Linux VM builder on nix-darwin
# using darwin.linux-builder.
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Ensure virtualization tools are available on the host
  # environment.systemPackages = lib.mkDefault [pkgs.qemu]; # qemu provides necessary tools

  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    # systems = ["x86_64-linux" "aarch64-linux"];
    # config.boot.binfmt.emulatedSystems = ["x86_64-linux"];
    # maxJobs = 4;
    config = {
      # environment.systemPackages = [pkgs.git pkgs.neovim];
      virtualisation = {
        darwin-builder = {
          # hostPort = 22;
          diskSize = 40 * 1024; # 40GB
          memorySize = 16 * 1024; # 8GB
        };
        cores = 8;
      };
    };
  };

  # Configure the builder VM details for Nix
  # nix.buildMachines = lib.mkDefault [{
  #   # hostName = "localhost"; # Connect via localhost
  #   sshUser = "builder";
  #   sshKey = "/etc/nix/builder_ed25519"; # Key installed by the builder setup
  #   system = linuxSystem; # Specify the builder's system type
  #   # maxJobs = 4;
  #   # supportedFeatures = [ "kvm" "benchmark" "big-parallel" "nixos-test" ]; # Standard features
  #   # port = builderHostPort; # Ensure Nix knows the port
  # }];

  # Ensure the SSH config directory exists for the config file below
  # system.activationScripts.etcLink.text = lib.mkBefore ''
  #   mkdir -p /etc/ssh/ssh_config.d
  # '';

  # Manage the SSH config file via Nix
  # environment.etc."ssh/ssh_config.d/100-linux-builder.conf" = {
  #   text = ''
  #     Host linux-builder
  #       Hostname localhost
  #       HostKeyAlias linux-builder
  #       Port ${toString builderHostPort} # Use configured port
  #   '';
  #   mode = "0644"; # Standard permissions for ssh config
  # };

  # Ensure the user running nix-daemon is a trusted user
  # Note: This adds the user running the daemon, typically root.
  # You still need your *own* user in nix.conf's extra-trusted-users
  # if you are connecting directly to the daemon socket without sudo.
  nix.settings.trusted-users = ["@admin"];
}
