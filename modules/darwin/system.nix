{
  config,
  lib,
  inputs,
  username,
  ...
}: {
  ###################################################################################
  #  macOS's System configuration
  # nix-darwin options: https://daiderd.com/nix-darwin/manual/index.html#sec-options
  # extra options: https://macos-defaults.com/
  # Manually find options with: https://github.com/joshryandavis/defaults2nix
  # TODO: switch to -> https://github.com/SushyDev/nix-plist-manager
  ###################################################################################
  system = {
    primaryUser = username;
    # Also extraActivation, and preActivation
    activationScripts.postActivation.text = ''
      # Activate settings without logout/login
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      # Remove channel symlinks (they get recreated despite nix.channel.enable = false)
      rm -rf /Users/${username}/.nix-defexpr/channels
      rm -rf /Users/${username}/.nix-defexpr/channels_root
      rm -rf /Users/${username}/.nix-profile/*
      rmdir /Users/${username}/.nix-defexpr 2>/dev/null || true
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

      controlcenter = {
        NowPlaying = lib.mkDefault false; # 18 = Display icon in menu bar 24 = Hide icon in menu bar
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

      # For custom preferences, run "defaults read". Diff the output with the target option on/off
      CustomUserPreferences = lib.mkDefault {
        "NSGlobalDomain" = {
          "NSToolbarTitleViewRolloverDelay" = 0.0;
        };

        "com.apple.ActivityMonitor".UpdatePeriod = 2;

        # Avoid creating .DS_Store files on network or USB volumes
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
      };

      loginwindow = {
        GuestEnabled = lib.mkDefault false;
        # SHOWFULLNAME = lib.mkDefault true;  # show full name in login window
      };

      ActivityMonitor.IconType = lib.mkDefault 6; # CPU usage plot
      LaunchServices.LSQuarantine = lib.mkDefault false; # Disable "This app is from the internet" quarantine message
    }; # ----------------- Defaults end

    # Use the Git hash as nix generation revision
    configurationRevision = lib.mkDefault (inputs.self.rev or inputs.self.dirtyRev or null);
  }; # ----------------- System end
}
