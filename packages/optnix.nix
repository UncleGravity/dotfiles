{
  pkgs,
  inputs,
  lib,
  ...
}: let
  flakePath = "$\{OPTNIX_FLAKE_PATH:-$HOME/nix}";

  sanitizeExpr = ''let
    sanitize = v: if builtins.isAttrs v then
      (if (v ? type && v.type == "derivation") then (v.name or "<derivation>")
       else builtins.mapAttrs (_: sanitize) v)
    else if builtins.isList v then builtins.map sanitize v
    else if builtins.isPath v then toString v
    else if builtins.isFunction v then "<function>"
    else v;
  in sanitize'';

  # Direct scope — works for system configs (nixos/darwin) and standalone HM
  mkDirectScope = { name, description, configType, configName }: {
    inherit name description;
    options-list-cmd = ''
      nix eval ${flakePath}#${configType}.${configName} --json --apply 'input:
        builtins.filter (v: v.visible && !v.internal)
          (input.pkgs.lib.optionAttrSetToDocList input.options)' || {
            echo '[]'
            echo "Warning: Failed to load options for ${name}" >&2
          }
    '';
    evaluator = ''
      nix eval ${flakePath}#${configType}.${configName}.config.{{ .Option }} --json \
        --apply '${sanitizeExpr}' | jq . || echo '{"error": "Failed to evaluate option"}'
    '';
  };

  # Nested HM scope — for home-manager embedded inside a system config
  mkNestedHMScope = { name, description, configType, configName }: {
    inherit name description;
    options-list-cmd = ''
      HAS_HM=$(nix eval ${flakePath}#${configType}.${configName}.config --json \
        --apply 'config: config ? home-manager' 2>/dev/null || echo "false")
      if [ "$HAS_HM" = "true" ]; then
        OPTNIX_FLAKE_PATH=${flakePath} nix eval --impure github:nix-community/home-manager#lib.homeManagerConfiguration --json --apply 'hmConfig: let
          flakeInputs = builtins.getFlake (builtins.getEnv "OPTNIX_FLAKE_PATH");
          systemConfig = flakeInputs.${configType}.${configName};
          username = builtins.head (builtins.attrNames systemConfig.config.home-manager.users);
          actualHomeConfig = (builtins.getAttr username systemConfig.config.home-manager.users).home;
          config = hmConfig {
            pkgs = systemConfig.pkgs;
            modules = [
              { home = { username = actualHomeConfig.username; homeDirectory = actualHomeConfig.homeDirectory; stateVersion = actualHomeConfig.stateVersion; }; }
            ] ++ systemConfig.config.home-manager.sharedModules;
          };
        in builtins.filter (v: v.visible && !v.internal)
             (systemConfig.pkgs.lib.optionAttrSetToDocList config.options)' || {
              echo '[]'; echo "Warning: Failed to evaluate Home Manager for ${name}" >&2
            }
      else
        echo '[]'; echo "Info: ${name} has no Home Manager configuration" >&2
      fi
    '';
    evaluator = ''
      HAS_HM=$(nix eval ${flakePath}#${configType}.${configName}.config --json \
        --apply 'config: config ? home-manager' 2>/dev/null || echo "false")
      USERNAME=$(nix eval ${flakePath}#${configType}.${configName}.config.home-manager.users --json \
        --apply 'users: builtins.head (builtins.attrNames users)' 2>/dev/null | jq -r . 2>/dev/null || echo "nouser")
      if [ "$HAS_HM" = "true" ] && [ "$USERNAME" != "nouser" ]; then
        nix eval ${flakePath}#${configType}.${configName}.config.home-manager.users."$USERNAME".{{ .Option }} --json \
          --apply '${sanitizeExpr}' | jq . || echo '{"error": "Failed to evaluate Home Manager option"}'
      else
        echo '{"error": "Home Manager not configured for this system"}'
      fi
    '';
  };

  # === Discovery (attrNames only — no config evaluation) ===
  nixosNames = builtins.attrNames (inputs.self.nixosConfigurations or {});
  darwinNames = builtins.attrNames (inputs.self.darwinConfigurations or {});
  standaloneNames = builtins.attrNames (inputs.self.homeConfigurations or {});

  # === Assemble all scopes ===
  allConfigs =
    # System scopes
    (lib.genAttrs nixosNames (n: mkDirectScope {
      name = n; description = "NixOS configuration for ${n}";
      configType = "nixosConfigurations"; configName = n;
    }))
    // (lib.genAttrs darwinNames (n: mkDirectScope {
      name = n; description = "nix-darwin configuration for ${n}";
      configType = "darwinConfigurations"; configName = n;
    }))
    // (lib.genAttrs standaloneNames (n: mkDirectScope {
      name = n; description = "Standalone Home Manager configuration for ${n}";
      configType = "homeConfigurations"; configName = n;
    }))
    # Nested HM scopes
    // (lib.listToAttrs (map (n: lib.nameValuePair "hm-${n}" (mkNestedHMScope {
      name = "hm-${n}"; description = "Home Manager module for ${n}";
      configType = "nixosConfigurations"; configName = n;
    })) nixosNames))
    // (lib.listToAttrs (map (n: lib.nameValuePair "hm-${n}" (mkNestedHMScope {
      name = "hm-${n}"; description = "Home Manager module for ${n}";
      configType = "darwinConfigurations"; configName = n;
    })) darwinNames));

  # === TOML Generation ===
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
    '') allConfigs);
  in ''
    # ${globalConfig}
    ${scopeConfigs}
  '';

  configFile = pkgs.writeText "optnix-config.toml" configToml;
in
  pkgs.symlinkJoin {
    name = "optnix";
    paths = [pkgs.optnix];
    nativeBuildInputs = [pkgs.makeWrapper];
    passthru = { inherit configFile; };
    postBuild = ''
      wrapProgram $out/bin/optnix \
        --add-flags '--config "${configFile}"'
    '';
  }
