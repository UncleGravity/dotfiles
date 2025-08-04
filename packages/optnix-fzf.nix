{
  pkgs,
  inputs,
  lib,
  ...
}: let
  # Generate configurations dynamically from flake
  # Flake path - make configurable via environment variable with sensible default
  flakePath = "$\{OPTNIX_FLAKE_PATH:-$HOME/nix}";

  generateConfigs = configType: configName:
    if configType == "nixosConfigurations" then {
      name = configName;
      description = "NixOS configuration for ${configName}";
      options-list-cmd = ''
        nix eval ${flakePath}#nixosConfigurations.${configName} --json --apply 'input: let
          inherit (input) options pkgs;

          optionsList = builtins.filter
            (v: v.visible && !v.internal)
            (pkgs.lib.optionAttrSetToDocList options);
        in
          optionsList'
      '';
      evaluator = ''nix eval ${flakePath}#nixosConfigurations.${configName}.config.{{ .Option }} --json --apply 'let sanitize = v: if builtins.isAttrs v then (if (v ? type && v.type == "derivation") then (v.name or "<derivation>") else builtins.mapAttrs (_: sanitize) v) else if builtins.isList v then builtins.map sanitize v else if builtins.isPath v then toString v else if builtins.isFunction v then "<function>" else v; in sanitize' | jq .'';
    }
    else if configType == "darwinConfigurations" then {
      name = configName;
      description = "nix-darwin configuration for ${configName}";
      options-list-cmd = ''
        nix eval ${flakePath}#darwinConfigurations.${configName} --json --apply 'input: let
          inherit (input) options pkgs;

          optionsList = builtins.filter
            (v: v.visible && !v.internal)
            (pkgs.lib.optionAttrSetToDocList options);
        in
          optionsList'
      '';
      evaluator = ''nix eval ${flakePath}#darwinConfigurations.${configName}.config.{{ .Option }} --json --apply 'let sanitize = v: if builtins.isAttrs v then (if (v ? type && v.type == "derivation") then (v.name or "<derivation>") else builtins.mapAttrs (_: sanitize) v) else if builtins.isList v then builtins.map sanitize v else if builtins.isPath v then toString v else if builtins.isFunction v then "<function>" else v; in sanitize' | jq .'';
    }
    else {
      name = configName;
      description = "Standalone Home Manager configuration for ${configName}";
      options-list-cmd = ''
        nix eval ${flakePath}#homeConfigurations.${configName} --json --apply 'input: let
          inherit (input) options pkgs;

          optionsList = builtins.filter
            (v: v.visible && !v.internal)
            (pkgs.lib.optionAttrSetToDocList options);
        in
          optionsList'
      '';
      evaluator = ''nix eval ${flakePath}#homeConfigurations.${configName}.config.{{ .Option }} --json --apply 'let sanitize = v: if builtins.isAttrs v then (if (v ? type && v.type == "derivation") then (v.name or "<derivation>") else builtins.mapAttrs (_: sanitize) v) else if builtins.isList v then builtins.map sanitize v else if builtins.isPath v then toString v else if builtins.isFunction v then "<function>" else v; in sanitize' | jq .'';
    };

  # Generate home-manager module configs for systems that have HM as a module
  generateHmModuleConfig = configType: configName: {
    name = "hm-${configName}";
    description = "Home Manager module for ${configName}";
    options-list-cmd = ''
      nix eval github:nix-community/home-manager#packages.${pkgs.system}.docs-json --json --apply 'pkg: let inherit (builtins) fromJSON readFile; in fromJSON (readFile "''${pkg}/share/doc/home-manager/options.json")' | jq '[to_entries[] | .value.name = .key | .value.declarations = [.value.declarations[].name] | .value]'
    '';
    evaluator =
      if configType == "nixosConfigurations" then
        ''nix eval ${flakePath}#nixosConfigurations.${configName}.config.home-manager.users.angel.{{ .Option }} --json --apply 'let sanitize = v: if builtins.isAttrs v then (if (v ? type && v.type == "derivation") then (v.name or "<derivation>") else builtins.mapAttrs (_: sanitize) v) else if builtins.isList v then builtins.map sanitize v else if builtins.isPath v then toString v else if builtins.isFunction v then "<function>" else v; in sanitize' | jq .''
      else
        ''nix eval ${flakePath}#darwinConfigurations.${configName}.config.home-manager.users.angel.{{ .Option }} --json --apply 'let sanitize = v: if builtins.isAttrs v then (if (v ? type && v.type == "derivation") then (v.name or "<derivation>") else builtins.mapAttrs (_: sanitize) v) else if builtins.isList v then builtins.map sanitize v else if builtins.isPath v then toString v else if builtins.isFunction v then "<function>" else v; in sanitize' | jq .'';
  };

  # Get all configurations from flake
  configs =
    # NixOS configurations
    (lib.mapAttrs' (name: _: lib.nameValuePair name (generateConfigs "nixosConfigurations" name))
      (inputs.self.nixosConfigurations or {})) //
    # Darwin configurations
    (lib.mapAttrs' (name: _: lib.nameValuePair name (generateConfigs "darwinConfigurations" name))
      (inputs.self.darwinConfigurations or {})) //
    # Standalone Home Manager configurations
    (lib.mapAttrs' (name: _: lib.nameValuePair name (generateConfigs "homeConfigurations" name))
      (inputs.self.homeConfigurations or {})) //
    # Home Manager modules for NixOS systems
    (lib.mapAttrs' (name: _: lib.nameValuePair "hm-${name}" (generateHmModuleConfig "nixosConfigurations" name))
      (inputs.self.nixosConfigurations or {})) //
    # Home Manager modules for Darwin systems
    (lib.mapAttrs' (name: _: lib.nameValuePair "hm-${name}" (generateHmModuleConfig "darwinConfigurations" name))
      (inputs.self.darwinConfigurations or {}));

  # Generate TOML config content
  configToml = let
    globalConfig = ''
      min_score = 1
      debounce_time = 25
      default_scope = "nixos"
      formatter_cmd = "alejandra"
    '';

    scopeConfigs = lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: config: ''
      [scopes.${name}]
      description = "${config.description}"
      options-list-cmd = """
      ${config.options-list-cmd}
      """
      evaluator = """
      ${config.evaluator}
      """
    '') configs);
  in ''
    # ${globalConfig}

    ${scopeConfigs}
  '';

  configFile = pkgs.writeText "optnix-config.toml" configToml;
  # configNames = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: config: "${name} - ${config.description}") configs);
in
pkgs.writeShellApplication {
  name = "optnix-fzf";
  runtimeInputs = [
    pkgs.fzf
    pkgs.gnused
    pkgs.jq
    inputs.optnix.packages.${pkgs.system}.optnix
  ];
  passthru = {
    inherit configFile;
  };
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
