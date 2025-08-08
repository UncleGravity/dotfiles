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
