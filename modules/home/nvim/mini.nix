{...}: {
  programs.nixvim.plugins.mini = {
    enable = true;
    modules = {
      # ----------------------------------------------------------------------
      # -- Sensible defaults
      basics = {
        options = {
          basic = true;
          extra_ui = true;
          # win_borders = "default"; # Uncomment and change if you want different border style
        };
        mappings = {
          basic = true;
          option_toggle_prefix = "\\";
        };
        autocommands.basic = true;
        silent = false;
      };

      # ----------------------------------------------------------------------
      # -- Home Page
      starter = {
        header = ''
          ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗
          ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║
          ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║
          ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║
          ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
        '';
      };

      # ----------------------------------------------------------------------
      # -- Buffer Tabs
      tabline = {
        tabpage_section = "right";
      };

      # ----------------------------------------------------------------------
      # -- Drag selections around, with Alt+<direction>
      move = {};

      # ----------------------------------------------------------------------
      # -- Autopairs `'"({[]})'`
      pairs = {};

      # ----------------------------------------------------------------------
      # -- Surround text objects
      surround = {
        mappings = {
          add = "sa";
          delete = "sd";
          find = "sf";
          find_left = "sF";
          highlight = "sh";
          replace = "sr";
          update_n_lines = "sn";
        };
      };

      # ----------------------------------------------------------------------
      # -- Split/join code blocks with gj
      splitjoin = {
        mappings = {
          toggle = "gj";
        };
      };

      # ----------------------------------------------------------------------
      # -- Bracketed motions
      bracketed = {
        buffer = {
          suffix = "b";
          options = {};
        };
        comment = {
          suffix = "c";
          options = {};
        };
        conflict = {
          suffix = "x";
          options = {};
        };
        diagnostic = {
          suffix = "d";
          options = {};
        };
        file = {
          suffix = "";
          options = {};
        };
        indent = {
          suffix = "i";
          options = {};
        };
        jump = {
          suffix = "j";
          options = {};
        };
        location = {
          suffix = "l";
          options = {};
        };
        oldfile = {
          suffix = "o";
          options = {};
        };
        quickfix = {
          suffix = "q";
          options = {};
        };
        treesitter = {
          suffix = "t";
          options = {};
        };
        undo = {
          suffix = "";
          options = {};
        };
        window = {
          suffix = "w";
          options = {};
        };
        yank = {
          suffix = "y";
          options = {};
        };
      };

      # ----------------------------------------------------------------------
      # -- Indent Line
      indentscope = {
        draw = {
          delay = 0;
          animation = {
            __raw = "require('mini.indentscope').gen_animation.none()";
          };
        };
        symbol = "│"; # character that draws the guide line
        options.try_as_border = true;
      };

      # ----------------------------------------------------------------------
      # -- Key sequence clues
      #   clue = {
      #     triggers = [
      #       # Leader triggers
      #       { mode = "n"; keys = "<Leader>"; }
      #       { mode = "x"; keys = "<Leader>"; }

      #       # Built-in completion
      #       { mode = "i"; keys = "<C-x>"; }

      #       # `g` key
      #       { mode = "n"; keys = "g"; }
      #       { mode = "x"; keys = "g"; }

      #       # Marks
      #       { mode = "n"; keys = "'"; }
      #       { mode = "n"; keys = "`"; }
      #       { mode = "x"; keys = "'"; }
      #       { mode = "x"; keys = "`"; }

      #       # Registers
      #       { mode = "n"; keys = "\""; }
      #       { mode = "x"; keys = "\""; }
      #       { mode = "i"; keys = "<C-r>"; }
      #       { mode = "c"; keys = "<C-r>"; }

      #       # Window commands
      #       { mode = "n"; keys = "<C-w>"; }

      #       # `z` key
      #       { mode = "n"; keys = "z"; }
      #       { mode = "x"; keys = "z"; }

      #       # '\\' key for toggle commands
      #       { mode = "n"; keys = "\\"; }
      #     ];

      #     clues = [
      #       # Enhance this by adding descriptions for <Leader> mapping groups
      #       { __raw = "require('mini.clue').gen_clues.builtin_completion()"; }
      #       { __raw = "require('mini.clue').gen_clues.g()"; }
      #       { __raw = "require('mini.clue').gen_clues.marks()"; }
      #       { __raw = "require('mini.clue').gen_clues.registers()"; }
      #       { __raw = "require('mini.clue').gen_clues.windows()"; }
      #       { __raw = "require('mini.clue').gen_clues.z()"; }
      #     ];

      #     window = {
      #       delay = 200;
      #     };
      #   };
    };
  };
}
