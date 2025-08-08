require('scrollview').setup {
    excluded_filetypes = {
        'alpha',
        'TelescopePrompt',
        'ministarter',
        'dapui_scopes',
        'dapui_breakpoints',
        'dapui_stacks',
        'dapui_watches',
        'dap-repl',
        'dapui_console',
    },
    current_only = true,
    always_show = false,
    base = 'right',
    hover = false,
    -- column = 80,
    signs_on_startup = {
        -- 'all',
        'changelist',
        'conflicts',
        'cursor',
        'diagnostics',
        'folds',
        'latestchange',
        'loclist',
        'marks',
        'quickfix',
        'search',
        'spell',
        -- 'textwidth',
        'trail',
    },
    diagnostics_error_symbol = '󰅚 ',
    diagnostics_warn_symbol = ' ',
    diagnostics_severities = {
        vim.diagnostic.severity.ERROR,
        vim.diagnostic.severity.WARN,
    },
    scrollview_floating_windows = true,
}

-- require('scrollview.contrib.gitsigns').setup() -- Enable gitsigns on scrollbar

vim.keymap.set('n', '<Leader>us', '<Cmd>ScrollViewToggle<CR>', { desc = 'Toggle scroll view' })
