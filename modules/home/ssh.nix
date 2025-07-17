{
  config,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;
    forwardAgent = true;

    extraConfig = ''
      Include ${config.home.homeDirectory}/.config/colima/ssh_config
      IdentityAgent ${
        if pkgs.stdenv.isDarwin
        then ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
        else "~/.1password/agent.sock"
      }
    '';

    matchBlocks = {
      "kiwi" = {
        user = "angel";
        hostname = "kiwi";
      };
    };
  };
}
