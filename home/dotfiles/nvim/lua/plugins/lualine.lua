return {
  'nvim-lualine/lualine.nvim',
  -- enabled = false,
  event = 'VeryLazy',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local lazy_status = require 'lazy.status' -- to configure lazy pending updates count

    -- configure lualine with modified theme
    require('lualine').setup {
      extensions = { 'lazy' },
      options = {
        -- theme = 'gruvbox-material',
        theme = 'auto',
        globalstatus = true,
        ignore_focus = { 'neo-tree' },
      },
      sections = {
        lualine_a = {
          { 'mode' },
        },
        lualine_b = {
          { 'branch' },
          { 'diff' },
          { 'diagnostics' },
          -- {
          --   require('noice').api.statusline.mode.get,
          --   cond = require('noice').api.statusline.mode.has,
          --   color = { fg = '#ff9e64' },
          -- },
        },
        lualine_c = {
          { 'filename', path = 3 },
        },
        lualine_x = {
          {
            lazy_status.updates,
            cond = lazy_status.has_updates,
            color = { fg = '#ff9e64' },
          },
          { 'encoding' },
          { 'filetype' },
        },
      },
    }
  end,
}
