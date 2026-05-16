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
    DELTA_PAGER = "less -RFX --mouse"; # Fix "delta" issue where mouse scroll doesn't work in tmux
    TEST = "HELLO";
  };
}
