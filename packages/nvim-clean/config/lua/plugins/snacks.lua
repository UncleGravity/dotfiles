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
    statuscolumn = { enabled = true },
})

----------------------------------------------------------------------------------------------------
--- Keymaps
-- Explorer -------------------------------------------------------------
vim.keymap.set('n', '<leader>e', '<cmd>lua Snacks.explorer()<CR>', { desc = 'Toggle Explorer' })

-- Buffer delete --------------------------------------------------------
vim.keymap.set('n', '<leader>bd', '<cmd>lua Snacks.bufdelete()<CR>', { desc = 'Delete Buffer' })
vim.keymap.set('n', '<leader>bD', '<cmd>lua Snacks.bufdelete.all()<CR>', { desc = 'Delete All Buffers' })
vim.keymap.set('n', '<leader>bo', '<cmd>lua Snacks.bufdelete.other()<CR>', { desc = 'Delete Other Buffers' })

-- Picker --------------------------------------------------------------
vim.keymap.set('n', '<leader><space>', '<cmd>lua Snacks.picker.smart()<CR>', { desc = 'Smart Find Files' })
vim.keymap.set('n', '<leader>/', '<cmd>lua Snacks.picker.grep()<CR>', { desc = 'Grep' })
vim.keymap.set('n', '<leader>s"', '<cmd>lua Snacks.picker.registers()<CR>', { desc = 'Registers' })
vim.keymap.set('n', '<leader>sm', '<cmd>lua Snacks.picker.marks()<CR>', { desc = 'Marks' })
vim.keymap.set('n', '<leader>s/', '<cmd>lua Snacks.picker.search_history()<CR>', { desc = 'Search History' })
vim.keymap.set('n', '<leader>s?', '<cmd>lua Snacks.picker.commands()<CR>', { desc = 'Commands' })
vim.keymap.set('n', '<leader>sd', '<cmd>lua Snacks.picker.diagnostics()<CR>', { desc = 'Diagnostics' })
vim.keymap.set('n', '<leader>sh', '<cmd>lua Snacks.picker.help()<CR>', { desc = 'Help Pages' })
vim.keymap.set('n', '<leader>sj', '<cmd>lua Snacks.picker.jumps()<CR>', { desc = 'Jumps' })
vim.keymap.set('n', '<leader>sk', '<cmd>lua Snacks.picker.keymaps()<CR>', { desc = 'Keymaps' })
vim.keymap.set('n', '<leader>sr', '<cmd> lua Snacks.picker.recent()<CR>', { desc = "Recent" })
vim.keymap.set('n', '<leader>s<space>', '<cmd>lua Snacks.picker()<CR>', { desc = 'Pickers' })

-- Git -----------------------------------------------------------------
vim.keymap.set('n', '<leader>sgb', '<cmd>lua Snacks.picker.git_branches()<CR>', { desc = 'Git Branches' })
vim.keymap.set('n', '<leader>sgl', '<cmd>lua Snacks.picker.git_log()<CR>', { desc = 'Git Log' })
vim.keymap.set('n', '<leader>sgL', '<cmd>lua Snacks.picker.git_log_line()<CR>', { desc = 'Git Log Line' })
vim.keymap.set('n', '<leader>sgs', '<cmd>lua Snacks.picker.git_status()<CR>', { desc = 'Git Status' })
vim.keymap.set('n', '<leader>sgS', '<cmd>lua Snacks.picker.git_stash()<CR>', { desc = 'Git Stash' })
vim.keymap.set('n', '<leader>sgd', '<cmd>lua Snacks.picker.git_diff()<CR>', { desc = 'Git Diff (Hunks)' })
vim.keymap.set('n', '<leader>sgf', '<cmd>lua Snacks.picker.git_log_file()<CR>', { desc = 'Git Log File' })

-- Todo ----------------------------------------------------------------
vim.keymap.set('n', '<leader>sT', '<cmd>lua Snacks.picker.todo_comments()<CR>', { desc = 'Todo Comments' })
