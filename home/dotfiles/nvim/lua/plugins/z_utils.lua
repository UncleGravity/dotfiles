return {

  -------------------------------------------------------------------------------------------------
  -- Adds borders around ui popups
  -- { 'stevearc/dressing.nvim', opts = {} },

  -------------------------------------------------------------------------------------------------
  -- Highlight TODO, BUG, etc in comment. Like this:  NOTE:
  {
    'folke/todo-comments.nvim',
    event = 'BufReadPre',
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

  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>qS", function() require("persistence").select() end,desc = "Select Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
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
