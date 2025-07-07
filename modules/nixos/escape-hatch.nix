{config, pkgs, options, lib, ...}:
let
  cfg = config.my.escape-hatch;
  commonPackages = with pkgs; [
    # FOUND THIS LIST HERE: https://unix.stackexchange.com/questions/522822/different-methods-to-run-a-non-nixos-executable-on-nixos
    # According to the answer, this is the list of libraries that are needed to run "most" unpatched binaries.
    # stdenv.cc.cc
    # openssl
    # xorg.libXcomposite
    # xorg.libXtst
    # xorg.libXrandr
    # xorg.libXext
    # xorg.libX11
    # xorg.libXfixes
    # libGL
    # libva
    # pipewire
    # xorg.libxcb
    # xorg.libXdamage
    # xorg.libxshmfence
    # xorg.libXxf86vm
    # libelf
    
    # # Required
    # glib
    # gtk2
    # bzip2
    
    # # Without these it silently fails
    # xorg.libXinerama
    # xorg.libXcursor
    # xorg.libXrender
    # xorg.libXScrnSaver
    # xorg.libXi
    # xorg.libSM
    # xorg.libICE
    # gnome2.GConf
    # nspr
    # nss
    # cups
    # libcap
    # SDL2
    # libusb1
    # dbus-glib
    # ffmpeg
    # # Only libraries are needed from those two
    # libudev0-shim
    # udev
    
    # # Verified games requirements
    # xorg.libXt
    # xorg.libXmu
    # libogg
    # libvorbis
    # SDL
    # SDL2_image
    # glew110
    # libidn
    # tbb
    
    # # Other things from runtime
    # flac
    # freeglut
    # libjpeg
    # libpng
    # libpng12
    # libsamplerate
    # libmikmod
    # libtheora
    # libtiff
    # pixman
    # speex
    # SDL_image
    # SDL_ttf
    # SDL_mixer
    # SDL2_ttf
    # SDL2_mixer
    # libappindicator-gtk2
    # libdbusmenu-gtk2
    # libindicator-gtk2
    # libcaca
    # libcanberra
    # libgcrypt
    # libvpx
    # librsvg
    # xorg.libXft
    # libvdpau
    # gnome2.pango
    # cairo
    # atk
    # gdk-pixbuf
    # fontconfig
    # freetype
    # dbus
    # alsaLib
    # expat
    # # Needed for electron
    # libdrm
    # mesa
    # libxkbcommon 
    # zlib
  ];
in
{
  options.my.escape-hatch = {
    enable = lib.mkEnableOption "Nix escape hatches for running non-NixOS binaries";
  };

  config = lib.mkIf cfg.enable {
    # -----------------------------------------------------
    # Nix escape hatches
  # -----------------------------------------------------
  # Why? Because I tried to run a make file that required bash and NixOS doesn't have /bin/bash
  # So to avoid having to patch the make file, I just symlinked bash to /bin/bash
  # sudo ln -s /run/current-system/sw/bin/bash /bin/bash
  # But apparently there's a whole solution for this:
  services.envfs.enable = true; # Dynamically populates contents of /bin and /usr/bin/ so that it contains all executables from the PATH of the requesting process (eg. /bin/bash)

  # Run unpatched binaries
  # Why? Because vscode-server doesn't work without it.
  programs.nix-ld.enable = true; # Needed for vscode-server
  programs.nix-ld.libraries = options.programs.nix-ld.libraries.default ++ commonPackages;
  

  # Why? https://github.com/Mic92/nix-ld?tab=readme-ov-file#my-pythonnodejsrubyinterpreter-libraries-do-not-find-the-libraries-configured-by-nix-ld
  # Nix-ld is only used by unpatched executables that use the link loader at /lib or /lib64. 
  # If you use for example python from nixpkgs than it will not pick up NIX_LD_LIBRARY_PATH and NIX_LD since these types of binaries are configured to use a glibc from the nix store. 
  # So we need to manually set LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
  environment.systemPackages = with pkgs; [
    # Create an FHS environment using the command `fhs`, enabling the execution of non-NixOS packages in NixOS!
    (
      let 
        base = pkgs.appimageTools.defaultFhsEnvArgs; 
      in
        pkgs.buildFHSEnv (base // {
        name = "fhs";
        targetPkgs = pkgs: (
          # pkgs.buildFHSUserEnv provides only a minimal FHS environment,
          # lacking many basic packages needed by most software.
          # Therefore, we need to add them manually.
          #
          # pkgs.appimageTools provides basic packages required by most software.
          (base.targetPkgs pkgs) ++  commonPackages ++
          [
            pkg-config
            ncurses
            # Feel free to add more packages here if needed.
          ]
        );
        profile = "
          export FHS=1
          export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
        ";
        runScript = "zsh";
        extraOutputsToInstall = ["dev"];
      })
    )
  ];
  };
}
