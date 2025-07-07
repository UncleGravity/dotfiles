{...}: {
  programs.nixvim = {
    plugins = {
      lsp = {
        enable = true;
        servers = {
          lua_ls.enable = true; # Lua
          html.enable = true; # HTML
          cssls = {
            # CSS
            enable = true;
            extraOptions = {
              on_attach =
                /*
                lua
                */
                ''
                  function(client, bufnr)
                    local file_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
                    if string.find(file_content, '@tailwind') then
                      vim.lsp.buf_detach_client(bufnr, client.id)
                    end
                  end
                '';
            };
          };
          ts_ls.enable = true; # Javascript/Typescript
          tailwindcss.enable = true; # Tailwind
          emmet_language_server.enable = true; # Emmet
          pyright = {
            # Python
            enable = true;
            settings.analysis = {
              reportUnusedCallResult = false;
            };
          };
          clangd.enable = true; # Cland
          nixd.enable = true; # Nix
          zls.enable = true; # Zig
          gopls.enable = true; # Go
          # rust_analyzer.enable = true;          # Rust
          bashls = {
            # Bash
            enable = true;
            filetypes = ["sh" "zsh"];
          };
          taplo.enable = true; # TOML
          yamlls.enable = true; # Yaml
        };
      };
    };

    lsp = {
      inlayHints.enable = true;
      # keymaps = [];
    };
  };
}
