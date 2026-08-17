{config, ...}: {
  _module.args.hostname = config.clan.core.settings.machine.name;

  clan.core = {
    enableRecommendedDefaults = false;
    sops.defaultGroups = ["admins"];
  };
}
