return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  -- enabled = false,
  version = false, -- use latest commit
  event = { 'BufReadPre', 'BufNewFile' },
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  build = ':TSUpdate',
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
      move = {
        enable = true,
        goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer', [']a'] = '@parameter.inner' },
        goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer', [']A'] = '@parameter.inner' },
        goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer', ['[a'] = '@parameter.inner' },
        goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer', ['[A'] = '@parameter.inner' },
      },
    },
  },
  config = function(_, opts)
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

    -- Enable folding with treesitter
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldlevel = 99 -- Make sure nothing is folded on when opening a file

    -- Prefer git instead of curl in order to improve connectivity in some environments
    require('nvim-treesitter.install').prefer_git = true
    require('nvim-treesitter.configs').setup(opts)

    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  end,
}
