{...}: {
  imports = [./base.nix];

  microvm.vcpu = 1;
  microvm.mem = 512;
}
