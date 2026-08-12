{
  programs.pi-coding-agent.settings = {
    hud = {
      mode = "overlay";
      startupNotification = false;
    };

    packages = ["npm:pi-hud"];
  };
}
