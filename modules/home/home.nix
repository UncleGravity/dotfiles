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
}
