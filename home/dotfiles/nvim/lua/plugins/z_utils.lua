return {
  -- Adds borders around ui popups
  {
    'stevearc/dressing.nvim',
    opts = {},
  },

  -- Theme switcher
  {
    'andrew-george/telescope-themes',
    config = function()
      require('telescope').load_extension 'themes'
    end,
  },

  -- NOTE: Highlight todo, notes, etc in comment
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

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

  -- Show open buffers on top bar
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

  -- Closing a buffer won't close it's window
  {
    'echasnovski/mini.bufremove',
    version = false,
    config = function()
      require('mini.bufremove').setup()
      vim.keymap.set('n', '<leader>bd', function() require('mini.bufremove').delete(0) end, { desc = 'Delete Buffer (mini.bufremove)' })
    end,
  },
}
