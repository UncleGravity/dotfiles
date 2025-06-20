return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  -- enabled = false,
  version = false, -- use latest commit
  event = { 'BufReadPre', 'BufNewFile' },
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  build = ':TSUpdate',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  opts = {
    ensure_installed = {
      'asm',
      'arduino',

      'bash',
      'c',
      'cpp',
      'cmake',
      'make',
      'just',

      'diff',
      'gitignore',

      'html',
      'xml',
      'css',
      'javascript',
      'typescript',
      'tsx',

      'json',
      'yaml',
      'toml',

      'lua',
      'luadoc',
      'vim',
      'vimdoc',
      'tmux',
      'dockerfile',
      'regex',

      'csv',
      'markdown',
      'markdown_inline',
      'latex',

      'nix',
      'python',
      'go',
      'rust',
      'zig',
      'sql',
      'java',
      'kotlin',
    },
    -- Autoinstall languages that are not installed
    auto_install = true,
    highlight = {
      enable = true,
    },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '=',
        node_incremental = '=',
        scope_incremental = '+',
        node_decremental = '-',
      },
    },
    textobjects = {
      -- select = {
      -- enable = true,

      -- Automatically jump forward to textobj, similar to targets.vim
      -- lookahead = true,

      -- keymaps = {
      --   -- You can use the capture groups defined in textobjects.scm
      --   ['a='] = { query = '@assignment.outer', desc = 'Select outer part of an assignment' },
      --   ['i='] = { query = '@assignment.inner', desc = 'Select inner part of an assignment' },
      --   ['l='] = { query = '@assignment.lhs', desc = 'Select left hand side of an assignment' },
      --   ['r='] = { query = '@assignment.rhs', desc = 'Select right hand side of an assignment' },
      --
      --   ['aa'] = { query = '@parameter.outer', desc = 'Select outer part of a parameter/argument' },
      --   ['ia'] = { query = '@parameter.inner', desc = 'Select inner part of a parameter/argument' },
      --
      --   ['ai'] = { query = '@conditional.outer', desc = 'Select outer part of a conditional' },
      --   ['ii'] = { query = '@conditional.inner', desc = 'Select inner part of a conditional' },
      --
      --   ['al'] = { query = '@loop.outer', desc = 'Select outer part of a loop' },
      --   ['il'] = { query = '@loop.inner', desc = 'Select inner part of a loop' },
      --
      --   ['af'] = { query = '@call.outer', desc = 'Select outer part of a function call' },
      --   ['if'] = { query = '@call.inner', desc = 'Select inner part of a function call' },
      --
      --   ['am'] = { query = '@function.outer', desc = 'Select outer part of a method/function definition' },
      --   ['im'] = { query = '@function.inner', desc = 'Select inner part of a method/function definition' },
      --
      --   ['ac'] = { query = '@class.outer', desc = 'Select outer part of a class' },
      --   ['ic'] = { query = '@class.inner', desc = 'Select inner part of a class' },
      -- },
      -- },
      move = {
        enable = true,
        set_jumps = true, -- whether to set jumps in the jumplist
        goto_next_start = {
          [']a'] = { query = '@parameter.inner', desc = 'Next parameter' },
          [']b'] = { query = '@block.outer', desc = 'Next block' },
          [']f'] = { query = '@call.outer', desc = 'Next function call' },
          [']l'] = { query = '@loop.outer', desc = 'Next loop' },
        },
        goto_previous_start = {
          -- ['[m'] = { query = '@function.outer', desc = 'Prev function def start' },
          ['[a'] = { query = '@parameter.inner', desc = 'Prev parameter' },
          ['[b'] = { query = '@block.outer', desc = 'Prev block' },
          ['[f'] = { query = '@call.outer', desc = 'Prev function call' },
          ['[l'] = { query = '@loop.outer', desc = 'Prev loop' },
        },
      },
    },
  },
  config = function(_, opts)
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

    -- Enable folding with treesitter
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldtext = "v:lua.require('extra.foldtext')()"
    vim.wo.foldlevel = 99 -- Make sure nothing is folded on when opening a file

    -- Prefer git instead of curl in order to improve connectivity in some environments
    require('nvim-treesitter.install').prefer_git = true
    require('nvim-treesitter.configs').setup(opts)

    local ts_repeat_move = require 'nvim-treesitter.textobjects.repeatable_move'

    -- -- vim way: ; goes to the direction you were moving.
    vim.keymap.set({ 'n', 'x', 'o' }, ';', ts_repeat_move.repeat_last_move)
    vim.keymap.set({ 'n', 'x', 'o' }, ',', ts_repeat_move.repeat_last_move_opposite)
    --
    -- -- Optionally, make builtin f, F, t, T also repeatable with ; and ,
    -- vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f)
    -- vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F)
    -- vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t)
    -- vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T)
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  end,
}
