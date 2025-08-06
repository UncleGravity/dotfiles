{pkgs, ...}:
# Create a stable symlink to neovim runtime for LSP integration
pkgs.runCommand "nvim-runtime" {} ''
  mkdir -p $out/share/nvim
  ln -sf ${pkgs.neovim}/share/nvim/runtime $out/share/nvim/runtime
''