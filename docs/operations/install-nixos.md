# Install NixOS

Installation erases the target disk. The machine must already be enrolled, and
its Clan state must be committed and backed up.

```sh
just install-nixos portal root@<installer-ip>
just install-nixos sisyphus root@<installer-ip>
```

Portal loses `/var/lib/pangolin`. See [Portal](../machines/portal.md).
Sisyphus recreates every filesystem in its Disko graph. Kiwi installation is
blocked because its Disko graph includes the storage pool.

For Spark hardware, see [Install a Spark node](../machines/spark/install-node.md).

Do not regenerate an enrolled machine's `openssh` var. Keep console access open
until SSH accepts the expected host key and `systemctl --failed` reports no
failed units.
