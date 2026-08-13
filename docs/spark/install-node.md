# Install a Spark node

Installation starts from the stock NixOS minimal aarch64 USB image. Kexec does
not work on this hardware: `kexec -e` resets the SoC into firmware and boots the
existing operating system.

The installer partitions the NVMe, installs NixOS, injects both transitional
machine identities, and reboots the node.

## SSH identity domains

1. Operator keys determine who can log in. They are declared in
   `modules/common/ssh-keys.nix` and authorized on every host.
2. Clan's machine Age identity is staged at `/var/lib/sops-nix/key.txt`. It
   decrypts Clan vars, including the runtime SSH host key.
3. The retained SSH key at `/etc/ssh/ssh_host_ed25519_key` supports rollback
   to older generations that still decrypt legacy sops-nix files. The current
   generation uses only the Clan machine identity; inference uses a separate
   dedicated coordination key.
4. Both SSH key copies contain the same escrowed identity and therefore serve
   the same tracked fingerprint during the transition.

Factory and USB installer host keys must never be promoted into the installed
system.

## Procedure

1. Finish DGX OS factory setup and firmware updates:

   ```bash
   sudo fwupdmgr refresh
   sudo fwupdmgr update
   ```

2. Disable Secure Boot in the BIOS.
3. Record the `enP7s7` MAC address, add its DHCP reservation, add the node to
   the `spark` service instance in `flake-modules/clan.nix`, and enable its
   fabric switch port.
4. Create the permanent host identity:

   ```bash
   just host-key create spark-0[N]
   ```

5. Replace the node's `.sops.yaml` anchor with the printed host age identity,
   then update and verify its secret recipients:

   ```bash
   just sops-update-keys
   just host-key check spark-0[N]
   ```

6. Enroll the node in Clan's `sshd` service, import the same private and public
   keys into its `openssh` vars, and commit the host-key bundle, Clan vars,
   recipients, SOPS anchor, and rekeyed files before erasing the factory OS.
7. Boot the NixOS USB image. Set a temporary root password and verify that the
   management NIC received its reserved address:

   ```bash
   sudo passwd root
   ip -br addr
   ```

8. Replace the temporary known-host entry and authorize the operator:

   ```bash
   ssh-keygen -R <ip>
   ssh-copy-id root@<ip>
   ```

9. Run the installer:

   ```bash
   just spark-install spark-0[N]
   ```

   The installer verifies and stages both identities before `nixos-anywhere`
   starts. Disko creates a 1 GiB ESP and an ext4 root filesystem. The first
   node may spend 30-60 minutes building the NVIDIA kernel. Remove the USB
   stick during the reboot.

10. Verify the installed identity before accepting it into `known_hosts`.
    These commands must report the same fingerprint:

    ```bash
    ssh-keygen -lf secrets/host-keys/spark-0[N].pub
    ssh-keyscan -t ed25519 spark-0[N].local 2>/dev/null \
      | rg ' ssh-ed25519 ' \
      | ssh-keygen -lf -
    ```

11. Remove temporary entries and reconnect:

    ```bash
    ssh-keygen -R <ip>
    ssh-keygen -R spark-0[N].local
    ssh spark-0[N].local
    ```

Successful remote builds publish their input and output closures to the
personal cache. Later nodes can substitute the kernel and drivers from that
cache. A `nixpkgs` update creates new store paths, so the first subsequent
remote build must publish their replacements.
