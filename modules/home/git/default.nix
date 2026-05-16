{...}: {
  imports = [
    ./delta.nix
  ];

  programs.git = {
    enable = true;
    lfs.enable = true; # Large File Storage support
    settings = {
      user.name = "UncleGravity";
      user.email = "viera.tech@gmail.com";

      init.defaultBranch = "main";
      color.ui = "auto";

      # Pager
      core.pager = "delta --paging=never";
      interactive.diffFilter = "delta --color-only --features=interactive";
      delta.side-by-side = true;
      delta."interactive".keep-plus-minus-markers = false;

      # Interactive diff tool
      diff.tool = "nvim";
      difftool.nvim.cmd = "nvim -d $LOCAL $REMOTE";

      # Submodules
      submodule.recurse = true; # automatically handle submodules in operations
      status.submoduleSummary = true; # Show submodule changes in status

      push = {
        default = "simple";
        autoSetupRemote = true; # Auto-create upstream branch on push
        recurseSubmodules = "on-demand"; # Handle submodules on push
      };

      pull.rebase = true;

      # Rerere - remember how you resolved merge conflicts
      rerere.enabled = true;

      # Rebase improvements
      rebase = {
        autoStash = true; # stash changes before rebase
        autoSquash = true; # squash fixup! commits
      };

      # Better merge conflict display showing original, yours, and theirs
      merge.conflictStyle = "zdiff3";
    };
  };
}
