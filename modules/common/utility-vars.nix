{
  clan.core = {
    sops.defaultGroups = ["admins"];

    vars.generators.cachix = {
      share = true;

      prompts.auth-token = {
        description = "Cachix authentication token";
        type = "hidden";
        persist = true;
      };
    };
  };
}
