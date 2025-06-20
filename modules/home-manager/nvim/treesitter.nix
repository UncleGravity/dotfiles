{ pkgs,... }: {
  programs.nixvim = {

    extraFiles = {
      "lua/extra/foldtext.lua".text = builtins.readFile ./lua/extra/foldtext.lua;
      "lua/extra/persist-view.lua".text = builtins.readFile ./lua/extra/persist-view.lua;
    };

    extraConfigLua = ''require('extra.persist-view')'';

    opts = {
      foldmethod = "expr";
      foldexpr = "v:lua.vim.treesitter.foldexpr()";
      foldtext = "v:lua.require('extra.foldtext')()";
      foldlevel = 99;  # Make sure nothing is folded when a buffer opens
    };

    plugins.treesitter = {
      enable = true;
      settings.indent.enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        asm
        arduino
        bash
        c
        cpp
        cmake
        make
        just
        diff
        gitignore
        html
        xml
        css
        javascript
        typescript
        tsx
        json
        yaml
        toml
        lua
        luadoc
        vim
        vimdoc
        tmux
        dockerfile
        regex
        csv
        markdown
        markdown_inline
        latex
        nix
        python
        go
        rust
        zig
        sql
        java
        kotlin
      ];
    };
  };
}