return { -- Autocompletion
  -- 'hrsh7th/nvim-cmp',
  'iguanacucumber/magazine.nvim',
  name = 'nvim-cmp',
  -- enabled = false,
  version = false, -- use latest
  event = 'InsertEnter',
  dependencies = {

    -----------------------------------------------------------------------------------------------
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
      opts = {
        history = true, -- don't lose snip navigation
        delete_check_events = 'TextChanged', -- Check if the current snippet was deleted.
      },
    },

    -----------------------------------------------------------------------------------------------
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
  },

  -----------------------------------------------------------------------------------------------
  -- CMP config
  config = function()
    local cmp = require 'cmp'
    local luasnip = require 'luasnip'
    local defaults = require 'cmp.config.default'()
    local lspkind = require 'lspkind'

    vim.api.nvim_set_hl(0, 'FloatBorder', { link = 'Normal' }) -- fix de background color border

    cmp.setup {
      -- Don't preselect
      preselect = cmp.PreselectMode.None,
      completion = { completeopt = 'menu,menuone,noinsert,noselect' },

      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },

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
        -- ['<Tab>'] = cmp.mapping(function(fallback)
        --   if cmp.visible() then
        --     cmp.select_next_item()
        --   elseif luasnip.expand_or_locally_jumpable() then
        --     luasnip.expand_or_jump()
        --   else
        --     fallback()
        --   end
        -- end, { 'i', 's' }),
        -- ['<S-Tab>'] = cmp.mapping.select_prev_item(),

        -- Scroll the documentation window [b]ack / [f]orward
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),

        -- Accept ([y]es) the completion.
        ['<C-y>'] = cmp.mapping.confirm {
          select = true,
          behavior = cmp.ConfirmBehavior.Replace,
        },
        ['<CR>'] = cmp.mapping.confirm {
          behavior = cmp.ConfirmBehavior.Replace,
        },

        -- Manually trigger a completion from nvim-cmp.
        ['<C-Space>'] = cmp.mapping.complete {},

        -- navigate around snippets
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
        ['<C-j'] = cmp.mapping(function()
          if luasnip.choice_active() then
            luasnip.change_choice(1)
          end
        end, { 'i', 's' }),

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },
      sources = {
        {
          name = 'nvim_lsp',
          keyword_length = 1,
          option = { markdown_oxide = { keyword_pattern = [[\(\k\| \|\/\|#\)\+]] } },
        },
        { name = 'luasnip' },
        { name = 'buffer' },
        { name = 'path' },
        { name = 'lazydev' },
      },
      formatting = { -- Make completion menu look nice
        fields = { 'abbr', 'kind', 'menu' },
        expandable_indicator = true,
        format = function(entry, item)
          -- Apply color to "color entries" (#fff, #000, etc.)
          local color_item = require('nvim-highlight-colors').format(entry, { kind = item.kind })

          -- Set the source name as the menu column
          item.menu = '[' .. entry.source.name .. ']'
          item.menu_hl_group = 'Conceal'

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
      sorting = defaults.sorting,
    }

    -----------------------------------------------------------------------------------------------
    --- Command Line Completions

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
