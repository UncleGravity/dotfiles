return { -- Fuzzy Finder (files, lsp, etc)
  ---------------------------------------------
  -- Telescope General Config
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    version = false,
    -- branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      --  View all telescope searchable tags:
      --  :Telescope help_tags
      --
      -- Shoe Telescope keybindings:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?

      require('telescope').setup {
        defaults = {
          -- initial_mode = 'normal',
        },
        pickers = {
          find_files = {
            -- find_command = { 'fd', '--type=f', '--hidden', '--exclude', '.git' },
            -- Reason: Show most recently modified files first
            find_command = { 'rg', '--files', '--sortr=modified', '--hidden', '--glob', '!.git/' },
          },
          buffers = {
            show_all_buffers = true,
            sort_lastused = true,
            theme = 'dropdown',
            mappings = {
              i = {
                ['<c-d>'] = require('telescope.actions').delete_buffer,
              },
              n = {
                ['d'] = require('telescope.actions').delete_buffer,
              },
            },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]elect Telescope' })
      -- vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[D]iagnostics' })
      -- vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = 'Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[B]uffers' })
      vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = 'Search Files' })
      -- vim.keymap.set('n', '<leader>,', builtin.buffers, { desc = 'Search Buffers' })
      vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = '[/] Fuzzy search current buffer' })
      vim.keymap.set('n', '<leader>sm', builtin.marks, { desc = '[S]earch [M]arks' })
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sN', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[N]eovim files' })
    end,
  },

  ---------------------------------------------
  -- Extension: Undo
  {
    'debugloop/telescope-undo.nvim',
    dependencies = { -- note how they're inverted to above example
      {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
      },
    },
    keys = {
      { -- lazy style key map
        '<leader>su',
        '<cmd>lll histors<cr>',
        desc = '[u]ndo history',
      },
    },
    opts = {
      -- don't use `defaults = { }` here, do this in the main telescope spec
      extensions = {
        undo = {
          side_by_side = true,
          layout_strategy = 'vertical',
          layout_config = {
            preview_height = 0.8,
          },
        },
      },
    },
    config = function(_, opts)
      -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
      -- configs for us. We won't use data, as everything is in it's own namespace (telescope
      -- defaults, as well as each extension).
      require('telescope').setup(opts)
      require('telescope').load_extension 'undo'
    end,
  },
}
