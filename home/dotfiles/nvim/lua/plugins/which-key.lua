return { -- Useful plugin to show you pending keybinds.
  'folke/which-key.nvim',
  event = 'VimEnter', -- Sets the loading event to 'VimEnter'
  config = function() -- This is the function that runs, AFTER loading
    require('which-key').setup()

    -- Document existing key chains
    require('which-key').add {
      -- { '<leader>a', group = '[A]vante', icon = { icon = '', color = 'azure' } },
      { '<leader>c', group = '[c]ode' },
      { '<leader>d', group = '[d]ocument' },
      { '<leader>r', group = '[r]ename' },
      { '<leader>s', group = '[s]earch', icon = { icon = '', color = 'azure' } },
      { '<leader>w', group = '[w]orkspace' },
      { '<leader>t', group = '[t]oggle' },
      { '<leader>h', group = 'Git [h]unk', mode = { 'n', 'v' } },
      { '<leader>b', group = '[b]uffer' },
      { '<leader>l', group = '[l]azy', icon = { icon = '󰒲', color = 'azure' } },

      -- Neotree
      { mode = 'n', '<leader>e', ':Neotree reveal toggle<CR>', desc = '[e]xplorer', icon = { icon = '󰙅', color = 'orange' } },

      -- Lazy
      { mode = 'n', '<leader>ll', '<cmd>Lazy<cr>', desc = 'Open Lazy', icon = { icon = '󰒲', color = 'azure' } },
      { mode = 'n', '<leader>lg', '<cmd>LazyGit<cr>', desc = 'Open LazyGit', icon = { icon = '', color = 'azure' } },

      -- Yazi
      { mode = 'n', '<leader>y', '<cmd>Yazi<cr>', desc = 'Yazi', icon = { icon = '󰇥', color = 'azure' } },

      -- Buffer
      -- { mode = 'n', '<leader>bd', '<cmd>bdelete<CR>', desc = '[D]elete current buffer' },

      { '<leader>q', group = '[q]uit', icon = { icon = '', color = 'green' } },
    }
  end,
}
