{
  pkgs,
  inputs,
  lib,
  ...
}: let
  optnix = pkgs.callPackage ./optnix.nix {inherit inputs pkgs lib;};
  inherit (optnix) configFile;
in
  pkgs.writeShellApplication {
    name = "optnix-fzf";
    runtimeInputs = [
      pkgs.fzf
      pkgs.gnused
      pkgs.jq
      optnix
    ];
    text = ''
      # Extract scope names from TOML config file
      get_scopes() {
        grep '^\[scopes\.' "${configFile}" | sed 's/\[scopes\.\(.*\)\]/\1/' | sort
      }

      # Get scope descriptions for display
      get_scope_with_description() {
        scope_name="$1"
        description=$(grep -A 1 "^\[scopes\.$scope_name\]" "${configFile}" | grep '^description' | sed 's/description = "\(.*\)"/\1/')
        echo "$scope_name - $description"
      }

      # Get available scopes
      scopes=$(get_scopes)

      if [ -z "$scopes" ]; then
        echo "No scopes found in config"
        exit 1
      fi

      # Build list with descriptions for fzf
      scope_list=""
      while IFS= read -r scope; do
        if [ -n "$scope" ]; then
          scope_with_desc=$(get_scope_with_description "$scope")
          scope_list="$scope_list$scope_with_desc"$'\n'
        fi
      done <<< "$scopes"

      # Use fzf to select scope
      selected=$(echo -n "$scope_list" | fzf --prompt="Select scope: " --height=40% --border)

      if [ -n "$selected" ]; then
        # Extract scope name (everything before the first " - ")
        scope_name=$(echo "$selected" | cut -d' ' -f1)
        echo "Running optnix with scope: $scope_name"
        exec optnix -s "$scope_name" --config "${configFile}" "$@"
      else
        echo "No scope selected"
        exit 1
      fi
    '';
  }
