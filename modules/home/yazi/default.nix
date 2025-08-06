{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    _7zz # for archive extraction and preview
    jq # json
    ffmpeg # video thumbnails
    poppler # Faster PDF
    fd # search
    ripgrep # search
    fzf # nav
    resvg # SVG Preview
    imagemagick # Font, HEIC, and JPEG XL preview
    clipboard-jh # clipboard manager
  ];
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    plugins = {
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      git = pkgs.yaziPlugins.git;
    };

    initLua = ''
      require("git"):setup()
    '';

    keymap = {
      mgr.prepend_keymap = [
        # Yank file to clipboard
        {
          on = ["y"];
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
          run = "plugin toggle-pane max-preview";
          desc = "Maximize or restore preview";
        }
      ];

      # Don't go into normal mode when pressing Esc
      input.prepend_keymap = [
        {
          on = ["<Esc>"];
          run = "close";
          desc = "Cancel input";
        }
      ];
    };

    settings = {
      # Register Git Plugin
      plugin.prepend_fetchers = [
        {
          id = "git";
          name = "*";
          run = "git";
        }
        {
          id = "git";
          name = "*/";
          run = "git";
        }
      ];
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
