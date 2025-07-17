{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    chromium # Web browser
    ghostty # arigatogosaimasu hashimoto san
  ];
}
