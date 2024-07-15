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
  nix.package = pkgs.nix;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set NIX_PATH (WHY ISN'T THIS WORKING)
  nix.nixPath = [
    "darwin-config=$HOME/.nixpkgs/darwin-configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"

    # Had to add this so nixd would work
    # Error: file 'nixpkgs' was not found in the Nix search path
    "nixpkgs=${pkgs.path}"
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

    defaults = {
      menuExtraClock = {
        ShowAMPM = true;
        ShowDate = 0; # 0:When space allows, 1:Always, 2:Never
        ShowDayOfMonth = true;
        ShowDayOfWeek = true;
        ShowSeconds = true;
      };

      # other macOS's defaults configuration.
      # ......
    };
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ]; # Use nix managed zsh (probably more frequently updated)
}
