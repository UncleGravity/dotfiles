{config, ...}: {
  sops.templates."networkmanager/wifi-speed.env".content = ''
    WIFI_SPEED_SSID="${config.sops.placeholder."wifi/ssid"}"
    WIFI_SPEED_PSK="${config.sops.placeholder."wifi/psk"}"
  '';

  networking.networkmanager.ensureProfiles.secrets.entries = [
    {
      file = config.sops.secrets."wifi/speed".path;
      key = "psk";
      matchId = "SPEED";
      matchSetting = "wifi";
      matchType = "wireguard";
    }
  ];

  networking.networkmanager.ensureProfiles.environmentFiles = [config.sops.templates."networkmanager/wifi-speed.env".path];

  networking.networkmanager.ensureProfiles.profiles = [
    {
      SPEED = {
        connection = {
          id = "$WIFI_SPEED_SSID";
          interface-name = "wlp116s0f0";
          type = "wifi";
          uuid = "bd396f97-f69d-4dc1-96e5-1c70d8a94ebc";
        };
        ipv4 = {
          method = "auto";
        };
        ipv6 = {
          addr-gen-mode = "default";
          method = "auto";
        };
        proxy = {};
        wifi = {
          hidden = "true";
          ssid = "$WIFI_SPEED_SSID";
        };
        wifi-security = {
          key-mgmt = "sae";
          psk = "$WIFI_SPEED_PSK";
        };
      };
    }
  ];
}
