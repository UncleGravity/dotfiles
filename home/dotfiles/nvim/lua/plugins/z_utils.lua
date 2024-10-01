return {
  -------------------------------------------------------------------------------------------------
  -- Adds borders around ui popups
  {
    'stevearc/dressing.nvim',
    opts = {},
  },

  -------------------------------------------------------------------------------------------------
  -- Theme switcher
  {
    'andrew-george/telescope-themes',
    lazy = true,
    config = function()
      require('telescope').load_extension 'themes'
    end,
  },

  -------------------------------------------------------------------------------------------------
  -- Highlight TODO, BUG, etc in comment. Like this:  NOTE:
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  -------------------------------------------------------------------------------------------------
  -- Seamless navigation between TMUX & NVIM
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
    },
    keys = {
      { '<c-h>', '<cmd><C-U>TmuxNavigateLeft<cr>' },
      { '<c-j>', '<cmd><C-U>TmuxNavigateDown<cr>' },
      { '<c-k>', '<cmd><C-U>TmuxNavigateUp<cr>' },
      { '<c-l>', '<cmd><C-U>TmuxNavigateRight<cr>' },
      { '<c-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>' },
    },
  },

  -------------------------------------------------------------------------------------------------
  -- Show open buffers in top bar
  {
    'echasnovski/mini.tabline',
    version = false,
    -- enabled = false,
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('mini.tabline').setup()
    end,
  },

  -------------------------------------------------------------------------------------------------
  -- Closing a buffer won't close it's window
  {
    'echasnovski/mini.bufremove',
    version = false,
    event = 'VeryLazy',
    config = function()
      require('mini.bufremove').setup()
      vim.keymap.set('n', '<leader>bd', function()
        require('mini.bufremove').delete(0)
      end, { desc = 'Delete Buffer (mini.bufremove)' })
    end,
  },

  -- Plenary keybindings for profiling: just for troubleshooting
  -- {
  --   'nvim-lua/plenary.nvim',
  --   keys = {
  --     {
  --       '<leader>ps',
  --       function()
  --         require'plenary.profile'.start("profile.log", { flame = true })
  --       end,
  --       desc = 'Start profiling',
  --     },
  --     {
  --       '<leader>pe',
  --       function()
  --         require'plenary.profile'.stop()
  --       end,
  --       desc = 'Stop profiling',
  --     },
  --   },
  -- },
}
