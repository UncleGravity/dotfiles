# Install a Spark node

Installation starts from the stock NixOS minimal aarch64 USB image. Kexec does
not work on this hardware: `kexec -e` resets the SoC into firmware and boots the
existing operating system.

The installer partitions the NVMe, installs NixOS, injects the Clan machine
identity, and reboots the node.

## SSH identity domains

1. Operator keys determine who can log in. They are declared in
   `modules/common/ssh-keys.nix` and authorized on every host.
2. Clan's machine Age identity is staged at `/var/lib/sops-nix/key.txt`. It
   decrypts Clan vars, including the runtime SSH host key.
3. Inference uses a separate Clan-managed coordination key. It is not the SSH
   server host key.

Factory and USB installer host keys must never be promoted into the installed
system. The Spark installer does not stage `/etc/ssh` host keys.

## Procedure

1. Finish DGX OS factory setup and firmware updates:

   ```bash
   sudo fwupdmgr refresh
   sudo fwupdmgr update
   ```

2. Disable Secure Boot in the BIOS.
3. Confirm the node is already enrolled in the `spark` service instance and
   that all of its Clan vars are valid:

   ```bash
   nix run --builders "" .#clan -- vars check spark-0[N]
   ```

   This reinstall procedure only supports the four existing enrolled nodes.
   First-time enrollment is a separate procedure. Never regenerate an existing
   node's `openssh` generator during reinstall.
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

   The installer verifies and stages the Clan machine identity before
   `nixos-anywhere` starts. It fails unless the evaluated Spark configuration
   uses only that identity for SOPS and the SSH server host key. Disko creates
   a 1 GiB ESP and an ext4 root filesystem. The first node may spend 30-60
   minutes building the NVIDIA kernel. Remove the USB stick during the reboot.

7. Verify the installed identity before accepting it into `known_hosts`.
    These commands must report the same fingerprint:

    ```bash
    ssh-keygen -lf \
      vars/per-machine/spark-0[N]/openssh/ssh.id_ed25519.pub/value
    ssh-keyscan -t ed25519 spark-0[N].local 2>/dev/null \
      | rg ' ssh-ed25519 ' \
      | ssh-keygen -lf -
    ```

8. Remove temporary entries and reconnect:

    ```bash
    ssh-keygen -R <ip>
    ssh-keygen -R spark-0[N].local
    ssh spark-0[N].local
    ```

   Verify `/var/lib/sops-nix/key.txt` and the runtime Clan SSH secret exist,
   while `/etc/ssh/ssh_host_ed25519_key{,.pub}` do not. Open a second strict
   SSH connection before closing the installer session.

Successful remote builds publish their input and output closures to the
personal cache. Later nodes can substitute the kernel and drivers from that
cache. A `nixpkgs` update creates new store paths, so the first subsequent
remote build must publish their replacements.
