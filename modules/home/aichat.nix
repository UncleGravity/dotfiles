{
  inputs,
  pkgs,
  ...
}: let
  configYaml = pkgs.writeText "aichat-config.yml" ''
    clients:
    - type: openai
    - type: claude
    - type: gemini
    model: openai
    editor: null
    keybindings: emacs
    save: true
    stream: true
    wrap: 'no'
    wrap_code: false
  '';

  aichat = inputs.wrapper-manager.lib.wrapWith pkgs {
    basePackage = pkgs.aichat;
    env.AICHAT_CONFIG_FILE.value = configYaml;
  };
in {
  home.packages = [aichat];
  home.shellAliases."ai" = "aichat";
}
