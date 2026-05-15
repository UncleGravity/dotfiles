{config, ...}: {
  # To edit:
  #   sops machines/nixos/kiwi/services/guacamole/user-mapping.xml.sops
  sops.secrets."guacamole/user-mapping.xml" = {
    sopsFile = ./user-mapping.xml.sops;
    format = "binary";
    owner = "guacamole-server";
    group = "guacamole-server";
    mode = "0644";
  };

  my.guacamole = {
    enable = true;
    userMappingFile = config.sops.secrets."guacamole/user-mapping.xml".path;
  };
}
