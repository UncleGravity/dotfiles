{
  programs.nushell = {
    enable = true;
    # Keep the right prompt visible after pressing enter (like p10k).
    # Starship's nu init clears TRANSIENT_PROMPT_COMMAND_RIGHT — re-point it at the
    # regular right prompt closure so the previous line keeps its timestamp etc.
    extraConfig = ''
      # History --------------------------------------------------------------------------------
      # SQLite backend: stores timestamp, cwd, exit_status, duration, host, session per entry.
      # The `history` command returns it as a structured table you can pipe/filter.
      $env.config.history.file_format = "sqlite"
      $env.config.history.max_size = 1_000_000
      $env.config.history.isolation = false # Share history between sessions
      $env.config.history.ignore_space_prefixed = true # Don't save commands that start with space

      $env.TRANSIENT_PROMPT_COMMAND_RIGHT = {|| do $env.PROMPT_COMMAND_RIGHT }

      # Carapace --------------------------------------------------------------------------------
      # Fallback chain for commands carapace has no native spec for: try zsh's completion
      # system first, then fish, then bash. Lets us reuse the wider zsh/fish ecosystems.
      $env.CARAPACE_BRIDGES = "zsh,fish,bash"
    '';
  };

  programs.carapace = {
    enable = true;
    # Carapace's late compdef replaces Nix's native flake-aware Zsh completer.
    enableZshIntegration = false;
  };

  programs.nix-your-shell = {
    enable = true;
    enableZshIntegration = true;
  };

  # Enables nushell integration by default for most modules
  home.shell.enableNushellIntegration = true;

  programs.starship = let
    # Nerd Font codepoints, encoded via JSON because Nix has no \uXXXX escape and the
    # Edit/Write tools strip Private-Use-Area glyphs when pasted literally.
    nf = builtins.fromJSON ''
      {
        "apple":  "",
        "nixos":  "",
        "linux":  "",
        "ubuntu": "",
        "debian": "",
        "arch":   "",
        "fedora": "",
        "alpine": "",
        "snow":   "",
        "rust":   "",
        "nodejs": "",
        "python": "",
        "golang": ""
      }
    '';
  in {
    enable = true;
    enableNushellIntegration = true;

    # Lean p10k look-alike: single line, no backgrounds, single space between segments.
    settings = {
      add_newline = false;

      format = "$os$directory$git_branch$git_status$character";
      right_format = "$cmd_duration$nodejs$rust$python$golang$nix_shell$time";

      character = {
        success_symbol = "[❯](76)";
        error_symbol = "[❯](196)";
      };

      os = {
        disabled = false;
        format = "[$symbol]($style) ";
        symbols = {
          Macos = nf.apple;
          NixOS = nf.nixos;
          Linux = nf.linux;
          Ubuntu = nf.ubuntu;
          Debian = nf.debian;
          Arch = nf.arch;
          Fedora = nf.fedora;
          Alpine = nf.alpine;
        };
      };

      directory = {
        style = "31";
        format = "[$path]($style) ";
        truncation_length = 3;
        truncate_to_repo = false;
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "76";
        symbol = "";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "178";
      };

      cmd_duration = {
        min_time = 3000;
        format = "[$duration]($style) ";
        style = "101";
      };

      nix_shell = {
        disabled = false;
        format = "[$symbol$state]($style)";
        symbol = "${nf.snow} ";
        style = "74";
      };

      time = {
        disabled = false;
        format = " [$time]($style)";
        time_format = "%I:%M:%S %p";
        style = "66";
      };

      # Language version modules — auto-shown when relevant files are detected in cwd
      # (Cargo.toml, package.json, pyproject.toml, go.mod, etc.).
      rust = {
        format = "[$symbol $version]($style)";
        symbol = nf.rust;
        style = "208"; # orange
      };

      nodejs = {
        format = "[$symbol $version]($style)";
        symbol = nf.nodejs;
        style = "70"; # green
      };

      python = {
        format = "[$symbol $version]($style)";
        symbol = nf.python;
        style = "220"; # yellow
      };

      golang = {
        format = "[$symbol $version]($style)";
        symbol = nf.golang;
        style = "38"; # cyan
      };
    };
  };
}
