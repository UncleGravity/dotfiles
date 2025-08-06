{
  pkgs,
  inputs,
  lib,
  ...
}: let
  # Flake path - make configurable via environment variable with sensible default
  flakePath = "$\{OPTNIX_FLAKE_PATH:-$HOME/nix}";

  # === Validation Helpers ===
  hasHomeManagerCmd = configType: configName: ''$(nix eval ${flakePath}#${configType}.${configName}.config --json --apply 'config: config ? home-manager' 2>/dev/null || echo "false")'';

  getUsernameCmd = configType: configName: ''$(nix eval ${flakePath}#${configType}.${configName}.config.home-manager.users --json --apply 'users: builtins.head (builtins.attrNames users)' | jq -r . 2>/dev/null || echo "nouser")'';

  # === Separate Config Generators ===

  mkSystemConfig = {
    name,
    description,
    configType,
    configName,
  }: {
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
      nix eval ${flakePath}#${configType}.${configName}.config.{{ .Option }} --json --apply 'let
        sanitize = v: if builtins.isAttrs v then
          (if (v ? type && v.type == "derivation") then (v.name or "<derivation>")
           else builtins.mapAttrs (_: sanitize) v)
        else if builtins.isList v then builtins.map sanitize v
        else if builtins.isPath v then toString v
        else if builtins.isFunction v then "<function>"
        else v;
      in sanitize' | jq . || echo '{"error": "Failed to evaluate option"}'
    '';
  };

  mkHomeManagerConfig = {
    name,
    description,
    configType,
    configName,
  }: {
    inherit name description;

    options-list-cmd = ''
      if [ "${hasHomeManagerCmd configType configName}" = "true" ]; then
        OPTNIX_FLAKE_PATH=${flakePath} nix eval --impure github:nix-community/home-manager#lib.homeManagerConfiguration --json --apply 'hmConfig: let
          flakeInputs = builtins.getFlake (builtins.getEnv "OPTNIX_FLAKE_PATH");
          systemConfig = flakeInputs.${configType}.${configName};
          username = builtins.head (builtins.attrNames systemConfig.config.home-manager.users);
          actualHomeConfig = (builtins.getAttr username systemConfig.config.home-manager.users).home;

          config = hmConfig {
            pkgs = systemConfig.pkgs;
            modules = [
              {
                home = {
                  username = actualHomeConfig.username;
                  homeDirectory = actualHomeConfig.homeDirectory;
                  stateVersion = actualHomeConfig.stateVersion;
                };
              }
            ] ++ systemConfig.config.home-manager.sharedModules;
          };
        in
          builtins.filter (v: v.visible && !v.internal)
            (systemConfig.pkgs.lib.optionAttrSetToDocList config.options)' || {
              echo '[]'
              echo "Warning: Failed to evaluate Home Manager for ${name}" >&2
            }
      else
        echo '[]'
        echo "Info: ${name} has no Home Manager configuration" >&2
      fi
    '';

    evaluator = ''
      if [ "${hasHomeManagerCmd configType configName}" = "true" ] && [ "${getUsernameCmd configType configName}" != "nouser" ]; then
        nix eval ${flakePath}#${configType}.${configName}.config.home-manager.users.${getUsernameCmd configType configName}.{{ .Option }} --json --apply 'let
          sanitize = v: if builtins.isAttrs v then
            (if (v ? type && v.type == "derivation") then (v.name or "<derivation>")
             else builtins.mapAttrs (_: sanitize) v)
          else if builtins.isList v then builtins.map sanitize v
          else if builtins.isPath v then toString v
          else if builtins.isFunction v then "<function>"
          else v;
        in sanitize' | jq . || echo '{"error": "Failed to evaluate Home Manager option"}'
      else
        echo '{"error": "Home Manager not configured for this system", "details": "System has no Home Manager or no users configured"}'
      fi
    '';
  };

  mkStandaloneHomeConfig = {
    name,
    description,
    configType,
    configName,
  }: {
    inherit name description;

    options-list-cmd = ''
      nix eval ${flakePath}#${configType}.${configName} --json --apply 'input:
        builtins.filter (v: v.visible && !v.internal)
          (input.pkgs.lib.optionAttrSetToDocList input.options)' || {
            echo '[]'
            echo "Warning: Failed to load standalone Home Manager options for ${name}" >&2
          }
    '';

    evaluator = ''
      nix eval ${flakePath}#${configType}.${configName}.config.{{ .Option }} --json --apply 'let
        sanitize = v: if builtins.isAttrs v then
          (if (v ? type && v.type == "derivation") then (v.name or "<derivation>")
           else builtins.mapAttrs (_: sanitize) v)
        else if builtins.isList v then builtins.map sanitize v
        else if builtins.isPath v then toString v
        else if builtins.isFunction v then "<function>"
        else v;
      in sanitize' | jq . || echo '{"error": "Failed to evaluate standalone Home Manager option"}'
    '';
  };

  # === Config Type Dispatcher ===

  mkConfig = {
    name,
    description,
    configType,
    configName,
    isHomeManager ? false,
    isStandalone ? false,
  }:
    if isStandalone
    then mkStandaloneHomeConfig {inherit name description configType configName;}
    else if isHomeManager
    then mkHomeManagerConfig {inherit name description configType configName;}
    else mkSystemConfig {inherit name description configType configName;};

  # === Configuration Specifications ===

  systemConfigs =
    lib.pipe {
      nixos = inputs.self.nixosConfigurations or {};
      darwin = inputs.self.darwinConfigurations or {};
      standalone = inputs.self.homeConfigurations or {};
    } [
      # NixOS system configs
      (specs:
        lib.mapAttrs' (name: _:
          lib.nameValuePair name (mkConfig {
            inherit name;
            description = "NixOS configuration for ${name}";
            configType = "nixosConfigurations";
            configName = name;
          }))
        specs.nixos)

      # Darwin system configs
      (configs:
        configs
        // lib.mapAttrs' (name: _:
          lib.nameValuePair name (mkConfig {
            inherit name;
            description = "nix-darwin configuration for ${name}";
            configType = "darwinConfigurations";
            configName = name;
          })) (inputs.self.darwinConfigurations or {}))

      # Standalone Home Manager configs
      (configs:
        configs
        // lib.mapAttrs' (name: _:
          lib.nameValuePair name (mkConfig {
            inherit name;
            description = "Standalone Home Manager configuration for ${name}";
            configType = "homeConfigurations";
            configName = name;
            isStandalone = true;
          })) (inputs.self.homeConfigurations or {}))
    ];

  # Helper to check if a system actually has Home Manager at build time
  systemHasHomeManager = configType: configs:
    lib.filterAttrs (
      name: _: let
        evalResult = builtins.tryEval (configs.${name}.config.home-manager or null);
      in
        evalResult.success && evalResult.value != null
    )
    configs;

  homeManagerConfigs = let
    nixosWithHM = systemHasHomeManager "nixosConfigurations" (inputs.self.nixosConfigurations or {});
    darwinWithHM = systemHasHomeManager "darwinConfigurations" (inputs.self.darwinConfigurations or {});
  in
    # Home Manager configs for NixOS systems (only those with HM)
    (lib.mapAttrs' (name: _:
      lib.nameValuePair "hm-${name}" (mkConfig {
        name = "hm-${name}";
        description = "Home Manager module for ${name}";
        configType = "nixosConfigurations";
        configName = name;
        isHomeManager = true;
      }))
    nixosWithHM)
    //
    # Home Manager configs for Darwin systems (only those with HM)
    (lib.mapAttrs' (name: _:
      lib.nameValuePair "hm-${name}" (mkConfig {
        name = "hm-${name}";
        description = "Home Manager module for ${name}";
        configType = "darwinConfigurations";
        configName = name;
        isHomeManager = true;
      }))
    darwinWithHM);

  # === Final Configuration Assembly ===

  allConfigs = systemConfigs // homeManagerConfigs;

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
      '')
      allConfigs);
  in ''
    # ${globalConfig}
    ${scopeConfigs}
  '';

  optnix = inputs.optnix.packages.${pkgs.system}.optnix;
  configFile = pkgs.writeText "optnix-config.toml" configToml;
in
  pkgs.symlinkJoin {
    name = "optnix";
    paths = [optnix];
    nativeBuildInputs = [pkgs.makeWrapper];
    passthru = {
      inherit configFile;
    };
    postBuild = ''
      wrapProgram $out/bin/optnix \
        --add-flags '--config "${configFile}"'
    '';
  }
