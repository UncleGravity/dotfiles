{ pkgs, lib, inputs, username, hostname, ... }: {

  #############################################################
  #  Host & User config
  #############################################################
  # networking.hostName = hostname;
  # networking.computerName = hostname;
  # system.defaults.smb.NetBIOSName = hostname;

  users.users."${username}" = {
    home = "/Users/${username}";
    description = username;
  };

  nix.settings.trusted-users = [ username ];
  
  #############################################################
  #  Yabai
  #############################################################
  # services.yabai.enable = true;

  #############################################################
  #  Packages
  #############################################################
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [ vim git ];

  #############################################################
  #  Homebrew
  #############################################################
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # 'zap': uninstalls all formulae(and related files) not listed here.
      # cleanup = "zap";
    };

    taps = [
      "homebrew/services"
    ];

    # `brew install`
    # TODO Feel free to add your favorite apps here.
    brews = [
      # "aria2"  # download tool
    ];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
    casks = [
      # "google-chrome"
    ];
  };

  #############################################################
  #  Nix
  #############################################################
  nix.settings.experimental-features = "nix-command flakes"; # Enable flakes
  services.nix-daemon.enable = true; # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix; # idk
  nix.registry.nixpkgs.flake = inputs.nixpkgs; # make `nix run nixpkgs#nixpkgs` use the same nixpkgs as the one used by this flake.

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set NIX_PATH 
  # Based on this: https://nixos-and-flakes.thiscute.world/best-practices/nix-path-and-flake-registry
  # environment.etc."nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";
  nix.nixPath = lib.mkForce [
    { darwin-config = "$HOME/.nixpkgs/darwin-configuration.nix"; }
    # { nixpkgs = "/etc/nix/inputs/nixpkgs"; }
    { nixpkgs = "${inputs.nixpkgs}"; }
    # "/nix/var/nix/profiles/per-user/root/channels" # We probably don't need this anymore.
  ];

  # do garbage collection monthly
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 30d";
  };

  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
  nix.settings.auto-optimise-store = false;

  # Set Git commit hash for darwin-version. (I don't know what this is for)
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on. (don't know what this is for)
  # nixpkgs.hostPlatform = "x86_64-darwin";

  ###################################################################################
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  ###################################################################################

  system = {
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    keyboard = {
      enableKeyMapping = true;  # enable key mapping
      remapCapsLockToControl = true; # save fingers
    };

    defaults = {

      NSGlobalDomain = {
        # Sets how long you must hold down the key before it starts repeating.
        InitialKeyRepeat = 15;  # minimum is 15 (225 ms), maximum is 120 (1800 ms)
        # Sets how fast it repeats once it starts.
        KeyRepeat = 3;  # minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false;  # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false;  # disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false;  # disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false;  # disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false;  # disable auto spelling correction
      };

      # Top Menu bar
      menuExtraClock = {
        ShowAMPM = true;
        ShowDate = 0; # 0:When space allows, 1:Always, 2:Never
        ShowDayOfMonth = true;
        ShowDayOfWeek = true;
        ShowSeconds = true;
      };

      # Finder
      finder = {
        ShowPathbar = true; # Breadcrumbs
        AppleShowAllExtensions = true; # Show all file extensions
        AppleShowAllFiles = true; # Show hidden files
        FXDefaultSearchScope = "SCcf"; # Search the current folder by default
        FXPreferredViewStyle = "Nlsv"; # List view
      };
      CustomUserPreferences."com.apple.finder" = {
        ShowExternalHardDrivesOnDesktop = false;
        ShowHardDrivesOnDesktop = false;
      };

      # Login Window
      loginwindow = {
        GuestEnabled = false; # Disable guest account
        SHOWFULLNAME = true;  # show full name in login window
      };

      # Misc
      ActivityMonitor.IconType = 6; # CPU usage plot
      LaunchServices.LSQuarantine = false; # Disable "This app is from the internet" quarantine message

      # ----------------- Defaults end
    };

    # ----------------- System end
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # ^ Won't work on TMUX unless we add this
  environment.etc."pam.d/sudo_local".text = ''
    # Managed by Nix Darwin
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
    auth       sufficient     pam_tid.so
  '';

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ]; # Use nix managed zsh (probably more frequently updated)
}
