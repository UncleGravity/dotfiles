return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  opts_extend = { 'spec' },
  opts = {
    -- defaults = {},
    spec = {
      {
        mode = { 'n', 'v' },
        -- { "<leader><tab>", group = "tabs" },
        -- { "<leader>c", group = "code" },
        -- { "<leader>f", group = "file/find" },
        { '<leader>a', group = '[a]i', icon = { icon = ' ', color = 'azure' } },
        { '<leader>g', group = '[g]it', mode = { 'n', 'v' }, icon = { icon = ' ', color = 'orange' } },
        { '<leader>l', group = '[l]azy', icon = { icon = '󰒲 ', color = 'azure' } },
        -- { '<leader>gh', group = '[h]unks', mode = { 'n', 'v' }, icon = { icon = ' ', color = 'red' } },
        { '<leader>q', group = '[q]uit', icon = { icon = ' ', color = 'green' } },
        { '<leader>s', group = '[s]earch', icon = { icon = ' ', color = 'azure' } },
        { '<leader>w', group = '[w]orkspace' },
        { '<leader>t', group = '[t]oggle' },
        { '<leader>u', group = '[u]i', icon = { icon = '󰙵 ', color = 'cyan' } },
        { '<leader>x', group = 'diagnostics/quickfix', icon = { icon = '󱖫 ', color = 'green' } },
        { '[', group = 'prev' },
        { ']', group = 'next' },
        { 'g', group = 'goto' },
        { 'gs', group = 'surround' },
        { 'z', group = 'fold' },
        {
          '<leader>b',
          group = '[b]uffer',
          expand = function()
            return require('which-key.extras').expand.buf()
          end,
        },
        {
          '<leader>w',
          group = 'windows',
          proxy = '<c-w>',
          expand = function()
            return require('which-key.extras').expand.win()
          end,
        },
        -- better descriptions
        { 'gx', desc = 'Open with system app' },

        ----------------
        -- Custom

        -- Neotree
        { mode = 'n', '<leader>e', ':Neotree reveal toggle<CR>', desc = '[e]xplorer', icon = { icon = '󰙅 ', color = 'orange' } },

        -- Lazy
        { mode = 'n', '<leader>ll', '<cmd>Lazy<cr>', desc = 'Open Lazy', icon = { icon = '󰒲 ', color = 'azure' } },

        -- Yazi
        { mode = 'n', '<leader>y', '<cmd>Yazi<cr>', desc = 'Yazi', icon = { icon = '󰇥 ', color = 'azure' } },
      },
    },
  },
  keys = {
    {
      '<leader>?',
      function()
        require('which-key').show { global = false }
      end,
      desc = 'Buffer Keymaps (which-key)',
    },
    {
      '<c-w><space>',
      function()
        require('which-key').show { keys = '<c-w>', loop = true }
      end,
      desc = 'Window Hydra Mode (which-key)',
    },
  },
}
