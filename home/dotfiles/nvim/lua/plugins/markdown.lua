return {
  'tadmccorkle/markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  opts = {
    mappings = {
      inline_surround_toggle = '<leader>ms', -- (string|boolean) toggle inline style
      inline_surround_toggle_line = '<leader>msl', -- (string|boolean) line-wise toggle inline style
      inline_surround_delete = '<leader>md', -- (string|boolean) delete emphasis surrounding cursor
      inline_surround_change = '<leader>mc', -- (string|boolean) change emphasis surrounding cursor
      link_add = '<leader>ml', -- (string|boolean) add link
      link_follow = 'gx', -- (string|boolean) follow link
      go_curr_heading = false, -- (string|boolean) set cursor to current section heading
      go_parent_heading = '[p', -- (string|boolean) set cursor to parent section heading
      go_next_heading = ']]', -- (string|boolean) set cursor to next section heading
      go_prev_heading = '[[', -- (string|boolean) set cursor to previous section heading
    },
  },

  config = function(_, opts)
    require('markdown').setup(opts)
    vim.keymap.set('n', '<leader>mt', '<cmd>MDTaskToggle<cr>', {
      desc = 'Toggle markdown task',
    })
  end,
}
