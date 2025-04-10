return { -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',
  -- enabled = false,
  event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
  dependencies = {
    -- LSP progress bar
    { 'j-hui/fidget.nvim', opts = {} },

    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    {
      'folke/lazydev.nvim',
      ft = 'lua',
      opts = {
        library = {
          -- Load luvit types when the `vim.uv` word is found
          { path = 'luvit-meta/library', words = { 'vim%.uv' } },
        },
      },
    },
    { 'Bilal2453/luvit-meta', lazy = true }, -- Lua types
    { 'smjonas/inc-rename.nvim', opts = {} },
    { 'https://git.sr.ht/~whynothugo/lsp_lines.nvim' },
  },
  config = function()
    --  This function gets run when an LSP attaches to a particular buffer.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- Define a helper function to create keymaps
        local map = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -------------------------------------------------------------------------------------------
        -- Keybindings

        -- Jump to the definition of the word under your cursor. To jump back, press <C-t>.
        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('<leader>LD', require('telescope.builtin').lsp_definitions, 'Goto [D]efinition')

        -- Find references
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('<leader>LR', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>LI', require('telescope.builtin').lsp_implementations, 'Goto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>Lt', require('telescope.builtin').lsp_type_definitions, 'Goto [t]ype definition')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>Lb', require('telescope.builtin').lsp_document_symbols, 'list [b]uffer symbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>Ls', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'list project [s]ymbols')

        -- Show diagnostics for the current line in a floating window
        map('<leader>Lp', vim.diagnostic.open_float, '[P]review current line diagnostics')

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        -- map('<leader>Lr', vim.lsp.buf.rename, '[r]ename')
        map('<leader>Lr', ':IncRename ', '[r]ename')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>La', vim.lsp.buf.code_action, 'Code [a]ction')

        map('K', vim.lsp.buf.hover, 'Hover Documentation') --  See `:help K`
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -------------------------------------------------------------------------------------------
        -- Inlay hints
        -- This may be unwanted, since they displace some of your code
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
          map('<leader>Lh', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -----------------------------------------------------------------------------------------------
    -- Diagnostic configuration + lsp_lines (disabled by default)
    require('lsp_lines').setup()

    -- Diagnostic display configuration
    local config = {
      lines_enabled = false, -- disable lsp_lines by default
      text = {
        spacing = 4,
        source = 'if_many',
        prefix = '●',
      },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = '', -- '󰅚 ',
          [vim.diagnostic.severity.WARN] = '', -- ' ',
          [vim.diagnostic.severity.HINT] = '', -- ' ',
          [vim.diagnostic.severity.INFO] = '', -- ' ',
        },
      },
    }

    -- Apply diagnostic settings
    local function update_diagnostics()
      vim.diagnostic.config {
        underline = false,
        update_in_insert = false,
        virtual_text = not config.lines_enabled and config.text or false,
        virtual_lines = config.lines_enabled,
        severity_sort = true,
        signs = config.signs,
      }
    end

    -- Initial setup
    update_diagnostics()

    -- Toggle between virtual_text and lsp_lines
    vim.keymap.set('n', '<Leader>LL', function()
      config.lines_enabled = not config.lines_enabled
      update_diagnostics()
    end, { desc = 'Toggle lsp_lines' })

    -- Disable diagnostics in floating windows (to avoid LSP on things like lazy.nvim)
    vim.api.nvim_create_autocmd('WinEnter', {
      callback = function()
        local floating = vim.api.nvim_win_get_config(0).relative ~= ''
        if floating then
          vim.diagnostic.enable(false)
        else
          vim.diagnostic.enable(false)
        end
      end,
    })

    -----------------------------------------------------------------------------------------------
    -- Capabilities

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())
    -- local capabilities = require('cmp_nvim_lsp').default_capabilities()

    -- Add snippet support
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -----------------------------------------------------------------------------------------------
    -- LSP servers
    -- List: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
    local lspconfig = require 'lspconfig'

    -- Lua
    lspconfig.lua_ls.setup {
      capabilities = capabilities,
      settings = {
        Lua = {
          completion = {
            callSnippet = 'Replace',
          },
        },
      },
    }

    -----------------------------------------------------------------------------------------------
    -- nixpkgs: vscode-langservers-extracted

    -- HTML
    lspconfig.html.setup {
      capabilities = capabilities,
    }

    -- CSS
    -- Don't attach to CSS files that contain @tailwind directives
    lspconfig.cssls.setup {
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        local file_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')

        -- Check if the file contains "@tailwind" directive
        if string.find(file_content, '@tailwind') then
          -- Detach the LSP client from this buffer
          vim.lsp.buf_detach_client(bufnr, client.id)
        end
      end,
    }

    -----------------------------------------------------------------------------------------------

    -- JavaScript/TypeScript
    -- nixpkgs: typescript-language-server
    lspconfig.ts_ls.setup {
      capabilities = capabilities,
    }

    -- Tailwind
    -- nixpkgs: tailwindcss-language-server
    lspconfig.tailwindcss.setup {
      capabilities = capabilities,
    }

    -- Emmet
    -- nixpkgs: emmet-language-server
    lspconfig.emmet_language_server.setup {
      capabilities = capabilities,
    }

    -- Python
    -- nixpkgs: pyright
    lspconfig.pyright.setup {
      capabilities = capabilities,
      analysis = {
        reportUnusedCallResult = false,
      },
    }

    -- C
    -- nixpkgs: clang-tools
    lspconfig.clangd.setup {
      capabilities = capabilities,
    }

    -- Nix
    -- nixpkgs: nixd
    lspconfig.nixd.setup {
      capabilities = capabilities,
    }

    -- Zig
    -- nixpkgs: zls
    lspconfig.zls.setup {
      capabilities = capabilities,
    }

    -- Go
    -- nixpkgs: zls
    lspconfig.gopls.setup {
      capabilities = capabilities,
    }

    -- Rust
    -- nixpkgs: rust-analyzer
    lspconfig.rust_analyzer.setup {
      settings = {
        ['rust-analyzer'] = {
          diagnostics = {
            enable = true,
          },
        },
      },
    }

    -- Bash
    -- nixpkgs: bash-language-server
    lspconfig.bashls.setup {
      capabilities = capabilities,
      filetypes = { 'sh', 'zsh' },
    }

    -- TOML
    -- nixpkgs: taplo
    lspconfig.taplo.setup {
      capabilities = capabilities,
    }

    -- Markdown
    -- nixpkgs: marksman
    -- lspconfig.marksman.setup {
    --   capabilities = capabilities,
    -- }

    -- Markdown
    -- nixpkgs: markdown-oxide
    lspconfig.markdown_oxide.setup {
      -- Ensure that dynamicRegistration is enabled! This allows the LS to take into account actions like the
      -- Create Unresolved File code action, resolving completions for unindexed code blocks, ...
      capabilities = vim.tbl_deep_extend('force', capabilities, {
        workspace = {
          didChangeWatchedFiles = {
            dynamicRegistration = true,
          },
        },
      }),
      -- on_attach = on_attach, -- configure your on attach config
    }

    -- TODO:
    -- SQL
    -- Docker Compose https://github.com/microsoft/compose-language-service
  end,
}
