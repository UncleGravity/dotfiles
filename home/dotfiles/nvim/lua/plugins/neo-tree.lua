return {
  'nvim-neo-tree/neo-tree.nvim',
  -- enabled = false,
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  -- cmd = 'Neotree',

  -- keys = {
  --   { '<leader>e', ':Neotree toggle<CR>', { icon = '󰙅', desc = 'Toggle NeoTree' } },
  -- },

  opts = {
    -- position = 'float',
    sources = {
      'filesystem',
      'document_symbols',
      -- 'buffers',
      -- 'git_status',
    },
    open_files_do_not_replace_types = { 'terminal', 'Trouble', 'trouble', 'qf', 'Outline' },
    filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
    -- close_if_last_window = true,
    window = {
      mappings = {
        ['<leader>e'] = { 'close_window', desc = 'Close NeoTree' },
        ['l'] = 'open',
        ['h'] = 'close_node',
        ['<space>'] = 'none',
        ['Y'] = {
          function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.setreg('+', path, 'c')
          end,
          desc = 'Copy Path to Clipboard',
        },
        ['O'] = {
          function(state)
            require('lazy.util').open(state.tree:get_node().path, { system = true })
          end,
          desc = 'Open with System Application',
        },
        ['P'] = { 'toggle_preview', config = { use_float = true } },
      },
    },
    default_component_configs = {
      indent = {
        with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
        expander_collapsed = '',
        expander_expanded = '',
        expander_highlight = 'NeoTreeExpander',
      },
      git_status = {
        symbols = {
          unstaged = '󰄱',
          staged = '󰱒',
        },
      },
    },
  },
}