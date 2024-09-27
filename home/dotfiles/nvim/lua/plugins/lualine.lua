return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local lazy_status = require 'lazy.status' -- to configure lazy pending updates count

    -- configure lualine with modified theme
    require('lualine').setup {
      extensions = { 'lazy' },
      options = {
        theme = 'gruvbox-material',
        globalstatus = true,
        ignore_focus = { 'neo-tree' },
      },
      sections = {
        lualine_a = {
          { 'mode' },
          --------------

          ----------------
        },
        lualine_b = {
          { 'branch' },
          { 'diff' },
          { 'diagnostics' },
          -- {
          --   'buffers',
          --   -- show_filename_only = false, -- Shows shortened relative path when set to false.
          --   -- use_mode_colors = true,
          --   symbols = {
          --     modified = ' ●', -- Text to show when the buffer is modified
          --     alternate_file = '', -- Text to show to identify the alternate file
          --     directory = '', -- Text to show when the buffer is a directory
          --   },
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
          -- { 'fileformat' },
          { 'filetype' },
        },
      },
      -- Add tabline configuration
      -- tabline = {
      --   lualine_a = {
      --     {
      --       'buffers',
      --       show_filename_only = true, -- Shows full path
      --       mode = 2, -- Show buffer number
      --       max_length = vim.o.columns, -- Maximum width of buffers component
      --       -- use_mode_colors = true,
      --       symbols = {
      --         modified = ' ●',
      --         alternate_file = '',
      --         directory = '',
      --       },
      --     },
      --   },
      -- },
    }
  end,
}
