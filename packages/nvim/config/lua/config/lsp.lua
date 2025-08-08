-- LSP Config Reference
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md

----------------------------------------------------------------------------------------------------
--- Keymaps
vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>lr", ":IncRename ", { desc = "Rename symbol" })

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
--- Diagnostics Configuration
vim.diagnostic.config {
    underline = false,
    update_in_insert = false,
    virtual_text = {
        spacing = 4,
        source = 'if_many',
        prefix = '●',
    },
    severity_sort = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.HINT] = ' ',
            [vim.diagnostic.severity.INFO] = ' ',
        },
    },
}

--- Misc
require('inc_rename').setup() -- Live preview while renaming symbol

----------------------------------------------------------------------------------------------------
