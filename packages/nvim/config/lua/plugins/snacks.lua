----------------------------------------------------------------------------------------------------
--- Snacks.nvim
require('snacks').setup({
    -- Feature toggles -------------------------------------------------------
    bigfile = { enabled = true },   -- Handle large files gracefully
    bufdelete = { enabled = true }, -- Delete buffers without closing windows
    explorer = {
        enabled = true,
        replace_netrw = true, -- Replace default netrw explorer
    },
    -- indent = { enabled = true },
    picker = { enabled = true },
    quickfile = { enabled = true },
    statuscolumn = {
      enabled = true,
      folds = {
        open = true, -- show open fold icons
        -- git_hl = false, -- use Git Signs hl for fold icons
      },
    },
})

----------------------------------------------------------------------------------------------------
--- Keymaps
local map = vim.keymap.set

-- Explorer -------------------------------------------------------------
map('n', '<leader>e', '<cmd>lua Snacks.explorer()<CR>', { desc = 'Toggle Explorer' })

-- Buffer delete --------------------------------------------------------
map('n', '<leader>bd', '<cmd>lua Snacks.bufdelete()<CR>', { desc = 'Delete Buffer' })
map('n', '<leader>bD', '<cmd>lua Snacks.bufdelete.all()<CR>', { desc = 'Delete All Buffers' })
map('n', '<leader>bo', '<cmd>lua Snacks.bufdelete.other()<CR>', { desc = 'Delete Other Buffers' })

-- Picker --------------------------------------------------------------
map('n', '<leader><space>', '<cmd>lua Snacks.picker.smart()<CR>', { desc = 'Smart Find Files' })
map('n', '<leader>/', '<cmd>lua Snacks.picker.grep()<CR>', { desc = 'Grep' })
map('n', '<leader>s"', '<cmd>lua Snacks.picker.registers()<CR>', { desc = 'Registers' })
map('n', '<leader>sm', '<cmd>lua Snacks.picker.marks()<CR>', { desc = 'Marks' })
map('n', '<leader>s/', '<cmd>lua Snacks.picker.search_history()<CR>', { desc = 'Search History' })
map('n', '<leader>s?', '<cmd>lua Snacks.picker.commands()<CR>', { desc = 'Commands' })
map('n', '<leader>sd', '<cmd>lua Snacks.picker.diagnostics()<CR>', { desc = 'Diagnostics' })
map('n', '<leader>sh', '<cmd>lua Snacks.picker.help()<CR>', { desc = 'Help Pages' })
map('n', '<leader>sj', '<cmd>lua Snacks.picker.jumps()<CR>', { desc = 'Jumps' })
map('n', '<leader>sk', '<cmd>lua Snacks.picker.keymaps()<CR>', { desc = 'Keymaps' })
map('n', '<leader>sr', '<cmd> lua Snacks.picker.recent()<CR>', { desc = "Recent" })
map('n', '<leader>s<space>', '<cmd>lua Snacks.picker()<CR>', { desc = 'Pickers' })

-- Git -----------------------------------------------------------------
map('n', '<leader>sgb', '<cmd>lua Snacks.picker.git_branches()<CR>', { desc = 'Git Branches' })
map('n', '<leader>sgl', '<cmd>lua Snacks.picker.git_log()<CR>', { desc = 'Git Log' })
map('n', '<leader>sgL', '<cmd>lua Snacks.picker.git_log_line()<CR>', { desc = 'Git Log Line' })
map('n', '<leader>sgs', '<cmd>lua Snacks.picker.git_status()<CR>', { desc = 'Git Status' })
map('n', '<leader>sgS', '<cmd>lua Snacks.picker.git_stash()<CR>', { desc = 'Git Stash' })
map('n', '<leader>sgd', '<cmd>lua Snacks.picker.git_diff()<CR>', { desc = 'Git Diff (Hunks)' })
map('n', '<leader>sgf', '<cmd>lua Snacks.picker.git_log_file()<CR>', { desc = 'Git Log File' })

-- Todo ----------------------------------------------------------------
map('n', '<leader>sT', '<cmd>lua Snacks.picker.todo_comments()<CR>', { desc = 'Todo Comments' })

-- LSP -----------------------------------------------------------------
map('n', 'gd', '<cmd>lua Snacks.picker.lsp_definitions()<CR>', { desc = 'Goto Definition' })
map('n', 'gD', '<cmd>lua Snacks.picker.lsp_declarations()<CR>', { desc = 'Goto Declaration' })
map('n', '<leader>lr', '<cmd>lua Snacks.picker.lsp_references()<CR>', { nowait = true, desc = 'References' })
map('n', '<leader>lI', '<cmd>lua Snacks.picker.lsp_implementations()<CR>', { desc = 'Goto Implementation' })
map('n', '<leader>lt', '<cmd>lua Snacks.picker.lsp_type_definitions()<CR>', { desc = 'Goto T[y]pe Definition' })
map('n', '<leader>ls', '<cmd>lua Snacks.picker.lsp_symbols()<CR>', { desc = 'Symbols' })
map('n', '<leader>lS', '<cmd>lua Snacks.picker.lsp_workspace_symbols()<CR>', { desc = 'Workspace Symbols' })
