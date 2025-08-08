-- LSP Config Reference
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md

----------------------------------------------------------------------------------------------------
--- Keymaps
vim.keymap.set('n', '<leader>lf', vim.lsp.buf.format, { desc = "Format buffer" })

----------------------------------------------------------------------------------------------------
--- Manual Configurations live in config/lsp folder
----------------------------------------------------------------------------------------------------
--- Enable
vim.lsp.enable({
    "nixd",
    "zls",
    "lua_ls"
})

----------------------------------------------------------------------------------------------------
