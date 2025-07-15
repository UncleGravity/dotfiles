# This file defines the common configuration shared across different machines.
{
  pkgs,
  lib,
  inputs,
  username,
  hostname,
  ...
}: {
  # --------------------------------------------------------------------------
  # My Darwin Modules
  my = {
    homebrew.enable = true;
    apfs-snapshots.enable = true;
  };

  #############################################################
  #  Host & User config
  #############################################################
  networking = {
    hostName = hostname;
    localHostName = hostname;
    computerName = hostname;
    # system.defaults.smb.NetBIOSName = lib.mkDefault hostname; # Often derived from hostname
    wakeOnLan.enable = lib.mkDefault true;
  };

  users.users."${username}" = {
    home = "/Users/${username}";
    description = username;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzI2b0Spyh5wIm6mLVPKaDonuea0a7sdNFGN2V1HTRq" # Master
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLpjzihuPI+t7xYjznPNLALMCunS2WKw/cqYRMAG1YILTGiLmdYRWck9Ic7muK7SXWj0XP8nWTze1iRhA/iTyxA=" # CRISPR (termius)
    ];
  };

  #############################################################
  #  Packages
  #############################################################
  environment.systemPackages = with pkgs; [
    curl
    wget
    vim
    git
    cowsay
  ];

  #############################################################
  #  Nix
  #############################################################

  nix.channel.enable = false; # Flake gang
  nixpkgs.config.allowUnfree = true; # gomenasai :(

  nix.settings = {
    experimental-features = "nix-command flakes";

    # -------------------------------
    # Binary caches for faster builds
    substituters = [
      "https://nix-community.cachix.org?priority=41"
      "https://numtide.cachix.org?priority=42"
      "https://unclegravity-nix.cachix.org?priority=43"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI="
    ];
    always-allow-substitutes = true;
    # -------------------------------
    trusted-users = [username];
  };

  # ---------------------------------------------------------------------------
  # Garbage collect EVERYTHING older than 30 days
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      interval = {
        Weekday = 0;
        Hour = 0;
      }; # Every Sunday at midnight
      extraArgs = "--keep 5 --keep-since 30d"; # Remove older than 30d, keep at least 5
    };
  };

  # -------------------------------
  # Bug
  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
  nix.settings.auto-optimise-store = lib.mkDefault false;
  # https://github.com/NixOS/nix/issues/7273#issuecomment-2295429401
  nix.optimise.automatic = lib.mkDefault true;
  # -------------------------------

  # Use the Git hash as nix generation revision
  system.configurationRevision = lib.mkDefault (inputs.self.rev or inputs.self.dirtyRev or null);

  ###################################################################################
  #  macOS's System configuration
  # nix-darwin options: https://daiderd.com/nix-darwin/manual/index.html#sec-options
  # extra options: https://macos-defaults.com/
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
      rm -f /Users/${username}/.nix-profile
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
  }; # ----------------- System end

  # Enable TouchID for sudo authentication
  security.pam.services.sudo_local = {
    enable = lib.mkDefault true;
    touchIdAuth = lib.mkDefault true;
    reattach = lib.mkDefault true; # TMUX fix https://github.com/LnL7/nix-darwin/pull/787
  };

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
    # environment.pathsToLink = [ "/share/zsh" ];
  };

  environment.shells = lib.mkDefault [pkgs.zsh]; # Use nix managed zsh (probably more frequently updated

  #############################################################
  #  Tailscale
  #############################################################
  # services.tailscale.enable = true;
}
