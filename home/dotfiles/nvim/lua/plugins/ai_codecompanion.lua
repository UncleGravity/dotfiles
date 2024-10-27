return { -- AI
  'olimorris/codecompanion.nvim',
  -- enabled = false,
  lazy = true,
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'hrsh7th/nvim-cmp', -- Optional: For using slash commands and variables in the chat buffer
    'nvim-telescope/telescope.nvim', -- Optional: For using slash commands
    { 'stevearc/dressing.nvim', opts = {} }, -- Optional: Improves the default Neovim UI
    -- { 'echasnovski/mini.diff', version = false, opts = {} },
  },
  config = function()
    require('codecompanion').setup {
      display = {
        chat = {
          window = {
            layout = "float",
          }
        }
        -- diff = {
        --   provider = 'mini_diff',
        -- },
      },
      strategies = {
        chat = {
          adapter = 'anthropic',
        },
        inline = {
          adapter = 'anthropic',
        },
        agent = {
          adapter = 'anthropic',
        },
      },
    }

    -- Add key mappings
    vim.api.nvim_set_keymap('n', '<C-a>', '<cmd>CodeCompanionActions<cr>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('v', '<C-a>', '<cmd>CodeCompanionActions<cr>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', '<LocalLeader>ac', '<cmd>CodeCompanionChat Toggle<cr>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('v', '<LocalLeader>ac', '<cmd>CodeCompanionChat Toggle<cr>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('v', 'ga', '<cmd>CodeCompanionChat Add<cr>', { noremap = true, silent = true })

    -- Expand 'cc' into 'CodeCompanion' in the command line
    vim.cmd [[cab cc CodeCompanion]]
  end,
}
