# Add a Spark node

1. Choose a hostname, fabric ID, management address, and management MAC.
2. Add the DHCP reservation and two untagged VLAN 100 switch ports.
3. Add the node to `modules/clan/spark-cluster/inventory.nix`.
4. Add its extension point:

   ```nix
   # machines/spark-05/configuration.nix
   _: {}
   ```

5. Enroll it:

   ```sh
   host=spark-05
   git add modules/clan/spark-cluster/inventory.nix \
     "machines/$host/configuration.nix"
   just spark-enroll "$host"
   nix flake check
   ```

6. Review and commit the generated Clan state.

Workload placement is managed separately in
`modules/nixos/profiles/spark/inference/default.nix`.
