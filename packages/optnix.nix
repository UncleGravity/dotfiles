{
  pkgs,
  inputs,
  lib,
  ...
}: let
  nixExe = lib.getExe pkgs.nix;
  formatter = lib.getExe pkgs.alejandra;
  tomlFormat = pkgs.formats.toml {};

  flakeRef = attrPath: ''"''${OPTNIX_FLAKE_PATH:-$HOME/nix}#${attrPath}"'';

  sanitizeExpr = ''
    let
      sanitize = value:
        if builtins.isAttrs value
        then
          if value ? type && value.type == "derivation"
          then value.name or "<derivation>"
          else builtins.mapAttrs (_: sanitize) value
        else if builtins.isList value
        then builtins.map sanitize value
        else if builtins.isPath value
        then toString value
        else if builtins.isFunction value
        then "<function>"
        else value;
    in
      sanitize
  '';

  mkDirectScope = {
    description,
    configType,
    configName,
  }: {
    inherit description;
    options-list-cmd = ''
      ${nixExe} eval ${flakeRef "${configType}.${configName}"} --json --apply 'input:
        builtins.filter (option: option.visible && !option.internal)
          (input.pkgs.lib.optionAttrSetToDocList input.options)'
    '';
    evaluator = ''
      ${nixExe} eval ${flakeRef "${configType}.${configName}.config.{{ .Option }}"} \
        --apply '${sanitizeExpr}'
    '';
  };

  mkNestedHMScope = {
    description,
    configType,
    configName,
  }: {
    inherit description;
    options-list-cmd = ''
      ${nixExe} eval ${flakeRef "${configType}.${configName}"} --json --apply 'input:
        if input.options ? home-manager
        then
          builtins.filter (option: option.visible && !option.internal)
            (input.pkgs.lib.optionAttrSetToDocList
              (input.options.home-manager.users.type.nestedTypes.elemType.getSubOptions []))
        else []'
    '';
    evaluator = ''
      ${nixExe} eval ${flakeRef "${configType}.${configName}"} --apply 'input: let
        users = input.config.home-manager.users or {};
        usernames = builtins.attrNames users;
      in
        if usernames == []
        then "Home Manager is not configured for this system"
        else
          (${sanitizeExpr})
            ((builtins.getAttr (builtins.head usernames) users).{{ .Option }})'
    '';
  };

  nixosConfigurations = inputs.self.nixosConfigurations or {};
  darwinConfigurations = inputs.self.darwinConfigurations or {};
  standaloneConfigurations = inputs.self.homeConfigurations or {};

  nixosNames = builtins.attrNames nixosConfigurations;
  darwinNames = builtins.attrNames darwinConfigurations;
  standaloneNames = builtins.attrNames standaloneConfigurations;

  mkDirectScopes = {
    configurations,
    configType,
    describe,
  }:
    lib.mapAttrs (
      configName: _:
        mkDirectScope {
          inherit configName configType;
          description = describe configName;
        }
    )
    configurations;

  mkNestedHMScopes = configType: configurations:
    lib.mapAttrs' (
      configName: _:
        lib.nameValuePair "hm-${configName}" (mkNestedHMScope {
          inherit configName configType;
          description = "Home Manager module for ${configName}";
        })
    )
    configurations;

  directScopes =
    mkDirectScopes {
      configurations = nixosConfigurations;
      configType = "nixosConfigurations";
      describe = configName: "NixOS configuration for ${configName}";
    }
    // mkDirectScopes {
      configurations = darwinConfigurations;
      configType = "darwinConfigurations";
      describe = configName: "nix-darwin configuration for ${configName}";
    }
    // mkDirectScopes {
      configurations = standaloneConfigurations;
      configType = "homeConfigurations";
      describe = configName: "Standalone Home Manager configuration for ${configName}";
    };

  nestedHMScopes =
    mkNestedHMScopes "nixosConfigurations" nixosConfigurations
    // mkNestedHMScopes "darwinConfigurations" darwinConfigurations;

  scopes = directScopes // nestedHMScopes;
  expectedScopeNames =
    nixosNames
    ++ darwinNames
    ++ standaloneNames
    ++ map (name: "hm-${name}") (nixosNames ++ darwinNames);
  scopesAreUnique =
    builtins.length expectedScopeNames
    == builtins.length (lib.unique expectedScopeNames);

  defaultScope =
    if pkgs.stdenv.hostPlatform.isDarwin && darwinNames != []
    then builtins.head darwinNames
    else if nixosNames != []
    then builtins.head nixosNames
    else if standaloneNames != []
    then builtins.head standaloneNames
    else null;

  settings =
    {
      min_score = 1;
      debounce_time = 25;
      formatter_cmd = formatter;
      inherit scopes;
    }
    // lib.optionalAttrs (defaultScope != null) {
      default_scope = defaultScope;
    };

  configFile = tomlFormat.generate "optnix-config.toml" settings;
  scopeList = pkgs.writeText "optnix-scopes.tsv" ''
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: scope: "${name}\t${scope.description}"
      )
      scopes
    )}
  '';
in
  assert lib.assertMsg scopesAreUnique
  "optnix scope names must be unique across NixOS, nix-darwin, Home Manager, and nested Home Manager scopes";
    pkgs.symlinkJoin {
      name = "optnix";
      paths = [pkgs.optnix];
      nativeBuildInputs = [pkgs.makeWrapper];
      passthru = {inherit configFile scopeList;};
      postBuild = ''
        wrapProgram $out/bin/optnix \
          --add-flags '--config "${configFile}"'
      '';
    }
