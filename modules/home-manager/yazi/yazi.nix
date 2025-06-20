{ config, lib, pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    plugins = {
      max-preview = ./plugins/max-preview.yazi;
    };

    keymap = {
      mgr.prepend_keymap = [
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
      mgr = {
        sort_by = "mtime";
        sort_reverse = false;
        sort_dir_first = false;
      };
      preview = {
        image_delay = 0;
      };
    };
  };
}