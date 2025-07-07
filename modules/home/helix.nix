{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.helix = {
    enable = true;
    # package = pkgs.evil-helix;

    settings = {
      theme = "kanagawa";

      editor = {
        mouse = true;
        line-number = "relative";
        auto-format = false;
        rulers = [100];
        bufferline = "multiple";
        color-modes = true;

        lsp = {
          display-inlay-hints = true;
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        whitespace = {
          render = {
            space = "none";
            tab = "all";
            newline = "none";
          };
          characters = {
            tab = "→";
            newline = "⏎";
            space = "·";
            tabpad = "·";
          };
        };

        indent-guides = {
          render = true;
          character = "┆";
          skip-levels = 1;
        };
      };

      keys = {
        normal = {
          # Quick save
          "C-s" = ":w";
          # Quick quit
          "C-q" = ":q";
          # Format document
          "C-f" = ":format";
        };

        insert = {
          # Quick save in insert mode
          "C-s" = ["normal_mode" ":w" "insert_mode"];
        };
      };
    };
  };
}
