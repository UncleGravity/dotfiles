return { -- Autoformat
  'stevearc/conform.nvim',
  -- enabled = false,
  config = function()
    local conform = require 'conform'

    conform.setup {
      notify_on_error = true,
      formatters_by_ft = {
        -- List of formatters here:
        -- https://github.com/stevearc/conform.nvim?tab=readme-ov-file#formatters
        lua = { 'stylua' },
        python = { 'ruff_organize_imports', 'ruff_format' }, -- Using ruff through LSP
        nix = { 'alejandra' },
        bash = { 'shfmt' },

        typescript = { 'prettierd' },
        javascript = { 'prettierd' },
        javascriptreact = { 'prettierd' },
        typescriptreact = { 'prettierd' },
        html = { 'prettierd' },
        css = { 'prettierd' },
        json = { 'prettierd' },
        markdown = { 'prettierd' },
        yaml = { 'prettierd' },
        toml = { 'taplo' },
      },
    }

    vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
      require('conform').format {
        async = false,
        timeout_ms = 1000,
        lsp_fallback = true,
      }
    end, { desc = '[f]ormat buffer' })
  end,
}
