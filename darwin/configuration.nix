{ pkgs, lib, inputs, username, hostname, ... }: {

  imports = [
    # ./kanata.nix
    ./homebrew.nix
  ];

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
  environment.systemPackages = with pkgs; [ 
    wget
    vim 
    git 
    ];

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
      enableKeyMapping = true; # enable key mapping
      remapCapsLockToControl = true; # save fingers
    };

    defaults = {

      NSGlobalDomain = {
        # Sets how long you must hold down the key before it starts repeating.
        InitialKeyRepeat = 15; # minimum is 15 (225 ms), maximum is 120 (1800 ms)
        # Sets how fast it repeats once it starts.
        KeyRepeat = 2; # minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false; # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false; # disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false; # disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false; # disable auto spelling correction

        # Disable "Press and Hold" system-wide
        ApplePressAndHoldEnabled = false;
      };

      # Dock
      dock = {
        autohide = true; # hide dock when not in use
        autohide-time-modifier = 0.2; # opening/closing animation times.
        autohide-delay = 0.0; # delay before showing/hiding dock.
        show-recents = false; # don't show recent applications in dock
        mru-spaces = false; # don't automatically rearrange spaces based on most recent use.
        mineffect = "scale"; # animation effect for minimizing windows
      };
      CustomUserPreferences."com.apple.dock" = {
        # not added to nix-darwin yet
        scroll-to-open = true; # scroll up on a Dock icon to show all opened windows for an app
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
        # _FXShowPosixPathInTitle = true;
        ShowPathbar = true; # Breadcrumbs
        AppleShowAllExtensions = true; # Show all file extensions
        AppleShowAllFiles = true; # Show hidden files
        FXDefaultSearchScope = "SCcf"; # Search the current folder by default
        FXPreferredViewStyle = "Nlsv"; # List view
      };
      CustomUserPreferences = {
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
        };
        "NSGlobalDomain" = {
          "NSToolbarTitleViewRolloverDelay" = 0.0;
        };
      };

      # Login Window
      loginwindow = {
        GuestEnabled = false; # Disable guest account
        # SHOWFULLNAME = true;  # show full name in login window
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
  #https://github.com/LnL7/nix-darwin/pull/787
  environment.etc."pam.d/sudo_local".text = ''
    # Managed by Nix Darwin
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
    auth       sufficient     pam_tid.so
  '';

  #############################################################
  #  Zsh
  #############################################################

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;

  # IMPORTANT - This prevents compinit from running on /etc/zshrc, 
  # which noticeably slows down shell startup. Run compinit from user zshrc instead.
  programs.zsh.enableGlobalCompInit = false;
  environment.shells = [ pkgs.zsh ]; # Use nix managed zsh (probably more frequently updated
}