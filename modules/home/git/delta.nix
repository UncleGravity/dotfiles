{...}: {
  # Better diff viewer
  # (enableGitIntegration would clobber our custom `core.pager` / `diffFilter` args).
  programs.delta = {
    enable = true;
    enableGitIntegration = false;
  };

  home.sessionVariables = {
    DELTA_PAGER = "less -RFX --mouse"; # Fix "delta" issue where mouse scroll doesn't work in tmux
  };
}
