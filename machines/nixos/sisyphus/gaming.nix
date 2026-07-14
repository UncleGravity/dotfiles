{
  config,
  pkgs,
  username,
  ...
}: {
  specialisation.gaming.configuration = {
    system.nixos.tags = ["gaming"];

    # LATEST NVIDIA DRIVER
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;

    # AUTO LOGIN
    services.displayManager = {
      autoLogin = {
        enable = true;
        user = username;
      };
      defaultSession = "steam";
    };

    # Gamescope's DRM backend corrupts scanout if the display hotplugs after
    # the session starts (KVM switch, TV waking late/on another input), so
    # hold GDM until the TV is genuinely ready. "connected" alone is not
    # enough: the iGPU's HDMI port flaps connected with an empty EDID (idle
    # KVM input). Require a readable EDID, then give the link a moment to settle.
    # Gives up after 60s and proceeds anyway rather than blocking login.
    systemd.services.display-manager.preStart = ''
      for _ in {1..60}; do
        for conn in /sys/class/drm/card*-HDMI-A-*; do
          if ${pkgs.gnugrep}/bin/grep -q '^connected' "$conn/status" 2>/dev/null \
            && [ "$(${pkgs.coreutils}/bin/wc -c < "$conn/edid" 2>/dev/null)" -gt 0 ]; then
            ${pkgs.coreutils}/bin/sleep 3
            break 2
          fi
        done
        ${pkgs.coreutils}/bin/sleep 1
      done
    '';

    programs = {
      gamemode.enable = true;

      steam = {
        enable = true;
        gamescopeSession = {
          enable = true;
          # The AMD iGPU (kept enabled for the windows-vm specialisation) is
          # otherwise picked up by steamwebhelper for UI rendering, and the
          # cross-GPU buffer sharing to gamescope on the 4090 causes heavy
          # glitching/flickering. Pin the whole session to the NVIDIA GPU.
          env = {
            # Force GLX/EGL clients (Steam's CEF UI) onto the NVIDIA driver
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json";
            # Hide every Vulkan device except the RTX 4090 (10de:2684)
            MESA_VK_DEVICE_SELECT = "10de:2684!";
          };
        };
        # extest's LD_PRELOADed XTestFakeKeyEvent hook panics ("NoCompositor")
        # when Steam Input fires on game launch inside gamescope, aborting the
        # Steam client and crashing the session. Gamescope has native input
        # emulation via libei, so extest is redundant there anyway.
        extest.enable = false;
        protontricks.enable = true;
      };
    };
  };
}
