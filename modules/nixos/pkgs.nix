{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    curl
    wget
    vim
    git
    ghostty.terminfo
  ];
}
