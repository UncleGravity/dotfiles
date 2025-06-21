{config, lib, pkgs, inputs, ...}: {
  imports = [ ./lsp.nix ./mini.nix ./snacks.nix ./gitsigns.nix ./colorscheme.nix ./formatting.nix ./treesitter.nix ./which-key.nix ];
  programs.nixvim = {
    enable = true;
    # defaultEditor = true;
    globals = {
      mapleader = " ";
      direnv_auto = 1;
      direnv_silent_load = 0;
    };
    # Neovim options
    opts = {
      scrolloff = 10; # Minimal number of screen lines to keep above and below the cursor.

      # Decrease mapped sequence wait time
      # Displays which-key popup sooner
      timeoutlen = 300;

      updatetime = 1000; # Decrease update time
      backspace = "indent,eol,start"; # allow backspace on indent, end of line or insert mode start position

      # tabs & indentation
      tabstop = 2; # 2 spaces for tabs (prettier default)
      softtabstop = 2; # Number of spaces that a <Tab> counts for while performing editing operations
      shiftwidth = 2; # Number of spaces to use for each step of (auto)indent
      expandtab = true; # Use spaces instead of tabs

      # Sets how neovim will display certain whitespace characters in the editor.
      # See `:help 'list'`
      # and `:help 'listchars'`
      list = true;
      listchars = { /* lead = "·"; */ tab = "» "; trail = "·"; nbsp = "␣"; };

      swapfile = false; #  turn off swapfile
      colorcolumn = "100"; #  Show max line length indicator
      confirm = true; #  Confirm to save changes before exiting modified buffer
      grepprg = "rg --vimgrep";
      inccommand = "nosplit"; #  preview incremental substitute
      
      # line numbers
      number = true; # Show line numbers
      relativenumber = true; # Show relative line numbers
    };
    keymaps = [
      # clear highlights with <Esc>
      {
        mode = [ "i" "n" ];
        key = "<esc>";
        action = "<cmd>noh<cr><esc>";
        options.desc = "Escape and Clear hlsearch";
      }
      
      # Only search on selected text if any
      { mode = "x"; key = "/"; action = "<Esc>/\\%V"; }
      { mode = "x"; key = "?"; action = "<Esc>?\\%V"; }

      # flash.nvim
      {
        mode = [ "n" "x" "o" ];
        key = "s";
        action = "<cmd>lua require('flash').jump()<cr>";
        options.desc = "Flash";
      }
      {
        mode = [ "n" "o" "x" ];
        key = "S"; 
        action = "<cmd>lua require('flash').treesitter()<cr>";
        options.desc = "Flash Treesitter";
      }
      {
        mode = [ "n" ];
        key = "\\S";
        action = "<Cmd>ScrollViewToggle<CR>";
        options.desc = "Toggle scroll view";
      }
      # Quit
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<cr>";
        options.desc = "Quit";
      }
      {
        mode = "n";
        key = "<leader>qw";
        action = "<cmd>wqa<cr>";
        options.desc = "Save and Quit";
      }
      # persistence.nvim
      {
        mode = "n";
        key = "<leader>qr";
        action = "function() require('persistence').load() end";
        options.desc = "Restore Session";
      }
      {
        mode = "n";
        key = "<leader>q/";
        action = "function() require('persistence').select() end";
        options.desc = "Select Session";
      }
      {
        mode = "n";
        key = "<leader>ql";
        action = "function() require('persistence').load({ last = true }) end";
        options.desc = "Restore Last Session";
      }
      {
        mode = "n";
        key = "<leader>qd";
        action = "function() require('persistence').stop() end";
        options.desc = "Don't Save Current Session";
      }
    ];
    clipboard.register = "unnamedplus";

    plugins = {
      hmts.enable = true;
      lualine.enable = true;
      tmux-navigator.enable = true;
      # hardtime.enable = true;
      flash.enable = true;
      scrollview = {
        enable = true;
        settings = {
          excluded_filetypes = [
            "nerdtree"
            "neo-tree"
            "codecompanion"
            "Avante"
            "AvanteInput"
            "trouble"
            "lazygit"
            "alpha"
            "TelescopePrompt"
            "ministarter"
            "dapui_scopes"
            "dapui_breakpoints"
            "dapui_stacks"
            "dapui_watches"
            "dap-repl"
            "dapui_console"
          ];
          current_only = true;
          always_show = true;
          base = "right";
          hover = false;
          signs_on_startup = [
            "changelist"
            "conflicts"
            "cursor"
            "diagnostics"
            "folds"
            "latestchange"
            "loclist"
            "marks"
            "quickfix"
            "search"
            "spell"
            "trail"
          ];
          diagnostics_error_symbol = "󰅚 ";
          diagnostics_warn_symbol = " ";
          # The plugin expects vim.diagnostic.severity constants; omit for now or pass as strings
          diagnostics_severities = [
            { __raw = "vim.diagnostic.severity.ERROR"; }
            { __raw = "vim.diagnostic.severity.WARN"; }
          ];
          scrollview_floating_windows = true;
        };
      };
      persistence.enable = true;
      alpha = {
        enable = false;
        layout = [
          { type = "padding"; val = 2; }
          {
            opts = { hl = "Type"; position = "center"; };
            type = "text";
            val = [
              "███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗"
              "████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║"
              "██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║"
              "██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║"
              "██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║"
              "╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"
            ];
          }
          { type = "padding"; val = 2; }
          {
            type = "group";
            val = [
              {
                on_press = { __raw = "function() vim.cmd[[ene]] end"; };
                opts = { shortcut = "n"; };
                type = "button";
                val = "  New file";
              }
              {
                on_press = { __raw = "function() vim.cmd[[qa]] end"; };
                opts = { shortcut = "q"; };
                type = "button";
                val = " Quit Neovim";
              }
            ];
          }
        ];

      };
    };
  };
} 
