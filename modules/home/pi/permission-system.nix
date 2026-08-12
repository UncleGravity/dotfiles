{pkgs, ...}: let
  permissionPolicy = (pkgs.formats.json {}).generate "pi-permissions.jsonc" {
    defaultPolicy = {
      tools = "ask";
      bash = "ask";
      mcp = "ask";
      skills = "ask";
      special = "ask";
    };

    tools = {
      read = "allow";
      grep = "allow";
      find = "allow";
      ls = "allow";
      write = "allow";
      edit = "allow";
      subagent = "allow";
    };

    special = {
      doom_loop = "deny";
      external_directory = "ask";
    };
  };
in {
  programs.pi-coding-agent.settings.packages = ["npm:pi-permission-system"];

  home.file.".pi/agent/pi-permissions.jsonc".source = permissionPolicy;
}
