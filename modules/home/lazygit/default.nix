{...}: {
  programs.lazygit = {
    enable = true;
    settings = {
      nerdFontsVersion = "3";

      # Git specific settings
      git = {
        autoFetch = false;
        autoRefresh = true;
        pagers = [
          {
            colorArg = "always";
            pager = ''delta --dark --paging=never --line-numbers --hyperlinks --hyperlinks-file-link-format="lazygit-edit://{path}:{line}"'';
          }
        ];
      };

      gui.sidePanelWidth = 0.2;
      refresher.refreshInterval = 0; # disables auto-refresh. really annoying, don't enable.
      os = {
        # OSC52 clipboard.
        copyToClipboardCmd = ''printf "\033]52;c;$(printf {{text}} | base64 | tr -d '\n')\a" > /dev/tty'';
        # Use nvim to edit files
        editPreset = "nvim";
      };
    };
  };
}
