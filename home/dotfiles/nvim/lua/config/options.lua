-- vim.cmd 'let g:netrw_liststyle = 3' -- treeview for :Explore
-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- vim.opt.number = true
-- vim.opt.relativenumber = true
-- vim.opt.signcolumn = 'yes' -- show sign column so that text doesn't shift
-- vim.opt.cursorline = true -- Show which line the cursor is on
-- vim.opt.fillchars = { eob = ' ' } -- remove tilde symbol
-- vim.opt.cmdheight = 1
vim.g.disable_autoformat = true

-- hide empty buffer
-- vim.opt.hidden = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- tabs & indentation
vim.opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
vim.opt.softtabstop = 2 -- Number of spaces that a <Tab> counts for while performing editing operations
vim.opt.shiftwidth = 2 -- Number of spaces to use for each step of (auto)indent
vim.opt.expandtab = true -- Use spaces instead of tabs
-- vim.opt.smartindent = true -- Insert indents automatically

-- Enable mouse mode and mouse move events
-- vim.opt.mouse = 'a'
-- vim.opt.mousemoveevent = true -- could cause performance issues?
-- Don't show the mode, since it's already in the status line
-- vim.opt.showmode = false

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- search settings
-- vim.opt.ignorecase = true -- ignore case when searching
-- vim.opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive
-- vim.opt.inccommand = 'split' -- Preview substitutions live, as you type!

-- vim.opt.undofile = true -- Save undo history
vim.opt.updatetime = 1000 -- Decrease update time
-- vim.opt.termguicolors = true -- turn on termguicolors for some colorschemes to work
-- vim.opt.background = 'dark' -- colorschemes that can be light or dark will be made dark
vim.opt.backspace = 'indent,eol,start' -- allow backspace on indent, end of line or insert mode start position

-- clipboard
-- only set clipboard if not in ssh, to make sure the OSC 52
-- integration works automatically. Requires Neovim >= 0.10.0
vim.opt.clipboard = vim.env.SSH_TTY and '' or 'unnamedplus' -- Sync with system clipboard

-- split windows
-- vim.opt.splitright = true -- split vertical window to the right
-- vim.opt.splitbelow = true -- split horizontal window to the bottom

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { lead = '·', tab = '» ', trail = '·', nbsp = '␣' }

vim.opt.swapfile = false -- turn off swapfile
vim.opt.colorcolumn = '100' -- Show max line length indicator
vim.opt.confirm = true -- Confirm to save changes before exiting modified buffer
vim.opt.grepprg = 'rg --vimgrep'
vim.opt.inccommand = 'nosplit' -- preview incremental substitute
vim.opt.statusline = vim.opt.statusline + '%F'
-- vim.opt.wrap = false
