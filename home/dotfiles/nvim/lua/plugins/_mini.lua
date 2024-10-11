-- TODO: Move to mini.nvim, instead of individual plugins?
return {
  -------------------------------------------------------------------------------------------------
  -- Sensible defaults
  {
    'echasnovski/mini.basics',
    version = false,

    opts = {
      {
        options = {
          -- Basic options ('number', 'ignorecase', and many more)
          basic = true,
          -- Extra UI features ('winblend', 'cmdheight=0', ...)
          extra_ui = true,
          -- Presets for window borders ('single', 'double', ...)
          -- win_borders = 'double',
        },

        mappings = {
          -- Basic mappings (better 'jk', save with Ctrl+S, ...)
          basic = true,
          -- Prefix for mappings that toggle common options ('wrap', 'spell', ...).
          -- Supply empty string to not create these mappings.
          option_toggle_prefix = [[\]],
        },

        autocommands = {
          -- Basic autocommands (highlight on yank, start Insert in terminal, ...)
          basic = true,
        },

        -- Whether to disable showing non-error feedback
        silent = false,
      },
    },
  },

  -------------------------------------------------------------------------------------------------
  -- Show open buffers in top bar
  {
    'echasnovski/mini.tabline',
    version = false,
    -- enabled = false,
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('mini.tabline').setup {
        tabpage_section = 'right',
      }
    end,
  },

  -------------------------------------------------------------------------------------------------
  -- Closing a buffer won't close it's window
  {
    'echasnovski/mini.bufremove',
    version = false,
    event = 'VeryLazy',
    config = function()
      require('mini.bufremove').setup()
      vim.keymap.set('n', '<leader>bd', function()
        require('mini.bufremove').delete(0)
      end, { desc = 'Delete Buffer (mini.bufremove)' })
    end,
  },

  -------------------------------------------------------------------------------------------------
  -- Drag selections around, with Alt+<direction>
  -- Overwrites keybindings for alt+j/k in ../config/keymaps.lua
  { 'echasnovski/mini.move', event = 'VeryLazy', version = false, opts = {} },

  -------------------------------------------------------------------------------------------------
  -- Autopairs `'"({[]})"'`
  { 'echasnovski/mini.pairs', event = 'VeryLazy', version = false, opts = {} },

  -------------------------------------------------------------------------------------------------
  -- Split/Join function arguments
  {
    'echasnovski/mini.splitjoin',
    event = 'VeryLazy',
    version = false,
    opts = { mappings = { toggle = 'gj' } },
  },

  -------------------------------------------------------------------------------------------------
  -- Highlight other instances of the word under cursor
  -- {
  --   'echasnovski/mini.cursorword',
  --   version = false,
  --   config = function()
  --     require('mini.cursorword').setup()
  --     vim.api.nvim_set_hl(0, 'MiniCursorwordCurrent', {})
  --   end,
  -- },

  -------------------------------------------------------------------------------------------------
  -- Better bracket navigation (vim-unimpaired replacement)
  {
    'echasnovski/mini.bracketed',
    version = false,
    event = 'VeryLazy',
    opts = {
      buffer = { suffix = 'b', options = {} },
      comment = { suffix = 'c', options = {} },
      conflict = { suffix = 'x', options = {} },
      diagnostic = { suffix = 'd', options = {} },
      file = { suffix = '', options = {} }, -- bloat
      indent = { suffix = 'i', options = {} },
      jump = { suffix = 'j', options = {} },
      location = { suffix = 'l', options = {} },
      oldfile = { suffix = 'o', options = {} },
      quickfix = { suffix = 'q', options = {} },
      treesitter = { suffix = 't', options = {} },
      undo = { suffix = '', options = {} }, -- weird
      window = { suffix = 'w', options = {} },
      yank = { suffix = '', options = {} }, -- bloat
    },
  },

  -------------------------------------------------------------------------------------------------
  -- Better a/i textobjects
  {
    'echasnovski/mini.ai',

    version = false,
    dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
    config = function()
      local ai = require 'mini.ai'
      ai.setup {
        n_lines = 500,
        custom_textobjects = {
          a = ai.gen_spec.treesitter { -- argument / parameter
            a = { '@parameter.outer' },
            i = { '@parameter.inner' },
          },

          b = ai.gen_spec.treesitter { -- block
            a = { '@block.outer' },
            i = { '@block.inner' },
          },

          ['c'] = ai.gen_spec.treesitter {
            a = '@comment.outer',
            i = '@comment.inner',
          }, -- comment

          f = ai.gen_spec.treesitter { -- function
            a = { '@call.outer' },
            i = { '@call.inner' },
          },

          -- Whole buffer
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line '$',
              col = math.max(vim.fn.getline('$'):len(), 1),
            }
            return { from = from, to = to }
          end,
        },
      }
    end,
  },

  -------------------------------------------------------------------------------------------------
  -- Mini.surround
  {
    'echasnovski/mini.surround',
    opts = {
      mappngs = {
        add = 'sa',
        delete = 'sd',
        find = 'sf',
        find_left = 'sF',
        highlight = 'sh',
        replace = 'sr',
        update_n_lines = 'sn',
      },
    },
  },

  -------------------------------------------------------------------------------------------------
  -- Show indent lines

  {
    'echasnovski/mini.indentscope',
    -- version = false,
    config = function()
      require('mini.indentscope').setup {
        draw = {
          delay = 0,
          animation = require('mini.indentscope').gen_animation.none(),
        },
        symbol = '│',
        options = { try_as_border = true },
      }
    end,
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        pattern = {
          'alpha',
          'dashboard',
          'fzf',
          'help',
          'lazy',
          'lazyterm',
          'mason',
          'neo-tree',
          'notify',
          'toggleterm',
          'Trouble',
          'trouble',
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },
}
