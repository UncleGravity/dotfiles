return { -- Fancy vscode like scroll bar
  {
    'lewis6991/satellite.nvim',
    enabled = false,
    version = false,
    -- lazy = true,
    -- event = 'VeryLazy',
    config = function()
      require('satellite').setup {
        current_only = true,
        winblend = 0,
        zindex = 40,
        excluded_filetypes = {},
        width = 2,
        handlers = {
          cursor = {
            enable = true,
            -- Supports any number of symbols
            symbols = { '󰩷' },
            -- symbols = { '⎺', '⎻', '⎼', '⎽' },
            -- symbols = { '⎻', '⎼' }
            -- Highlights:
            -- - SatelliteCursor (default links to NonText
          },
          search = {
            enable = true,
            -- Highlights:
            -- - SatelliteSearch (default links to Search)
            -- - SatelliteSearchCurrent (default links to SearchCurrent)
          },
          diagnostic = {
            enable = true,
            signs = { '-', '=', '≡' },
            min_severity = vim.diagnostic.severity.HINT,
            -- Highlights:
            -- - SatelliteDiagnosticError (default links to DiagnosticError)
            -- - SatelliteDiagnosticWarn (default links to DiagnosticWarn)
            -- - SatelliteDiagnosticInfo (default links to DiagnosticInfo)
            -- - SatelliteDiagnosticHint (default links to DiagnosticHint)
          },
          gitsigns = {
            enable = true,
            signs = { -- can only be a single character (multibyte is okay)
              add = '│',
              change = '│',
              delete = '-',
            },
            -- Highlights:
            -- SatelliteGitSignsAdd (default links to GitSignsAdd)
            -- SatelliteGitSignsChange (default links to GitSignsChange)
            -- SatelliteGitSignsDelete (default links to GitSignsDelete)
          },
          marks = {
            enable = true,
            show_builtins = true, -- shows the builtin marks like [ ] < >
            key = 'm',
            -- Highlights:
            -- SatelliteMark (default links to Normal)
          },
          quickfix = {
            signs = { '-', '=', '≡' },
            -- Highlights:
            -- SatelliteQuickfix (default links to WarningMsg)
          },
        },
      }

      -- Set a more visible highlight for SatelliteCursor
      vim.api.nvim_set_hl(0, 'SatelliteCursor', { fg = '#FF0000', bold = true })
    end,
  },
  {
    'dstein64/nvim-scrollview',
    -- enabled = false,
    config = function()
      require('scrollview').setup {
        excluded_filetypes = { 'nerdtree', 'neo-tree', 'codecompanion', 'Avante', 'AvanteInput', 'trouble', 'lazygit', 'alpha', 'TelescopePrompt' },
        current_only = true,
        always_show = true,
        base = 'right',
        hover = false,
        -- column = 80,
        signs_on_startup = {
          -- 'all',
          'changelist',
          'conflicts',
          'cursor',
          'diagnostics',
          'folds',
          'latestchange',
          'loclist',
          'marks',
          'quickfix',
          'search',
          'spell',
          'textwidth',
          'trail',
        },
        -- diagnostics_error_symbol = '!',
        diagnostics_severities = { vim.diagnostic.severity.ERROR },
      }

      -- require('scrollview.contrib.gitsigns').setup() -- Enable gitsigns on scrollbar

      vim.keymap.set('n', '<Leader>us', '<Cmd>ScrollViewToggle<CR>', { desc = 'Toggle scroll view' })
    end,
  },
}
