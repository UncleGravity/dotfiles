return { -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  branch = '0.1.x',
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
          find_command = { 'rg', '--files', '--sortr=modified', '--hidden', '--glob', '!.git/' },
        },
        buffers = {
          show_all_buffers = true,
          sort_lastused = true,
          theme = 'dropdown',
          mappings = {
            i = {
              -- BUG: Doesn't work for currenly open buffer
              ['<c-d>'] = require('telescope.actions').delete_buffer,
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
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    -- vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    -- vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[S]earch [B]uffers' })
    vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = 'Search Files' })
    vim.keymap.set('n', '<leader>,', builtin.buffers, { desc = 'Search Buffers' })
    vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = '[/] Fuzzily search in current buffer' })
    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sN', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
