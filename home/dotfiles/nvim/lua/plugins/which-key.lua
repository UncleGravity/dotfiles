return {
  -- TODO: organize keybindings better
  'folke/which-key.nvim',
  event = 'VeryLazy',
  -- opts_extend = { 'spec' },
  opts = {
    preset = "helix",
    defaults = {},
    spec = {
      {
        mode = { 'n', 'v' },
        -- { "<leader><tab>", group = "tabs" },
        -- { "<leader>c", group = "code" },
        -- { "<leader>f", group = "file/find" },
        { '<leader>a', group = '[a]i', icon = { icon = ' ', color = 'azure' } },
        { '<leader>d', group = '[d]ebug', icon = { icon = ' ', color = 'red' } },
        { '<leader>g', group = '[g]it', mode = { 'n', 'v' }, icon = { icon = ' ', color = 'orange' } },
        { '<leader>l', group = '[l]azy', icon = { icon = '󰒲 ', color = 'azure' } },
        { '<leader>q', group = '[q]uit', icon = { icon = ' ', color = 'green' } },
        { '<leader>s', group = '[s]earch', icon = { icon = ' ', color = 'azure' } },
        { '<leader>u', group = '[u]i', icon = { icon = '󰙵 ', color = 'cyan' } },
        { '<leader>x', group = 'diagnostics/quickfi[x]', icon = { icon = '󱖫 ', color = 'green' } },
        { '<leader>L', group = '[L]SP', icon = { icon = ' ', color = 'azure' } },
        { '<leader>m', group = '[m]arkdown', icon = { icon = ' ', color = 'azure' } },
        { '[', group = 'prev' },
        { ']', group = 'next' },
        { 'g', group = 'goto' },
        { 'z', group = 'fold' },
        {
          '<leader>b',
          group = '[b]uffer',
          icon = { icon = '󰓩 ', color = 'orange' },
          expand = function()
            return require('which-key.extras').expand.buf()
          end,
        },
        -- {
        --   '<leader>w',
        --   group = 'windows',
        --   proxy = '<c-w>',
        --   expand = function()
        --     return require('which-key.extras').expand.win()
        --   end,
        -- },
        -- better descriptions
        { 'gx', desc = 'Open with system app' },

        ----------------
        -- Custom

        -- Neotree
        -- { '<leader>e', ':lua Snacks.explorer()<CR>', desc = '[e]xplorer', icon = { icon = '󰙅 ', color = 'orange' } },

        -- Lazy
        { '<leader>l', '<cmd>Lazy<cr>', desc = 'Open Lazy', icon = { icon = '󰒲 ', color = 'azure' } },

        -- Yazi
        { '<leader>y', '<cmd>Yazi<cr>', desc = 'Yazi', icon = { icon = '󰇥 ', color = 'azure' } },
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
