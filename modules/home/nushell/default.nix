{
  home.shell.enableNushellIntegration = true;

  programs = {
    nushell = {
      enable = true;
      # Keep the right prompt visible after pressing enter (like p10k).
      # Starship's nu init clears TRANSIENT_PROMPT_COMMAND_RIGHT — re-point it at the
      # regular right prompt closure so the previous line keeps its timestamp etc.
      extraConfig = ''
        $env.config.show_banner = false

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

        source ${./fzf-completion.nu}
      '';
    };

    carapace = {
      enable = true;
      # Carapace's late compdef replaces Nix's native flake-aware Zsh completer.
      enableZshIntegration = false;
    };

    starship = let
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
          "lock":   "",
          "rust":   "",
          "nodejs": "",
          "python": "",
          "golang": "",
          "zig":    ""
        }
      '';
    in {
      enable = true;
      enableNushellIntegration = true;

      # Lean p10k look-alike: single line, no backgrounds, single space between segments.
      settings = {
        add_newline = false;

        format = "$os$directory$git_branch$git_commit$git_state$git_status$character";
        right_format = "$status$cmd_duration$direnv($username$hostname )$nodejs$rust$python$golang$zig$nix_shell$time";

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
          format = "[$path]($style)[$read_only]($read_only_style) ";
          read_only = " ${nf.lock}";
          read_only_style = "196";
          truncation_length = 3;
          truncation_symbol = "…/";
          truncate_to_repo = false;
        };

        git_branch = {
          format = "[$branch]($style) ";
          style = "76";
          symbol = "";
          only_attached = true;
        };

        git_commit = {
          commit_hash_length = 7;
          format = "[$hash]($style) ";
          only_detached = true;
          style = "76";
        };

        git_state = {
          format = "[$state( $progress_current/$progress_total)]($style) ";
          style = "178";
        };

        git_status = {
          format = "([$ahead_behind$stashed$conflicted$staged$deleted$renamed$modified$untracked]($style) )";
          style = "178";
          use_git_executable = true;

          ahead = "[⇡\${count}](76) ";
          behind = "[⇣\${count}](76) ";
          diverged = "[⇣\${behind_count}⇡\${ahead_count}](76) ";
          stashed = "[*\${count}](76) ";
          conflicted = "[~\${count}](196) ";
          staged = "[+\${count}](178) ";
          deleted = "[✘\${count}](178) ";
          renamed = "[»\${count}](178) ";
          modified = "[!\${count}](178) ";
          untracked = "[?\${count}](39)";
        };

        cmd_duration = {
          min_time = 3000;
          format = "[$duration]($style) ";
          style = "101";
        };

        status = {
          disabled = false;
          format = "[$status( $signal_name)]($style) ";
          style = "196";
        };

        direnv = {
          disabled = false;
          format = "[$symbol$loaded]($style) ";
          symbol = "▼";
          loaded_msg = "";
          unloaded_msg = "!";
          style = "178";
        };

        username = {
          format = "[$user]($style)";
          style_user = "101";
          style_root = "196";
        };

        hostname = {
          ssh_only = true;
          ssh_symbol = "";
          format = "[@$hostname]($style)";
          style = "101";
        };

        nix_shell = {
          disabled = false;
          format = "[$symbol($name)]($style) ";
          symbol = "${nf.snow} ";
          style = "74";
        };

        time = {
          disabled = false;
          format = "[$time]($style)";
          time_format = "%H:%M";
          style = "66";
        };

        # Language version modules — auto-shown when relevant files are detected in cwd
        # (Cargo.toml, package.json, pyproject.toml, go.mod, etc.).
        rust = {
          format = "[$symbol( $version)]($style) ";
          symbol = nf.rust;
          style = "208"; # orange
        };

        nodejs = {
          format = "[$symbol( $version)]($style) ";
          symbol = nf.nodejs;
          style = "70"; # green
        };

        python = {
          format = "[$symbol( $version)( \\($virtualenv\\))]($style) ";
          symbol = nf.python;
          style = "220"; # yellow
        };

        golang = {
          format = "[$symbol( $version)]($style) ";
          symbol = nf.golang;
          style = "38"; # cyan
        };

        zig = {
          format = "[$symbol( $version)]($style) ";
          symbol = nf.zig;
          style = "214"; # gold
        };
      };
    };
  };
}
