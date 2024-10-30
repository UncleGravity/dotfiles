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
      go_curr_heading = '', -- (string|boolean) set cursor to current section heading
      go_parent_heading = '[p', -- (string|boolean) set cursor to parent section heading
      go_next_heading = ']]', -- (string|boolean) set cursor to next section heading
      go_prev_heading = '[[', -- (string|boolean) set cursor to previous section heading
    },
  },
  init = function()
    -- Get the existing treesitter config
    local treesitter_configs = require 'nvim-treesitter.configs'
    local existing_config = treesitter_configs.get_module 'markdown'

    -- Merge our markdown settings with any existing ones
    local markdown_config = vim.tbl_deep_extend('force', existing_config or {}, {
      enable = true,
    })

    -- Update treesitter config
    treesitter_configs.setup {
      markdown = markdown_config,
    }
  end,
}

