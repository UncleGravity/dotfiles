{
  lib,
  hostname,
  username,
  pkgs,
  ...
}: {
  # Enable Flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.sandbox = "relaxed"; # Allow packages with __noChroot = false; to use external dependencies
  nix.channel.enable = false;

  # --------------------------------------------------------------------------
  # Binary caches for faster builds
  nix.settings.substituters = [
    "https://nix-community.cachix.org?priority=41"
    "https://numtide.cachix.org?priority=42"
  ];
  nix.settings.trusted-public-keys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------------------
  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # ---------------------------------------------------------------------------
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5; # Limit to 5 latest generations

  # ---------------------------------------------------------------------------
  # Networking
  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no"; # No root login
      PasswordAuthentication = false; # No password login
    };
  };

  # ---------------------------------------------------------------------------
  # Set your time zone.
  time.timeZone = "Asia/Taipei";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ---------------------------------------------------------------------------
  # Disable sleep, suspend, hibernate, and hybrid-sleep
  # This is necessary because the GNOME3/GDM auto-suspend feature cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

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
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
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
  # Define a user account. Don't forget to set a password with 'passwd'.
  users = {
    users.${username} = {
      isNormalUser = true;
      description = "me";
      extraGroups = [
        "networkmanager"
        "wheel" # sudo
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzI2b0Spyh5wIm6mLVPKaDonuea0a7sdNFGN2V1HTRq" # Master
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLpjzihuPI+t7xYjznPNLALMCunS2WKw/cqYRMAG1YILTGiLmdYRWck9Ic7muK7SXWj0XP8nWTze1iRhA/iTyxA=" # Termius CRISPR
      ];
    };
    defaultUserShell = pkgs.zsh;
  };

  nix.settings.trusted-users = ["root" "${username}"]; # Allow root and angel to use nix-command (required by devenv for cachix to work)

  # ---------------------------------------------------------------------------
  # SHELLS
  environment.shells = with pkgs; [bash zsh];
  programs.zsh.enable = true; # apparently we need this even if it's enabled in home-manager
  programs.zsh.enableGlobalCompInit = false; # This prevents compinit from running on /etc/zshrc, which noticeably slows down shell startup. Run compinit from user zshrc instead.
  environment.pathsToLink = ["/share/zsh"]; # (apparently) get zsh completions for system packages (eg. systemd)

  # ---------------------------------------------------------------------------
  services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)

  # ---------------------------------------------------------------------------
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    distrobox
    chromium
    ghostty
  ];
}
