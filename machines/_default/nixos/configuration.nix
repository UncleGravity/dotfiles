{lib, hostname, username, pkgs, ...}:
{
  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
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
  boot.loader.systemd-boot.configurationLimit = 5;  # Limit to 5 latest generations

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

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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
  services.xserver.enable = lib.mkDefault true;
  services.xserver.autorun = lib.mkDefault true;
   
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = lib.mkDefault true;
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
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users =  {
    users.${username} = {
      isNormalUser = true;
      description = "me";
      extraGroups = [ 
        "networkmanager" 
        "wheel" # sudo
        ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzI2b0Spyh5wIm6mLVPKaDonuea0a7sdNFGN2V1HTRq" # PUBLIC ssh key
      ];
    };
    defaultUserShell = pkgs.zsh;
  };

  nix.settings.trusted-users = [ "root" "${username}" ]; # Allow root and angel to use nix-command (required by devenv for cachix to work)

  # ---------------------------------------------------------------------------
  # SHELLS
  environment.shells = with pkgs; [bash zsh];
  programs.zsh.enable = true; # apparently we need this even if it's enabled in home-manager
  programs.zsh.enableGlobalCompInit = false; # This prevents compinit from running on /etc/zshrc, which noticeably slows down shell startup. Run compinit from user zshrc instead.
  environment.pathsToLink = [ "/share/zsh" ]; # (apparently) get zsh completions for system packages (eg. systemd)

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