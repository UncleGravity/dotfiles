In a previous thread I sent this message:

<previous>
    I noticed that nix has the build-vm command, where it builds a given nixos configuration and wraps all the necessary qemu setup for it to run. One thing I really like is that it seems like the nix store is shared with the host. I would like to replicate that.

    Build considerations:
    I am on aarch64-darwin, but I have a local linux builder that can build both x86_64-linux and aarch64-linux. So no problem there.

    Current legacy qemu vm commands:
    nix run .#nixosConfigurations.darwinVM.config.system.build.vm # build and run
    nixos-rebuild --flake .#darwinVM build-vm # build only

    building it creates the following:
    ```bash
       ~/nix main ⇡5 *2 +9 !3 ❯ eza --follow-symlinks --tree -L2 result
      result -> /nix/store/mqjgn2kncvzhpm2vlbzv4syns4ffnjz8-nixos-vm
      ├── bin
      │   └── run-nixos-vm -> /nix/store/g6fl9wrx9gzx806193k9f0zqbfcyfi39-run-nixos-vm
      └── system -> /nix/store/5j2ykq8arvv0djd60whmzhypkrvzkd1x-nixos-system-nixos-25.11.20250716.6e98748
          ├── activate
          ├── append-initrd-secrets -> /nix/store/gzd5rv8bnvyi20izlmjlxsrzs6gkanzd-append-initrd-secrets/bin/append-initrd-secrets
          ├── bin
          ├── boot.json
          ├── configuration-name
          ├── dry-activate
          ├── dtbs -> /nix/store/agv6jjsjdg3j57gmbwjl8prw4ymww6rw-linux-6.12.38/dtbs
          ├── etc -> /nix/store/nzd89ay1grwf0wzlsbd6apvk0144a60z-etc/etc
          ├── extra-dependencies
          ├── firmware -> /nix/store/0gdhirh25s4ppsrs662ad9s6k4z1nb49-firmware/lib/firmware
          ├── init
          ├── init-interface-version
          ├── initrd -> /nix/store/3j3z7g4z3sgai9rhvig4hn1c89sxz2ny-initrd-linux-6.12.38/initrd
          ├── kernel -> /nix/store/agv6jjsjdg3j57gmbwjl8prw4ymww6rw-linux-6.12.38/Image
          ├── kernel-modules -> /nix/store/hjbc31anfsriw3y9ahx3cs4d3pc4c8c6-linux-6.12.38-modules
          ├── kernel-params
          ├── nixos-version
          ├── specialisation
          ├── sw -> /nix/store/bycb3cm4bhw3mznpg2zmb7fz3mvrx7b7-system-path
          ├── system
          └── systemd -> /nix/store/hn8y5nj5iza6yjnll8j9xg41drar35s6-systemd-257.6
    ```
    The run-nixos-vm script looks like this:
    ```bash
      #! /nix/store/jg93ssisp2ybs513p4xx5277bq7vdcxb-bash-5.2p37/bin/bash

      export PATH=/nix/store/avh1maz05kap7i4cqxwjmh04k9kkfx46-coreutils-9.7/bin${PATH:+:}$PATH

      set -e

      # Create an empty ext4 filesystem image. A filesystem image does not
      # contain a partition table but just a filesystem.
      createEmptyFilesystemImage() {
        local name=$1
        local size=$2
        local temp=$(mktemp)
        /nix/store/kj7ygnpldrwngnpb0xwv3vgmqbral494-qemu-host-cpu-only-10.0.2/bin/qemu-img create -f raw "$temp" "$size"
        /nix/store/ys7llgjfma0qf9zsyqw5kj1x1ycpqamv-e2fsprogs-1.47.2-bin/bin/mkfs.ext4 -L nixos "$temp"
        /nix/store/kj7ygnpldrwngnpb0xwv3vgmqbral494-qemu-host-cpu-only-10.0.2/bin/qemu-img convert -f raw -O qcow2 "$temp" "$name"
        rm "$temp"
      }

      NIX_DISK_IMAGE=$(readlink -f "${NIX_DISK_IMAGE:-./nixos.qcow2}") || test -z "$NIX_DISK_IMAGE"

      if test -n "$NIX_DISK_IMAGE" && ! test -e "$NIX_DISK_IMAGE"; then
          echo "Disk image do not exist, creating the virtualisation disk image..."

          createEmptyFilesystemImage "$NIX_DISK_IMAGE" "1024M"

          echo "Virtualisation disk image created."
      fi

      # Create a directory for storing temporary data of the running VM.
      if [ -z "$TMPDIR" ] || [ -z "$USE_TMPDIR" ]; then
          TMPDIR=$(mktemp -d nix-vm.XXXXXXXXXX --tmpdir)
      fi



      # Create a directory for exchanging data with the VM.
      mkdir -p "$TMPDIR/xchg"







      cd "$TMPDIR"



      # Start QEMU.
      exec /nix/store/kj7ygnpldrwngnpb0xwv3vgmqbral494-qemu-host-cpu-only-10.0.2/bin/qemu-system-aarch64 -machine virt,gic-version=2,accel=hvf:tcg -cpu max \
          -name nixos \
          -m 4096 \
          -smp 1 \
          -device virtio-rng-pci \
          -net nic,netdev=user.0,model=virtio -netdev user,id=user.0,"$QEMU_NET_OPTS" \
          -virtfs local,path=/etc/ssh,security_model=mapped-xattr,mount_tag=dummy \
          -virtfs local,path=/nix/store,security_model=none,mount_tag=nix-store \
          -virtfs local,path="${SHARED_DIR:-$TMPDIR/xchg}",security_model=none,mount_tag=shared \
          -virtfs local,path=/Users/angel,security_model=mapped-xattr,mount_tag=test \
          -virtfs local,path="$TMPDIR"/xchg,security_model=none,mount_tag=xchg \
          -drive cache=writeback,file="$NIX_DISK_IMAGE",id=drive1,if=none,index=1,werror=report -device virtio-blk-pci,bootindex=1,drive=drive1,serial=root \
          -device virtio-keyboard \
          -device virtio-gpu-pci \
          -device usb-ehci,id=usb0 \
          -device usb-kbd \
          -device usb-tablet \
          -kernel ${NIXPKGS_QEMU_KERNEL_nixos:-/nix/store/5j2ykq8arvv0djd60whmzhypkrvzkd1x-nixos-system-nixos-25.11.20250716.6e98748/kernel} \
          -initrd /nix/store/3j3z7g4z3sgai9rhvig4hn1c89sxz2ny-initrd-linux-6.12.38/initrd \
          -append "$(cat /nix/store/5j2ykq8arvv0djd60whmzhypkrvzkd1x-nixos-system-nixos-25.11.20250716.6e98748/kernel-params) init=/nix/store/5j2ykq8arvv0djd60whmzhypkrvzkd1x-nixos-system-nixos-25.11.20250716.6e98748/init regInfo=/nix/store/sshxr8byrhh9x72l874w75jgi83zr39m-closure-info/registration console=tty0 console=ttyAMA0,115200n8 $QEMU_KERNEL_PARAMS" \
          -nographic \
          $QEMU_OPTS \
          "$@"
    ```

  NOW. My question is the following. If I wanted to recreates a simple version of this setup, BUT instead of using qemu, I want to use the native apple virtualization framework, since I can run aarch64-linux but ALSO x86_64-linux via rosetta, which VF supports. Most likely using https://github.com/crc-org/vfkit/. What is the shortest path to create a very focused nix script/module/package that handles this? Let's start small. What's a list of the steps required to get there, in todo list format?

  I have attached vfkit documentation.
  https://raw.githubusercontent.com/crc-org/vfkit/refs/heads/main/doc/usage.md
  https://raw.githubusercontent.com/crc-org/vfkit/refs/heads/main/doc/quickstart.md
  https://raw.githubusercontent.com/crc-org/vfkit/refs/heads/main/doc/missing-vz-api.md
  https://raw.githubusercontent.com/crc-org/vfkit/refs/heads/main/doc/boot-messages.md
