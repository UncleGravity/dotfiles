require('nvim-treesitter.configs').setup({
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = '=',
            node_incremental = '=',
            scope_incremental = '+',
            node_decremental = '-',
        },
    },
})

-- [[ Configure Treesitter ]] See `:help nvim-treesitter`

-- Enable folding with treesitter
vim.wo.foldmethod = 'expr'
vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.wo.foldtext = "v:lua.require('extra.foldtext')()"
vim.wo.foldlevel = 99 -- Make sure nothing is folded on when opening a file
