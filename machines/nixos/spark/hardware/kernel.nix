{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  kernelSource = import "${inputs.dgx-spark}/kernel-configs/nvidia-kernel-source.nix";
  dgxKernelConfig = import "${inputs.dgx-spark}/kernel-configs/nvidia-dgx-spark-${kernelSource.nvidiaKernelVersion}.nix" {
    inherit lib;
  };

  nvidiaKernel = pkgs.linuxPackagesFor (
    pkgs.linux_6_17.override {
      enableCommonConfig = true;
      ignoreConfigErrors = true;

      argsOverride = {
        src = kernelSource.mkNvidiaKernelSource pkgs;
        version = "${kernelSource.nvidiaKernelVersion}-nvidia";
        modDirVersion = kernelSource.nvidiaKernelVersion;
        kernelPatches = [
          {
            name = "rust-gendwarfksyms-fix";
            patch = "${inputs.dgx-spark}/patches/rust-gendwarfksyms-fix.patch";
          }
        ];
        structuredExtraConfig =
          dgxKernelConfig
          // (with lib.kernel; {
            PREEMPT_VOLUNTARY = lib.mkForce no;
            SECURITY_APPARMOR_BOOTPARAM_VALUE = freeform "1";
            SECURITY_APPARMOR_RESTRICT_USERNS = lib.mkForce yes;
            USB_STORAGE = yes;
            USB_UAS = yes;
            OVERLAY_FS = yes;
            UEVENT_HELPER = no;
            UBUNTU_HOST = no;
          });
      };
    }
  );

  scrubKernelDevRefs = drv:
    drv.overrideAttrs (old: {
      postFixup =
        (old.postFixup or "")
        + ''
          if [ -d "$out/lib/modules" ]; then
            find $out/lib/modules -name '*.ko' -print0 \
              | xargs -0 -r ${pkgs.removeReferencesTo}/bin/remove-references-to \
                  -t ${config.boot.kernelPackages.kernel.dev}
          fi
        '';
    });

  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.production;
in {
  config = lib.mkIf config.hardware.dgx-spark.useNvidiaKernel {
    boot = {
      kernelPackages = lib.mkForce nvidiaKernel;
      kernelParams = ["cppc_cpufreq.auto_sel_mode=1"];
    };

    # The upstream scrub captures its pre-patch kernel. Retarget it so the
    # NVIDIA modules depend only on the final kernel with our Kconfig fix.
    hardware.nvidia.package = lib.mkForce (nvidiaPackage
      // {
        open = scrubKernelDevRefs nvidiaPackage.open;
        mod = scrubKernelDevRefs nvidiaPackage.mod;
      });
  };
}
