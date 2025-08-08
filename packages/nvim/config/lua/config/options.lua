-- NOTE: Most basic options defined using mini.basics.
-- They can be optionally overriden here.

-- vim.cmd 'let g:netrw_liststyle = 3' -- treeview for :Explore
-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.have_nerd_font = true
vim.g.disable_autoformat = true
vim.opt.scrolloff = 10 -- Minimal number of screen lines to keep above and below the cursor.

-- tabs & indentation
vim.opt.tabstop = 2      -- 2 spaces for tabs (prettier default)
vim.opt.softtabstop = 2  -- Number of spaces that a <Tab> counts for while performing editing operations
vim.opt.shiftwidth = 2   -- Number of spaces to use for each step of (auto)indent
vim.opt.expandtab = true -- Use spaces instead of tabs

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

vim.opt.updatetime = 1000              -- Decrease update time
vim.opt.backspace = 'indent,eol,start' -- allow backspace on indent, end of line or insert mode start position

-- clipboard
vim.opt.clipboard = 'unnamedplus' -- Sync with system clipboard

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'` and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

vim.opt.swapfile = false       -- turn off swapfile
vim.opt.colorcolumn = '100'    -- Show max line length indicator
vim.opt.confirm = true         -- Confirm to save changes before exiting modified buffer
vim.opt.grepprg = 'rg --vimgrep'
vim.opt.inccommand = 'nosplit' -- preview incremental substitute
vim.opt.statusline = vim.opt.statusline + '%F'

-- Default border for all floating windows
vim.opt.winborder = 'rounded'

-- Make floating windows opaque (fixes LSP hover transparency)
-- vim.opt.winblend = 0

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Preview substitutions
vim.opt.inccommand = 'split'
