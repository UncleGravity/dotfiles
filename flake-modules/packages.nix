{self, ...}: {
  perSystem = {
    inputs',
    pkgs,
    ...
  }: {
    packages = import ../packages {
      inherit pkgs self;
      clanCli = inputs'.clan-core.packages.clan-cli;
    };
  };
}
