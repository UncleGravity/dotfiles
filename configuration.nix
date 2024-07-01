# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # inputs.home-manager.nixosModules.default
    ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  services.openssh.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups.plugdev = {}; # Required by hackrf
  users.users.angel = {
    isNormalUser = true;
    description = "Angel";
    extraGroups = [ "networkmanager" "wheel" "plugdev" ];
    packages = with pkgs; [
    #  cowsay
    #  thunderbird
    ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      "angel" = import ./home.nix;
    };
  };
 
  # environment.shells = with pkgs; [bash zsh];
  environment.pathsToLink = [ "/share/zsh" ]; # get zsh completions for system packages (eg. systemd)
  programs.zsh.enable = true; # apparently we need this even if it's enabled in home-manager
  users.defaultUserShell = pkgs.zsh;

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Enable parallels tools
  hardware.parallels.enable = true;

  # -----------------------------------------------------
  # Nix escape hatches
  # -----------------------------------------------------
  # Why? Because I tried to run a make file that required bash and NixOS doesn't have /bin/bash
  # So to avoid having to patch the make file, I just symlinked bash to /bin/bash
  # sudo ln -s /run/current-system/sw/bin/bash /bin/bash
  # But apparently there's a whole solution for this:
  services.envfs.enable = true; # Dynamically populates contents of /bin and /usr/bin/ so that it contains all executables from the PATH of the requesting process (eg. /bin/bash)

  # Run unpatched binaries
  # Why? Because vscode-server doesn't work without it.
  programs.nix-ld.enable = true; # Needed for vscode-server
  programs.nix-ld.package = pkgs.nix-ld-rs; # Latest version of nix-ld
  # programs.nix-ld.libraries = with pkgs; [
  #     # -- Default Values from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/nix-ld.nix
  #     zlib
  #     zstd
  #     stdenv.cc.cc
  #     curl
  #     openssl
  #     attr
  #     libssh
  #     bzip2
  #     libxml2
  #     acl
  #     libsodium
  #     util-linux
  #     xz
  #     systemd
  #     # -- End Default Values
  #   ];
  # -----------------------------------------------------

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default. 
    wget
    distrobox
    podman
    chromium
  ];

  
  # PODMAN CONFIG
    environment.etc."containers/policy.json".text = ''
      {
        "default": [
          {
            "type": "insecureAcceptAnything"
          }
        ],
        "transports": {
          "docker-daemon": {
            "": [{"type":"insecureAcceptAnything"}]
          }
        }
      }
    '';
  
  # HACKRF CONFIG
  #services.udev.packages = [ pkgs.hackrf ];
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", GROUP="plugdev", MODE="0666"
  '';

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

