{...}: {
  # --------------------------------------------------------------------------
  #  Environment variables
  #  located at either:
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #  /etc/profiles/per-user/angel/etc/profile.d/hm-session-vars.sh
  # --------------------------------------------------------------------------
  home.sessionVariables = {
    # NVIM_APPNAME = "nvim-lua";
    EDITOR = "nvim";
    # EDITOR = "hx";
    TEST = "HELLO";
  };
}
