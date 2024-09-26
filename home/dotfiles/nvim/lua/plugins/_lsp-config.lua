return { -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',
  -- enabled = false,
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
  },
  config = function()
    --  This function gets run when an LSP attaches to a particular buffer.
    --  For example, opening `main.rs` is associated with `rust_analyzer`)
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- Define a helper function to create keymaps
        local map = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -----------------------------------------------------------------------------
        -- Keybindings
        require('which-key').add {
          { '<leader>L', group = '[L]SP', icon = { icon = ' ', color = 'azure' } },
        }

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('<leader>LD', require('telescope.builtin').lsp_definitions, 'Goto [D]efinition')

        -- Find references for the word under your cursor.
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('<leader>LR', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>LI', require('telescope.builtin').lsp_implementations, 'Goto [I]mplementation')

        -- Jump to the type of the word under your cursor.
        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>Lt', require('telescope.builtin').lsp_type_definitions, '[t]ype definition')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>Lb', require('telescope.builtin').lsp_document_symbols, '[b]uffer symbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>Lp', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[p]roject symbols')

        -- Rename the variable under your cursor.
        --  Most Language Servers support renaming across files, etc.
        map('<leader>Lr', vim.lsp.buf.rename, '[r]ename')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>La', vim.lsp.buf.code_action, 'Code [a]ction')

        -- Opens a popup that displays documentation about the word under your cursor
        --  See `:help K` for why this keymap.
        map('K', vim.lsp.buf.hover, 'Hover Documentation')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -----------------------------------------------------------------------------
        -- Highlighting on cursor hold

        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.server_capabilities.documentHighlightProvider then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -----------------------------------------------------------------------------
        -- Inlay hints
        -- This may be unwanted, since they displace some of your code
        if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
          map('<leader>Lh', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
          end, '[T]oggle Inlay [H]ints')
        end
      end,
    })

    -----------------------------------------------------------------------------
    -- Capabilities

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    -- Add snippet support (optional?)
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -----------------------------------------------------------------------------
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

    -----------------------------------------------------------------------------
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

    -- JSON
    lspconfig.jsonls.setup {
      capabilities = capabilities,
    }

    -----------------------------------------------------------------------------

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

    -- Bash
    -- nixpkgs: nodePackages.bash-language-server
    lspconfig.bashls.setup {
      capabilities = capabilities,
    }

    -- TOML
    -- nixpkgs: taplo
    lspconfig.taplo.setup {
      capabilities = capabilities,
    }

    -- TODO:
    -- SQL
    -- Docker Compose https://github.com/microsoft/compose-language-service
  end,
}
