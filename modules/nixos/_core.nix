{
  config,
  lib,
  hostname,
  username,
  pkgs,
  ...
}:
let
  cfg = config.my.config;
in {
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
      # Binary caches for faster builds
      substituters = cfg.binaryCaches.substituters;
      trusted-public-keys = cfg.binaryCaches.trustedPublicKeys;
      always-allow-substitutes = true;
      # -------------------------------
      trusted-users = ["root" username]; # Allow root and ${username} to use nix-command (required by devenv for cachix to work)
    };
  };

  # ---------------------------------------------------------------------------
  # Automatic garbage collection
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 30d"; # keep 30 days, at least 5
    };
  };

  # ---------------------------------------------------------------------------
  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    systemd-boot.configurationLimit = 10; # Limit to 5 latest generations
  };

  # ---------------------------------------------------------------------------
  # Networking
  networking = {
    hostName = hostname;
    networkmanager.enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no"; # No root login
      PasswordAuthentication = false; # No password login
    };
  };

  # ---------------------------------------------------------------------------
  # Set your time zone.
  time.timeZone = cfg.locale.timeZone;

  # Select internationalisation properties.
  i18n.defaultLocale = cfg.locale.defaultLocale;



  # ---------------------------------------------------------------------------
  # Disable sleep, suspend, hibernate, and hybrid-sleep
  # This is necessary because the GNOME3/GDM auto-suspend feature cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Same as above, not sure which one is the one that works. So we keep both for now.
  # TODO: Remove one of them.
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = lib.mkDefault false;

  # ---------------------------------------------------------------------------
  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # ---------------------------------------------------------------------------
  services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)

  # ---------------------------------------------------------------------------
  # Define a user account. Don't forget to set a password with 'passwd'.
  users = {
    users.${username} = {
      isNormalUser = true;
      description = "me";
      extraGroups = [
        "networkmanager"
        "wheel" # sudo
      ];
      openssh.authorizedKeys.keys = cfg.ssh.publicKeys;
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
