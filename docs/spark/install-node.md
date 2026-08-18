# Install a Spark node

Installation starts from the stock NixOS minimal aarch64 USB image. Kexec does
not work on this hardware: `kexec -e` resets the SoC into firmware and boots the
existing operating system.

The installer partitions the NVMe, installs NixOS, injects the Clan machine
identity, and reboots the node. The common identity, erase, rollback, and
post-install rules are in [Reinstall NixOS](../reinstall.md).

Inference uses a dedicated Clan-managed coordination key in addition to the
normal machine identity and SSH host key. Factory and USB installer host keys
must never be promoted into the installed system.

## Enroll a new node

Enrollment changes tracked repository state but does not contact or install the
machine. Existing enrolled nodes skip this section.

1. Choose a unique hostname, numeric fabric ID, management address, and
   management MAC. Arrange the DHCP reservation and enough switch capacity for
   both untagged VLAN 100 fabric links.
2. Add the node under `nodes` in
   `modules/clan/spark-cluster/inventory.nix`. Do not change inference instances
   merely to enroll a fleet member; workload placement is explicit in
   `modules/nixos/profiles/spark/inference/default.nix`.
3. Add its per-machine extension point:

   ```nix
   # machines/spark-05/configuration.nix
   _: {}
   ```

4. Stage the inventory and machine module. Nix flakes ignore an untracked
   machine module.
5. Generate and validate the new machine identity and vars:

   ```bash
   just spark-enroll spark-05
   ```

   The command generates the `openssh` public value first, then the rest of the
   machine vars. It stages only the generated state needed by subsequent Nix
   evaluations, never regenerates an existing enrollment, and never installs a
   disk.
6. Review and commit that staged state under `sops/machines/spark-05/`,
   `sops/secrets/spark-05-age.key/`, `vars/per-machine/spark-05/`, and the
   shared-var machine recipient links for `spark-05`. Run `nix flake check
   --builders ""` before installation.

## Install the node

1. Finish DGX OS factory setup and firmware updates:

   ```bash
   sudo fwupdmgr refresh
   sudo fwupdmgr update
   ```

2. Disable Secure Boot in the BIOS.
3. Confirm the node is declared in the `spark` service instance and all of its
   Clan vars are valid:

   ```bash
   nix run --builders "" .#clan -- vars check spark-0[N]
   ```

   Never regenerate an existing node's `openssh` generator during install or
   reinstall.
4. Boot the NixOS USB image. Set a temporary root password and verify that the
   management NIC received its reserved address:

   ```bash
   sudo passwd root
   ip -br addr
   ```

5. Replace the temporary known-host entry and authorize the operator:

   ```bash
   ssh-keygen -R <ip>
   ssh-copy-id root@<ip>
   ```

6. Run the installer:

   ```bash
   just spark-install spark-0[N]
   ```

   The wrapper derives the target address from the Nix inventory, verifies the
   NixOS configuration and existing vars, and asks for the hostname before any
   erase. It then runs `clan machines install`, which stages the identity before
   running `nixos-anywhere`.
   Disko creates a 1 GiB ESP and an ext4 root filesystem. The first node may
   spend 30-60 minutes building the NVIDIA kernel. Remove the USB stick during
   the reboot.

7. Remove temporary installer entries:

    ```bash
    ssh-keygen -R <ip>
    ssh-keygen -R spark-0[N].local
    ```

8. Run the common post-install checks from [Reinstall NixOS](../reinstall.md)
   with `host` and `target` set to the Spark hostname. Then verify both fabric
   links, exporters, NFS automounts, and the node's intended inference state.

Successful remote builds publish their input and output closures to the
personal cache. Later nodes can substitute the kernel and drivers from that
cache. A `nixpkgs` update creates new store paths, so the first subsequent
remote build must publish their replacements.
