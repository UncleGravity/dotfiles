--   [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
--
--  Keymaps from mini.basics:
--  |Keys   |     Modes       |                  Description                  |
--  |-------|-----------------|-----------------------------------------------|
--  | j     | Normal, Visual  | Move down by visible lines with no [count]    |
--  | k     | Normal, Visual  | Move up by visible lines with no [count]      |
--  | go    | Normal          | Add [count] empty lines after cursor          |
--  | gO    | Normal          | Add [count] empty lines before cursor         |
--  | gy    | Normal, Visual  | Copy to system clipboard                      |
--  | gp    | Normal, Visual  | Paste from system clipboard                   |
--  | gV    | Normal          | Visually select latest changed or yanked text |
--  | g/    | Visual          | Search inside current visual selection        |
--  | *     | Visual          | Search forward for current visual selection   |
--  | #     | Visual          | Search backward for current visual selection  |
--  | <C-s> | Normal, Visual, | Save and go to Normal mode                    |
--  |       |     Insert      |                                               |

-- Set <space> as the leader key
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Duplicate line(s) (just use yyp and dot to repeat)
vim.keymap.set('n', '<A-S-j>', 'yyp', { desc = 'Duplicate line down' })
vim.keymap.set('n', '<A-S-k>', 'yyP', { desc = 'Duplicate line up' })

-- buffers
vim.keymap.set('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Delete Buffer' })
vim.keymap.set('n', '<leader>bD', '<cmd>:bd<cr>', { desc = 'Delete Buffer and Window' })

-- quickfix
vim.keymap.set('n', ']q', '<cmd>cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', '<cmd>cprevious<CR>', { desc = 'Previous quickfix item' })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set({ 'i', 'n' }, '<esc>', '<cmd>noh<cr><esc>', { desc = 'Escape and Clear hlsearch' })

-- Exit terminal mode in the builtin terminal
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- quit
vim.keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit' })
vim.keymap.set('n', '<leader>qw', '<cmd>wqa<cr>', { desc = 'Save and Quit' })

-- -- Highlight word under cursor without moving
-- vim.keymap.set('n', '*', '*N', { desc = 'Highlight word under cursor' })
