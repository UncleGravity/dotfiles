{pkgs, ...}: {
  wrappers.git = {
    basePackage = pkgs.git;
    env.GIT_CONFIG_GLOBAL.value = ./config;
    pathAdd = [
      # Core git functionality
      pkgs.delta # Better diff viewer (configured in git config)
      pkgs.openssh # SSH for remote repositories
      pkgs.coreutils # Essential utilities (cp, mv, etc.) used by git

      # Additional git utilities
      pkgs.git-lfs # Large File Storage support
    ];
  };
}
