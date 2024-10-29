return {
  -- TODO: organize keybindings better
  'folke/which-key.nvim',
  event = 'VeryLazy',
  -- opts_extend = { 'spec' },
  opts = {
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
        { '<leader>e', ':Neotree reveal toggle<CR>', desc = '[e]xplorer', icon = { icon = '󰙅 ', color = 'orange' } },

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

-- return {
--   'echasnovski/mini.clue',
--   version = false,
--   config = function()
--     local miniclue = require 'mini.clue'
--     miniclue.setup {
--       triggers = {
--         -- Leader triggers
--         { mode = 'n', keys = '<Leader>' },
--         { mode = 'v', keys = '<Leader>' },
--         { mode = 'n', keys = '<space>' },
--         { mode = 'v', keys = '<space>' },
--
--         -- Built-in completion
--         { mode = 'i', keys = '<C-x>' },
--
--         -- `g` key
--         { mode = 'n', keys = 'g' },
--         { mode = 'v', keys = 'g' },
--
--         -- Marks
--         { mode = 'n', keys = "'" },
--         { mode = 'v', keys = "'" },
--         { mode = 'n', keys = '`' },
--         { mode = 'v', keys = '`' },
--
--         -- Registers
--         { mode = 'n', keys = '"' },
--         { mode = 'v', keys = '"' },
--         { mode = 'i', keys = '<C-r>' },
--         { mode = 'c', keys = '<C-r>' },
--
--         -- Window commands
--         { mode = 'n', keys = '<C-w>' },
--
--         -- `z` key
--         { mode = 'n', keys = 'z' },
--         { mode = 'v', keys = 'z' },
--
--         -- Brackets
--         { mode = 'n', keys = '[' },
--         { mode = 'n', keys = ']' },
--       },
--       clues = {
--         -- Enhance this by adding descriptions for <Leader> mapping groups
--         miniclue.gen_clues.builtin_completion(),
--         miniclue.gen_clues.g(),
--         miniclue.gen_clues.marks(),
--         miniclue.gen_clues.registers(),
--         miniclue.gen_clues.windows(),
--         miniclue.gen_clues.z(),
--
--         -- Leader groups
--         { mode = 'n', keys = '<Leader>a', desc = '[a]i' },
--         { mode = 'v', keys = '<Leader>a', desc = '[a]i' },
--         { mode = 'n', keys = '<Leader>g', desc = '[g]it' },
--         { mode = 'v', keys = '<Leader>g', desc = '[g]it' },
--         { mode = 'n', keys = '<Leader>l', desc = '[l]azy' },
--         { mode = 'v', keys = '<Leader>l', desc = '[l]azy' },
--         { mode = 'n', keys = '<Leader>q', desc = '[q]uit' },
--         { mode = 'v', keys = '<Leader>q', desc = '[q]uit' },
--         { mode = 'n', keys = '<Leader>s', desc = '[s]earch' },
--         { mode = 'v', keys = '<Leader>s', desc = '[s]earch' },
--         { mode = 'n', keys = '<Leader>w', desc = '[w]orkspace' },
--         { mode = 'v', keys = '<Leader>w', desc = '[w]orkspace' },
--         { mode = 'n', keys = '<Leader>t', desc = '[t]oggle' },
--         { mode = 'v', keys = '<Leader>t', desc = '[t]oggle' },
--         { mode = 'n', keys = '<Leader>u', desc = '[u]i' },
--         { mode = 'v', keys = '<Leader>u', desc = '[u]i' },
--         { mode = 'n', keys = '<Leader>x', desc = 'diagnostics/quickfi[x]' },
--         { mode = 'v', keys = '<Leader>x', desc = 'diagnostics/quickfi[x]' },
--         { mode = 'n', keys = '<Leader>L', desc = '[L]SP' },
--         { mode = 'v', keys = '<Leader>L', desc = '[L]SP' },
--         { mode = 'n', keys = '<Leader>b', desc = '[b]uffer' },
--         { mode = 'v', keys = '<Leader>b', desc = '[b]uffer' },
--
--         -- Other groups
--         { mode = 'n', keys = 'gs', desc = 'surround' },
--         { mode = 'v', keys = 'gs', desc = 'surround' },
--         { mode = 'n', keys = '[', desc = 'prev' },
--         { mode = 'n', keys = ']', desc = 'next' },
--
--         -- Specific keybindings
--         { mode = 'n', keys = 'gx', desc = 'Open with system app' },
--         { mode = 'n', keys = '<Leader>e', desc = '[e]xplorer (Neotree)', postkeys = ':Neotree reveal toggle<CR>' },
--         { mode = 'n', keys = '<Leader>ll', desc = 'Open Lazy', postkeys = '<cmd>Lazy<cr>' },
--         { mode = 'n', keys = '<Leader>y', desc = 'Yazi', postkeys = '<cmd>Yazi<cr>' },
--       },
--       window = {
--         delay = 150,
--         config = {
--           width = 'auto',
--         },
--       },
--     }
--   end,
-- }