</previous>

We ended up with the following files: [@flake.nix](@file:gemini/flake.nix) [@vfkit-runner.nix](@file:gemini/vfkit-runner.nix)

And this error when I do `nix run`:
```bash
   ~/Documents/vm/gemini ❯ nix run                                                        ▼ 04:11:59 PM
  --- Creating and formatting ./nixos.raw (20G) ---
  mke2fs 1.47.2 (1-Jan-2025)
  Creating filesystem with 5242880 4k blocks and 1310720 inodes
  Filesystem UUID: 3e3e2a3d-7c39-4e63-bf64-1744b0913df1
  Superblock backups stored on blocks:
  	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
  	4096000

  Allocating group tables: done
  Writing inode tables: done
  Creating journal (32768 blocks): done
  Writing superblocks and filesystem accounting information: done

  --- Disk image is ready ---
  --- Starting NixOS VM with vfkit ---
  INFO[0000] &{2 4096    {[linux kernel=/nix/store/wn9801n4bb9dqbv58cv246nnsa030gvc-nixos-vm/system/kernel initrd=/nix/store/wn9801n4bb9dqbv58cv246nnsa030gvc-nixos-vm/system/initrd cmdline="loglevel=4 net.ifnames=0 lsm=landlock,yama,bpf console=hvc0"] true}  [virtio-blk,path=./nixos.raw virtio-net,nat virtio-rng virtio-serial,stdio virtio-fs,sharedDir=/nix/store,mountTag=nix-store] none://  false  {[] false}}
  INFO[0000] boot parameters: &{VmlinuzPath:/nix/store/wn9801n4bb9dqbv58cv246nnsa030gvc-nixos-vm/system/kernel KernelCmdLine:loglevel=4 net.ifnames=0 lsm=landlock,yama,bpf console=hvc0 InitrdPath:/nix/store/wn9801n4bb9dqbv58cv246nnsa030gvc-nixos-vm/system/initrd}
  INFO[0000]
  INFO[0000] virtual machine parameters:
  INFO[0000] 	vCPUs: 2
  INFO[0000] 	memory: 4096 MiB
  INFO[0000]
  INFO[0000] Adding virtio-blk device (imagePath: ./nixos.raw)
  INFO[0000] Adding virtio-net device (nat: true macAddress: [])
  INFO[0000] Adding virtio-rng device
  INFO[0000] Adding stdio console
  INFO[0000] Adding virtio-fs device
  INFO[0000] virtual machine is running
  INFO[0000] waiting for VM to stop

  <<< NixOS Stage 1 >>>

  loading module dm_mod...
  loading module virtio_balloon...
  loading module virtio_console...
  loading module virtio_gpu...
  loading module virtio_rng...
  running udev...
  Starting systemd-udevd version 257.6
  kbd_mode: KDSKBMODE: Inappropriate ioctl for device
  starting device mapper and LVM...
  checking /dev/disk/by-label/nixos...
  fsck (busybox 1.36.1)
  [fsck.ext4 (1) -- /mnt-root/] fsck.ext4 -a /dev/disk/by-label/nixos
  nixos: clean, 12/1310720 files, 126834/5242880 blocks
  mounting /dev/disk/by-label/nixos on /...
  mounting nix-store on /nix/.ro-store...
  [    0.253387] 9pnet_virtio: no channels available for device nix-store
  mount: mounting nix-store on /mnt-root/nix/.ro-store failed: No such file or directory

  An error occurred in stage 1 of the boot process, which must mount the
  root filesystem on `/mnt-root' and then start stage 2.  Press one
  of the following keys:

    r) to reboot immediately
    *) to ignore the error and continue
```

  Let's try to find the simplest way to make this work. Don't try to fix everything at once. Let's break this into small chunks. Feel free to run your own terminal/console like nix run and rm nixos.raw. Do not ask for confirmation unless there are conflicting options to choose from. The editor will force me to allow/disallow each command anyway. Same goes for edits, if the edit is straighforward and doesn't require discussion or nuance, go for it. They are easy to undo.
