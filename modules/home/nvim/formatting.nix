{
  pkgs,
  lib,
  ...
}: {
  programs.nixvim = {
    # Conform.nvim for formatting
    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          c = ["clang-format"];
          lua = ["stylua"];
          python = ["ruff_organize_imports" "ruff_format"];
          nix = ["alejandra"];
          bash = ["shfmt"];
          zig = ["zigfmt"];
          go = ["gofmt"];
          typescript = ["prettierd"];
          javascript = ["prettierd"];
          javascriptreact = ["prettierd"];
          typescriptreact = ["prettierd"];
          html = ["prettierd"];
          css = ["prettierd"];
          json = ["prettierd"];
          markdown = ["prettierd"];
          yaml = ["prettierd"];
          toml = ["taplo"];
        };
      };
    };

    # Keymap for formatting the buffer via Conform
    keymaps = [
      {
        mode = ["n" "v"];
        key = "<leader>f";
        action = "<cmd>lua require('conform').format({ async = false, timeout_ms = 1000, lsp_fallback = true })<CR>";
        options.desc = "[f]ormat buffer";
      }
    ];
  };
}
