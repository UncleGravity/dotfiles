{pkgs, ...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ForwardAgent = false;
        IdentityAgent =
          if pkgs.stdenv.isDarwin
          then ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
          else "~/.1password/agent.sock";
      };

      # Local
      "kiwi" = {
        ForwardAgent = true;
        HostName = "kiwi";
        User = "angel";
      };

      # Cloud
      "portal" = {
        HostName = "angel.pizza";
        User = "angel";
      };
    };
  };
}
