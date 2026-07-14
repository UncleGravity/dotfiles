{
  pkgs,
  ...
}: {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";

    # put external tools on PATH for yazi
    extraPackages = with pkgs; [
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

    plugins = {
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true; # generates `require("git"):setup()` in init.lua
      };
    };

    settings = {
      plugin.prepend_fetchers = [
        { group = "git"; url = "*";  run = "git"; }
        { group = "git"; url = "*/"; run = "git"; }
      ];
      mgr = {
        sort_by = "mtime";
        sort_reverse = false;
        sort_dir_first = false;
      };
      preview.image_delay = 0;
    };

    keymap = {
      mgr.prepend_keymap = [
        # Copy using "cb"
        {
          on = ["y"];
          run = [
            ''shell 'cb copy "$@"' --confirm''
            "yank"
          ];
          desc = "Yank to clipboard";
        }
        # Toggle Preview Pane
        {
          on = "T";
          run = "plugin toggle-pane max-preview";
          desc = "Maximize or restore preview";
        }
      ];

      input.prepend_keymap = [
        { on = [ "<Esc>" ]; run = "close"; desc = "Cancel input"; }
      ];
    };
    # theme = { /* if you want theme.toml */ };
  };
}
