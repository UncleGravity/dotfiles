{ config, lib, pkgs, ... }:

let
  DOTFILES_DIR = ../../home/dotfiles;
in
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    plugins = {
      fg = ./plugins/fg.yazi;
      max-preview = ./plugins/max-preview.yazi;
    };

    keymap = {
      manager.prepend_keymap = [
        # Yank file to clipboard
        {
          on = [ "y" ];
          run = [
            ''
            	shell 'cb copy "$@"' --confirm
            ''
            "yank"
          ];
          desc = "Yank to clipboard";
        }
        {
          on = "T";
          run = "plugin max-preview";
          desc = "Maximize or restore preview";
        }

        # fg.yazi
        {
          on = [ "F" "g" ];
          run = "plugin fg --args='rg'";
          desc = "find by content";
        }
        {
          on = [ "F" "a" ];
          run = "plugin fg --args='rga'";
          desc = "find file by content (ripgrep-all)";
        }
        {
          on = [ "F" "f" ];
          run = "plugin fg --args='fzf'";
          desc = "find by filenames";
        }
        {
          on = [ "F" "d" ];
          run = "plugin fg --args='fd'";
          desc = "find directories only";
        }

        # MacOS only. Run native previewer.
        {
          on = [ "P" ];
          run = ''
            shell --confirm 'qlmanage -p "$@"'
          '';
          desc = "Preview";
          for = "macos";
        }
      ];

      # Don't go into normal mode when pressing Esc
      input.prepend_keymap = [
        {
          on = [ "<Esc>" ];
          run = "close";
          desc = "Cancel input";
        }
      ];
    };

    settings = {
      manager = {
        sort_by = "mtime";
        sort_reverse = false;
        sort_dir_first = false;
      };
      preview = {
        image_delay = 0;
      };
    };

    # flavors = {
    #   kanagawa = "${DOTFILES_DIR}/yazi/flavors/kanagawa.yazi";
    # };
    # theme = {
    #   flavor = {
    #     dark = "kanagawa";
    #     # light = "???";
    #   };
    # };
  };
}