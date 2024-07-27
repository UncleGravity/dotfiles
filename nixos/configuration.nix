# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, options, username, hostname, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./escape-hatch.nix
      ./hackrf.nix
    ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
  boot.loader.systemd-boot.configurationLimit = 5;  # Limit to 5 latest generations


  # ---------------------------------------------------------------------------
  # Networking
  networking.hostName = hostname; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  services.openssh.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;


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
  # X11
  services.xserver.enable = true;
   
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable xkb Options in TTY
  console.useXkbConfig = true;
  #console.keyMap = "us-intl";
  
  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "altgr-intl";
    #xkb.options = "";
    #xkb.model = "macbook79";
  };
    
  services.xserver.exportConfiguration = true;

  # ---------------------------------------------------------------------------
  # Enable CUPS to print documents.
  services.printing.enable = true;

  # ---------------------------------------------------------------------------
  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
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
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users =  {
    users.${username} = {
      isNormalUser = true;
      description = "Angel";
      extraGroups = [ "networkmanager" "wheel" ]; # plugdev is for hackrf
      packages = with pkgs; [];
    };
    defaultUserShell = pkgs.zsh;
  };

  # hardware.hackrf.enable = true; # doesn't work for some reason, maybe send pull request
  # https://github.com/NixOS/nixpkgs/blob/d1b9c95fdfe16e551737edc6e0b9646cfb9a6850/nixos/modules/hardware/hackrf.nix
  # users.groups = {
  #   plugdev = {}; # Required by hackrf
  # };
  # services.udev.extraRules = ''
  #   SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
  # '';

  nix.settings.trusted-users = [ "root" "${username}" ]; # Allow root and angel to use nix-command (required by devenv for cachix to work)

  # ---------------------------------------------------------------------------
  # SHELLS
  environment.shells = with pkgs; [bash zsh];
  programs.zsh.enable = true; # apparently we need this even if it's enabled in home-manager
  environment.pathsToLink = [ "/share/zsh" ]; # (apparently) get zsh completions for system packages (eg. systemd)

  # ---------------------------------------------------------------------------
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Enable parallels tools
  hardware.parallels.enable = true;
  
  # ---------------------------------------------------------------------------
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default. 
    wget
    git
    distrobox
    podman
    chromium
    kitty # Required for kitty to work
  ];
  
  # ---------------------------------------------------------------------------
  # PODMAN CONFIG
  
  # Enable common container config files in /etc/containers
  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  services.flatpak.enable = true; # enable flatpak (required by host-spawn / distrobox-host-exec)
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}

