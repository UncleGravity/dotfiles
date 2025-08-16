{
  config,
  pkgs,
  username,
  ...
}: {
  # --------------------------------------------------------------------------
  #  Framework basics
  # --------------------------------------------------------------------------
  xdg.enable = true; # Follow the XDG Base-Dir spec (XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME)
  programs.home-manager.enable = true; # Let Home Manager install and manage itself.

  # accounts.calendar.basePath = "${config.home.homeDirectory}/.calendar";
  # accounts.contact.basePath = "${config.home.homeDirectory}/.contacts";
  # --------------------------------------------------------------------------
  #  My custom sub-modules
  # --------------------------------------------------------------------------
  my = {
    zsh.enable = true;
    tmux.enable = true;
    dotfiles.enable = true;
  };

  # --------------------------------------------------------------------------
  #  Home section
  # --------------------------------------------------------------------------
  home = {
    inherit username;
    inherit (config.my.home) packages; # Single source of truth for user-space packages
    homeDirectory =
      if pkgs.stdenv.isDarwin
      then "/Users/${username}"
      else "/home/${username}";
  };

  # --------------------------------------------------------------------------
  #  Environment variables
  #  located at either:
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #  /etc/profiles/per-user/angel/etc/profile.d/hm-session-vars.sh
  # --------------------------------------------------------------------------
  home.sessionVariables = {
    # NVIM_APPNAME = "nvim-lua";
    # EDITOR = "nvim";
    EDITOR = "hx";
    DELTA_PAGER = "less -RFX --mouse"; # Fix "delta" issue where mouse scroll doesn't work in tmux
    TEST = "HELLO";
  };
}
