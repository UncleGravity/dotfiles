{
  config,
  lib,
  hostname,
  username,
  pkgs,
  ...
}: {
  # My NixOS modules
  my = {
    docker.enable = true;
    tailscale.enable = true;
    # escape-hatch.enable = true;
  };

  # --------------------------------------------------------------------------
  # Nix (flakes, caches, GC)
  nix = {
    channel.enable = false; # flake gang

    settings = {
      experimental-features = ["nix-command" "flakes"]; # Enable Flakes
      sandbox = "relaxed"; # Allow packages with __noChroot = false; to use external dependencies
      auto-optimise-store = lib.mkDefault false; # Avoiding some heavy IO

      # -------------------------------
      trusted-users = ["root" username]; # Allow root and ${username} to use nix-command (required by devenv for cachix to work)
    };
  };

  # ---------------------------------------------------------------------------
  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    systemd-boot.configurationLimit = 10;
  };

  # ---------------------------------------------------------------------------
  # Networking
  networking = {
    hostName = hostname;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no"; # No root login
      PasswordAuthentication = false; # No password login
    };
  };

  # ---------------------------------------------------------------------------
  # Time Zone
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = lib.mkDefault false;

  # ---------------------------------------------------------------------------
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # ---------------------------------------------------------------------------
  # services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)

  # ---------------------------------------------------------------------------
  # Define a user account. Don't forget to set a password with 'passwd'.
  # TTY autologin is gated by workstation profile (modules/nixos/workstation.nix).
  users = {
    users.${username} = {
      isNormalUser = true;
      description = "me";
      extraGroups = [
        "networkmanager"
        "wheel" # sudo
      ];
    };
    defaultUserShell = pkgs.zsh;
  };

  # ---------------------------------------------------------------------------
  # SHELLS
  environment = {
    shells = with pkgs; [bash zsh];
    pathsToLink = ["/share/zsh"]; # (apparently) get zsh completions for system packages (eg. systemd)
    systemPackages = config.my.common.systemPackages;
  };

  programs.zsh = {
    enable = true; # apparently we need this even if it's enabled in home-manager
    enableGlobalCompInit = false; # Remove compinit from /etc/zshrc, since it SLOWS down shell startup. Run compinit from user zshrc instead. (home-manager)
  };
}
