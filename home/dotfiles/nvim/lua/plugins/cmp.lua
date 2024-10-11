return { -- Autocompletion
  'hrsh7th/nvim-cmp',
  -- enabled = false,
  version = false, -- use latest
  event = 'InsertEnter',
  dependencies = {

    -- Snippet Engine & its associated nvim-cmp source
    {
      'L3MON4D3/LuaSnip',
      build = (function()
        -- Build Step is needed for regex support in snippets.
        return 'make install_jsregexp'
      end)(),
      dependencies = {
        'saadparwaiz1/cmp_luasnip',
        {
          'rafamadriz/friendly-snippets',
          config = function()
            require('luasnip.loaders.from_vscode').lazy_load()
          end,
        },
      },
    },

    -- Color Highlighting
    {
      'brenoprata10/nvim-highlight-colors',
      event = 'BufRead',
      config = function()
        require('nvim-highlight-colors').setup {
          render = 'virtual', ---@usage 'background'|'foreground'|'virtual'
          virtual_symbol = '■', --- if render=virtual, set symbol
          enable_tailwind = true, --- e.g. 'bg-blue-500'
        }
      end,
    },

    -- Other dependencies
    'hrsh7th/cmp-nvim-lsp', -- lsp completions
    'hrsh7th/cmp-path', -- local paths completions
    'hrsh7th/cmp-buffer', -- current buffer completions
    'onsails/lspkind.nvim', -- icons for 'kind' column
    'hrsh7th/cmp-cmdline', -- command line completions
    'hrsh7th/cmp-nvim-lsp-signature-help', -- show missing function arguments
  },
  config = function()
    local cmp = require 'cmp'
    local luasnip = require 'luasnip'
    local lspkind = require 'lspkind'
    luasnip.config.setup {}

    cmp.setup {
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },

      completion = { completeopt = 'menu,menuone,noinsert' },

      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
        -- completion = {
        --   border = 'rounded',
        --   scrollbar = true,
        --   winhighlight = 'Normal:Normal,FloatBorder:Normal,CursorLine:Visual,Search:None',
        -- },
        --
        -- documentation = {
        --   border = 'rounded',
        --   scrollbar = '',
        --   winhighlight = 'Normal:Normal,FloatBorder:Normal,CursorLine:Visual,Search:None',
        -- },
      },

      -- Please read `:help ins-completion`, it is really good!
      mapping = cmp.mapping.preset.insert {
        -- Move along the completion menu.
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<Tab>'] = cmp.mapping.select_next_item(),
        ['<S-Tab>'] = cmp.mapping.select_prev_item(),

        -- Scroll the documentation window [b]ack / [f]orward
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),

        -- Accept ([y]es) the completion.
        ['<C-y>'] = cmp.mapping.confirm { select = true },
        -- ['<CR>'] = cmp.mapping.confirm { select = true },

        -- Manually trigger a completion from nvim-cmp.
        ['<C-Space>'] = cmp.mapping.complete {},

        -- If you have a snippet that's like:
        --  function $name($args)
        --    $body
        --  end
        --
        -- <c-l> will move you to the right of each of the expansion locations.
        -- <c-h> is similar, except moving you backwards.
        ['<C-l>'] = cmp.mapping(function()
          if luasnip.expand_or_locally_jumpable() then
            luasnip.expand_or_jump()
          end
        end, { 'i', 's' }),
        ['<C-h>'] = cmp.mapping(function()
          if luasnip.locally_jumpable(-1) then
            luasnip.jump(-1)
          end
        end, { 'i', 's' }),

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },
      sources = {
        { name = 'nvim_lsp' },
        -- { name = 'nvim_lsp_signature_help' }, -- function arg popups while typing
        { name = 'luasnip' },
        { name = 'buffer' },
        { name = 'path' },
        { name = 'lazydev' },
      },
      formatting = {
        fields = { 'abbr', 'kind', 'menu' },
        expandable_indicator = true,
        format = function(entry, item)
          -- Apply color to "color entries" (#fff, #000, etc.)
          local color_item = require('nvim-highlight-colors').format(entry, { kind = item.kind })

          -- Set the source name as the menu column
          item.menu = entry.source.name

          -- Apply lspkind formatting (icons)
          item = lspkind.cmp_format {
            mode = 'symbol_text',
            ellipsis_char = '...',
            show_labelDetails = true,
          }(entry, item)

          -- Apply built in color highlighting if available
          if color_item and color_item.abbr_hl_group then
            item.kind_hl_group = color_item.abbr_hl_group
            item.kind = color_item.abbr
          end

          return item
        end,
      },
    }

    -- Set up cmdline completion for '/'
    -- cmp.setup.cmdline('/', {
    --   mapping = cmp.mapping.preset.cmdline(),
    --   sources = {
    --     { name = 'buffer' }
    --   }
    -- })

    -- Set up cmdline completion for ':'
    cmp.setup.cmdline(':', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = 'path' },
      }, {
        {
          name = 'cmdline',
          option = {
            ignore_cmds = { 'Man', '!' },
          },
        },
      }),
    })
  end,
}
