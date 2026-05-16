{
  config,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # SHELLS
  environment = {
    shells = with pkgs; [bash zsh];
    pathsToLink = ["/share/zsh"]; # (apparently) get zsh completions for system packages (eg. systemd)
    systemPackages = config.my.common.systemPackages;
  };

  programs.zsh = {
    enable = true; # apparently we need this even if it's enabled in home-manager
    enableGlobalCompInit = false; # Remove compinit from /etc/zshrc, since it SLOWS down shell startup. Run compinit from user zshrc instead. (home-manager)
  };
}
