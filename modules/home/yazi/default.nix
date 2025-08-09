{ pkgs, config, lib, ... }:

let
  yazi = pkgs.yazi.override {
    # put external tools on PATH for yazi
    # (the wrapper already has sensible optionalDeps; add extras here)
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
      git         = pkgs.yaziPlugins.git;
    };

    initLua = pkgs.writeText "yazi-init.lua" ''
        require("git"):setup()
      '';

    # IMPORTANT: use settings.yazi / settings.keymap
    settings = {
      yazi = {
        plugin.prepend_fetchers = [
          { id = "git"; name = "*";  run = "git"; }
          { id = "git"; name = "*/"; run = "git"; }
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
          {
            on = [ "y" ];
            run = [
              ''shell 'cb copy "$@"' --confirm''
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

        input.prepend_keymap = [
          { on = [ "<Esc>" ]; run = "close"; desc = "Cancel input"; }
        ];
      };
      # theme = { /* if you want theme.toml */ };
    };
  };
in {
  home.packages = [ yazi ];

  # "cd on exit" wrapper
  programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
    y() {
      local tmp="$(mktemp -t yazi-cwd.XXXXXX)"
      yazi --cwd-file="$tmp" "$@"
      if [ -f "$tmp" ]; then
        local cwd="$(cat "$tmp")"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd "$cwd"
        rm -f "$tmp"
      fi
    }
  '';
}
