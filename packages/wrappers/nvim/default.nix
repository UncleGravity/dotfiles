{pkgs, ...}: {
  # Create a wrapped version of neovim that uses our custom config
  wrappers.nvim = {
    basePackage = pkgs.neovim;
    prependFlags = [
      # Use our custom init.lua file
      "-u"
      "${./config/init.lua}"
      # Set the runtime path to include our config directory
      "--cmd"
      "set runtimepath^=${./config}"
    ];
    pathAdd = [
      # Essential tools for the nvim config
      pkgs.ripgrep
      pkgs.fd
      pkgs.git

      # LSP servers
      pkgs.lua-language-server
      pkgs.vscode-langservers-extracted # html, css, json, eslint
      pkgs.typescript-language-server
      pkgs.tailwindcss-language-server
      pkgs.emmet-language-server
      pkgs.pyright
      pkgs.clang-tools
      pkgs.nixd
      pkgs.zls
      pkgs.gopls
      pkgs.rust-analyzer
      pkgs.bash-language-server
      pkgs.taplo # toml
      pkgs.marksman # markdown
      pkgs.markdown-oxide # alternative markdown LSP

      # Formatters
      pkgs.stylua
      pkgs.alejandra # nix formatter
      pkgs.prettierd
      pkgs.shfmt
      pkgs.ruff # python

      # Debug adapters
      pkgs.lldb # for lldb-dap
      pkgs.nodejs # for js-debug
    ];
  };
}
