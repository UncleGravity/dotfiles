{pkgs, ...}: let
  cfg = ./config;
  nvimWith = pkgs.neovim.override {
    configure = {
      customLuaRC = builtins.readFile ./config/init.lua;
      packages = {
        all.start = [
          # UI
          pkgs.vimPlugins.kanagawa-nvim
          pkgs.vimPlugins.fidget-nvim
          pkgs.vimPlugins.lualine-nvim
          pkgs.vimPlugins.noice-nvim
          pkgs.vimPlugins.todo-comments-nvim

          # Navigation
          pkgs.vimPlugins.vim-tmux-navigator
          pkgs.vimPlugins.flash-nvim
          pkgs.vimPlugins.nvim-scrollview

          # Bundles
          pkgs.vimPlugins.mini-nvim
          pkgs.vimPlugins.snacks-nvim

          # LSP
          pkgs.vimPlugins.nvim-treesitter.withAllGrammars
          pkgs.vimPlugins.nvim-lspconfig
          pkgs.vimPlugins.blink-cmp

          pkgs.vimPlugins.gitsigns-nvim
          pkgs.vimPlugins.which-key-nvim
          pkgs.vimPlugins.fzf-lua
        ];
      };
    };
  };
  runtimeTools = [
    pkgs.ripgrep
    pkgs.fd
    pkgs.nodejs
  ];
in
  pkgs.symlinkJoin {
    name = "nvim-clean";
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      makeWrapper ${nvimWith}/bin/nvim $out/bin/nvim-clean \
          --set-default NVIM_APPNAME nvim-clean \
          --add-flags "--cmd 'set runtimepath^=${cfg}'" \
          --prefix PATH : ${pkgs.lib.makeBinPath runtimeTools}

      # nvim-blank: only sets NVIM_APPNAME and passes no other flags
      makeWrapper ${pkgs.neovim}/bin/nvim $out/bin/nvim-blank \
          --set-default NVIM_APPNAME nvim-blank
    '';
    paths = [];
  }
