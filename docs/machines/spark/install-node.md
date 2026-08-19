# Install a Spark node

Installation erases the NVMe. Enroll the node first and use the stock NixOS
minimal aarch64 USB image. Kexec does not work on this hardware.

1. Update firmware from DGX OS:

   ```sh
   sudo fwupdmgr refresh
   sudo fwupdmgr update
   ```

2. Disable Secure Boot in the BIOS.

   ```sh
   # Boot directly to BIOS
   sudo systemctl reboot --firmware-setup
   ```

3. Boot the NixOS USB image:

   ```sh
   sudo passwd root
   ip -br addr
   ```

4. Authorize the installer:

   ```sh
   host=spark-05
   ip=<installer-ip>
   ssh-keygen -R "$ip"
   ssh-copy-id "root@$ip"
   ```

5. Install NixOS:

   ```sh
   just spark-install "$host"
   ```

   The first build may take 30-60 minutes. Remove the USB drive during reboot.

6. Remove installer host keys:

   ```sh
   ssh-keygen -R "$ip"
   ssh-keygen -R "$host.local"
   ```

7. Keep console access until SSH works and no units have failed:

   ```sh
   ssh "$host.local" systemctl --failed
   ```

   Check both fabric links, exporters, NFS automounts, and intended workloads.
