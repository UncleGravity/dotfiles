{lib, ...}: {
  programs.nixvim = {
    keymaps = [
      # ----------------------------------------------------------------------
      # -- Explorer
      {
        key = "<leader>e";
        action = "<cmd>lua Snacks.explorer()<CR>";
        options.desc = "[e]xplorer";
      }

      # ----------------------------------------------------------------------
      # -- Buffer Delete
      {
        key = "<leader>bd";
        action = "<cmd>lua Snacks.bufdelete()<CR>";
        options.desc = "Delete Buffer";
      }
      {
        key = "<leader>bD";
        action = "<cmd>lua Snacks.bufdelete.all()<CR>";
        options.desc = "Delete All Buffers";
      }
      {
        key = "<leader>bo";
        action = "<cmd>lua Snacks.bufdelete.other()<CR>";
        options.desc = "Delete Other Buffers";
      }

      # ----------------------------------------------------------------------
      # -- Picker
      {
        key = "<leader><space>";
        action = "<cmd>lua Snacks.picker.smart()<CR>"; # -- Files
        options.desc = "Smart Find Files";
      }
      {
        key = "<leader>/";
        action = "<cmd>lua Snacks.picker.grep()<CR>"; # -- Grep
        options.desc = "[g]rep";
      }
      {
        key = "<leader>s\"";
        action = "<cmd>lua Snacks.picker.registers()<CR>"; # -- Registers
        options.desc = "Registers";
      }
      {
        key = "<leader>sm";
        action = "<cmd>lua Snacks.picker.marks()<CR>"; # -- Marks
        options.desc = "Marks";
      }
      {
        key = "<leader>s/";
        action = "<cmd>lua Snacks.picker.search_history()<CR>"; # -- Search History
        options.desc = "Search History";
      }
      {
        key = "<leader>sc";
        action = "<cmd>lua Snacks.picker.commands()<CR>"; # -- Commands
        options.desc = "Commands";
      }
      {
        key = "<leader>sd";
        action = "<cmd>lua Snacks.picker.diagnostics()<CR>"; # -- Diagnostics
        options.desc = "Diagnostics";
      }
      {
        key = "<leader>sh";
        action = "<cmd>lua Snacks.picker.help()<CR>"; # -- Help Pages
        options.desc = "Help Pages";
      }
      {
        key = "<leader>sj";
        action = "<cmd>lua Snacks.picker.jumps()<CR>"; # -- Jumps
        options.desc = "Jumps";
      }
      {
        key = "<leader>sk";
        action = "<cmd>lua Snacks.picker.keymaps()<CR>"; # -- Keymaps
        options.desc = "Keymaps";
      }
      {
        key = "<leader>sT";
        action = "<cmd>lua Snacks.picker.todo_comments()<CR>"; # -- Todo Comments
        options.desc = "Todo Comments";
      }
    ];
    plugins.snacks = {
      enable = true;
      settings = {
        explorer = {
          enabled = true;
          replace_netrw = true;
        };
        bigfile.enable = true; # -- Deal with big files
        bufdelete.enabled = true; # -- Buffer deletion without closing windows
        # scroll.enabled = true;        # -- Smooth Scrolling
        quickfile.enabled = true; # -- Render files before plugins are loaded
        statuscolumn.enabled = true; # -- idk
        picker.enabled = true;
        # indent = {
        #   enabled = true;
        #   settings = {
        #     animate.enabled = false;
        #   };
        # };
      };
    };

    plugins.todo-comments = {
      enable = true;
      settings = {
        signs = false;
      };
    };

    plugins.noice = {
      enable = true;
      settings = {
        routes = [
          {
            filter = {
              event = "msg_show";
              any = [
                {find = "%d+L, %d+B";}
                {find = "; after #%d+";}
                {find = "; before #%d+";}
              ];
            };
            view = "mini";
          }
          {
            view = "notify";
            filter = {event = "msg_showmode";};
          }
        ];
        lsp = {
          hover = {
            silent = true;
          };
          # override = {
          #   "vim.lsp.util.convert_input_to_markdown_lines" = true;
          #   "vim.lsp.util.stylize_markdown" = true;
          #   "cmp.entry.get_documentation" = true;
          # };
        };
        presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          inc_rename = true;
          lsp_doc_border = true;
        };
      };
    };
  };
}
