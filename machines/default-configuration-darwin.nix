# This file defines the common configuration shared across different machines.
{ pkgs, lib, inputs, username, hostname, ... }: {

  # imports = [
  #   ./homebrew.nix
  # ];

  #############################################################
  #  Host & User config
  #############################################################
  networking.hostName = hostname;
  networking.localHostName = hostname;
  networking.computerName = hostname;
  # system.defaults.smb.NetBIOSName = lib.mkDefault hostname; # Often derived from hostname

  users.users."${username}" = {
    home = "/Users/${username}";
    description = username;
  };

  nix.settings.trusted-users = [ username ];

  #############################################################
  #  Packages
  #############################################################
  environment.systemPackages = lib.mkDefault (with pkgs; [
    wget
    vim
    git
  ]);

  #############################################################
  #  Nix
  #############################################################
  nix.settings.experimental-features = lib.mkDefault "nix-command flakes";
  nixpkgs.config.allowUnfree = lib.mkDefault true;

  # Garbage collection everything older than 30 days
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 30d";
  };

  # https://github.com/NixOS/nix/issues/7273#issuecomment-2295429401
  nix.optimise.automatic = lib.mkDefault true;

  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
  nix.settings.auto-optimise-store = lib.mkDefault false;

  system.configurationRevision = lib.mkDefault (inputs.self.rev or inputs.self.dirtyRev or null);
  system.stateVersion = lib.mkDefault 4; # Set once per machine and keep stable.

  # Set NIX_PATH
  # environment.etc."nix/inputs/nixpkgs".source = "${inputs.nixpkgs}";
  # nix.nixPath = lib.mkForce [ ... ]; # Use mkForce if you absolutely need this path structure

  # nixpkgs.hostPlatform = "x86_64-darwin"; # Usually detected automatically

  ###################################################################################
  #  macOS's System configuration
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #  Extra options are documented here:
  #    https://macos-defaults.com/
  ###################################################################################
  system = {
    # Activate settings without logout/login
    activationScripts.postUserActivation.text = lib.mkDefault ''
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    keyboard = {
      enableKeyMapping = lib.mkDefault true; # allow changing key maps
      remapCapsLockToControl = lib.mkDefault true; # save fingers
    };

    defaults = {
      NSGlobalDomain = {
        # Sets how long you must hold down the key before it starts repeating.
        InitialKeyRepeat = lib.mkDefault 15; # minimum is 15 (225 ms), maximum is 120 (1800 ms)
        # Sets how fast it repeats once it starts.
        KeyRepeat = lib.mkDefault 2; # minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = lib.mkDefault false; 
        NSAutomaticDashSubstitutionEnabled = lib.mkDefault false; 
        NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
        NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;
        NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
        ApplePressAndHoldEnabled = lib.mkDefault false;
      };

      dock = {
        autohide = lib.mkDefault true;
        autohide-time-modifier = lib.mkDefault 0.2; # open/close animation time
        autohide-delay = lib.mkDefault 0.0;
        show-recents = lib.mkDefault false;
        mru-spaces = lib.mkDefault false; # don't automatically rearrange spaces based on most recent use.
        mineffect = lib.mkDefault "scale"; # animation effect for minimizing windows
        scroll-to-open = lib.mkDefault true; # scroll up on a Dock icon to show all opened windows for an app
      };

      menuExtraClock = {
        ShowAMPM = lib.mkDefault true;
        ShowDate = lib.mkDefault 0; # 0:When space allows, 1:Always, 2:Never
        ShowDayOfMonth = lib.mkDefault true;
        ShowDayOfWeek = lib.mkDefault true;
        ShowSeconds = lib.mkDefault true;
      };

      finder = {
        # _FXShowPosixPathInTitle = true;
        ShowPathbar = lib.mkDefault true; # Breadcrumbs
        AppleShowAllExtensions = lib.mkDefault true;
        AppleShowAllFiles = lib.mkDefault false; # Don't show hidden files
        FXDefaultSearchScope = lib.mkDefault "SCcf"; # Search the current folder by default
        FXPreferredViewStyle = lib.mkDefault "Nlsv"; # List view
        ShowExternalHardDrivesOnDesktop = lib.mkDefault false;
        ShowHardDrivesOnDesktop = lib.mkDefault false;
        ShowRemovableMediaOnDesktop = lib.mkDefault false;
      };
      CustomUserPreferences = lib.mkDefault {
        "NSGlobalDomain" = {
          "NSToolbarTitleViewRolloverDelay" = 0.0;
        };
        "com.apple.ActivityMonitor".UpdatePeriod = 2; # Example: Moved here
      };

      loginwindow = {
        GuestEnabled = lib.mkDefault false;
        # SHOWFULLNAME = lib.mkDefault true;  # show full name in login window
      };

      ActivityMonitor.IconType = lib.mkDefault 6; # CPU usage plot
      LaunchServices.LSQuarantine = lib.mkDefault false; # Disable "This app is from the internet" quarantine message
    }; # ----------------- Defaults end
  }; # ----------------- System end

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = lib.mkDefault true;
  security.pam.services.sudo_local.reattach = lib.mkDefault true; # TMUX fix https://github.com/LnL7/nix-darwin/pull/787

  # Karabiner-Elements
  # TODO: Broken for now, install with homebrew instead.
  # https://github.com/nix-darwin/nix-darwin/issues/1041
  # services.karabiner-elements.enable = lib.mkDefault true;

  #############################################################
  #  Zsh 
  #############################################################
  programs.zsh = {

    # Create /etc/zshrc that loads the nix-darwin environment.
    # this is required if you want to use darwin's default shell - zsh (instead of bash)
    enable = lib.mkDefault true;

    # IMPORTANT - This prevents compinit from running on /etc/zshrc, 
    # which noticeably slows down shell startup. Run compinit from user zshrc instead.
    # This is (I think) mostly necessary because I am using a custom zshrc file instead of letting nix manage it.
    enableGlobalCompInit = lib.mkDefault false;
  };

  environment.shells = lib.mkDefault [ pkgs.zsh ]; # Use nix managed zsh (probably more frequently updated

}