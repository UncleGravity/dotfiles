return {
  'folke/noice.nvim',
  -- enabled = false,
  event = 'VeryLazy',
  dependencies = {
    -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
    'MunifTanjim/nui.nvim',
    {
      'rcarriga/nvim-notify',
      keys = {
        {
          '<leader>un',
          function()
            require('notify').dismiss { silent = true, pending = true }
          end,
          desc = 'Dismiss All Notifications',
        },
      },
      opts = {
        -- If I don't add background_colour, nvim-notify complains
        background_colour = '#000000',
        stages = 'static',
        timeout = 3000,
        max_height = function()
          return math.floor(vim.o.lines * 0.75)
        end,
        max_width = function()
          return math.floor(vim.o.columns * 0.75)
        end,
        on_open = function(win)
          vim.api.nvim_win_set_config(win, { zindex = 100 })
        end,
      },
    },
    { 'smjonas/inc-rename.nvim' },
  },
  opts = {
    -- Show undo/redo messages in small notification
    routes = {
      {
        filter = {
          event = 'msg_show',
          any = {
            { find = '%d+L, %d+B' },
            { find = '; after #%d+' },
            { find = '; before #%d+' },
          },
        },
        view = 'mini',
      },
      -- Show "recording macro" message
      {
        view = 'notify',
        filter = { event = 'msg_showmode' },
      },
    },
    lsp = {

      -- CTRL-K behavior
      hover = {
        silent = true, -- Don't show a message if hover is not available
      },

      -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true, -- requires hrsh7th/nvim-cmp
      },
    },

    presets = {
      bottom_search = true, -- use a classic bottom cmdline for search
      command_palette = true, -- position the cmdline and popupmenu together
      long_message_to_split = true, -- long messages will be sent to a split
      inc_rename = true, -- enables an input dialog for inc-rename.nvim
      lsp_doc_border = true, -- add a border to hover docs and signature help
    },
  },

  keys = {
    { '<leader>sn', '', desc = '+noice' },
    {
      '<S-Enter>',
      function()
        require('noice').redirect(vim.fn.getcmdline())
      end,
      mode = 'c',
      desc = 'Redirect Cmdline',
    },
    {
      '<leader>snl',
      function()
        require('noice').cmd 'last'
      end,
      desc = 'Noice Last Message',
    },
    {
      '<leader>snh',
      function()
        require('noice').cmd 'history'
      end,
      desc = 'Noice History',
    },
    {
      '<leader>sna',
      function()
        require('noice').cmd 'all'
      end,
      desc = 'Noice All',
    },
    {
      '<leader>snd',
      function()
        require('noice').cmd 'dismiss'
      end,
      desc = 'Dismiss All',
    },
    {
      '<leader>snt',
      function()
        require('noice').cmd 'pick'
      end,
      desc = 'Noice Picker (Telescope/FzfLua)',
    },
    {
      '<c-f>',
      function()
        if not require('noice.lsp').scroll(4) then
          return '<c-f>'
        end
      end,
      silent = true,
      expr = true,
      desc = 'Scroll Forward',
      mode = { 'i', 'n', 's' },
    },
    {
      '<c-b>',
      function()
        if not require('noice.lsp').scroll(-4) then
          return '<c-b>'
        end
      end,
      silent = true,
      expr = true,
      desc = 'Scroll Backward',
      mode = { 'i', 'n', 's' },
    },
  },
  config = function(_, opts)
    -- HACK: noice shows messages from before it was enabled,
    -- but this is not ideal when Lazy is installing plugins,
    -- so clear the messages in this case.
    -- if vim.o.filetype == 'lazy' then
    --   vim.cmd [[messages clear]]
    -- end
    require('noice').setup(opts)
    vim.api.nvim_set_hl(0, 'NoiceCmdlinePopupBorder', { link = 'Normal' }) -- fix de background color border
    -- vim.api.nvim_set_hl(0, 'FloatBorder', { link = 'Normal' })
  end,
}
