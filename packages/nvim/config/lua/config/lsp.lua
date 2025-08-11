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
    "nixd",                  -- Nix | nixpkgs: nixd
    "lua_ls",                -- Lua | nixpkgs: lua-language-server
    "html",                  -- HTML | nixpkgs: vscode-langservers-extracted
    "cssls",                 -- CSS | nixpkgs: vscode-langservers-extracted
    "emmet_language_server", -- Emmet | nixpkgs: emmet-language-server
    "ts_ls",                 -- JS/TS | nixpkgs: typescript-language-server <-- choose one
    -- "tsgo", -- JS/TS | nixpkgs: typescript-go <-- choose one
    "tailwindcss",           -- Tailwind | nixpkgs: tailwindcss-language-server
    "pyright",               -- python | nixpkgs: pyright <-- choose one
    -- "ty", -- python | nixpkgs: ty <-- choose one
    "clangd",                -- C | nixpkgs: clang-tools
    "gopls",                 -- Go | nixpkgs: gopls
    "rust_analyzer",         -- Rust | nixpkgs: rust-analyzer
    "bashls",                -- Bash | nixpkgs: bash-language-server
    "taplo",                 -- TOML | -- nixpkgs: taplo
    "zls",                   -- Zig | nixpkgs: zls
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
