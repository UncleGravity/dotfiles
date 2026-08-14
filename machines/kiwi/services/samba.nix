{
  config,
  hostname,
  pkgs,
  username,
  ...
}: let
  lanInterface = "enp117s0";
in {
  clan.core.vars.generators.samba = {
    prompts.password = {
      description = "Samba password for ${username}";
      type = "hidden";
      persist = true;
    };
    files.password = {
      owner = "root";
      group = "root";
      mode = "0600";
      restartUnits = ["samba-password.service"];
    };
    runtimeInputs = [pkgs.coreutils];
    script = ''
      if [[ ! -s "$out/password" ]]; then
        echo "Samba password must not be empty" >&2
        exit 1
      fi

      originalSize="$(wc -c < "$out/password")"
      singleLineSize="$(tr -d '\r\n' < "$out/password" | wc -c)"
      if [[ "$originalSize" -ne "$singleLineSize" ]]; then
        echo "Samba password must be a single line" >&2
        exit 1
      fi
    '';
  };

  services = {
    samba = {
      enable = true;
      openFirewall = false;
      nmbd.enable = false;
      winbindd.enable = false;

      settings = {
        global = {
          "server string" = hostname;
          "smb ports" = "445";
          "disable netbios" = "yes";

          "log level" = "1";
          "log file" = "/var/log/samba/log.%m";
          "max log size" = "1000";

          "fruit:aapl" = "yes";
          "deadtime" = "30";

          "load printers" = "no";
          "printing" = "bsd";
          "printcap name" = "/dev/null";
          "disable spoolss" = "yes";
        };

        nas = {
          path = "/srv/share";
          "comment" = "All the NAS folders";
          "read only" = "no";
          "valid users" = username;
          "vfs objects" = "catia fruit streams_xattr";
          "veto files" = "/._*/.DS_Store/.Trashes";
        };
      };
    };

    samba-wsdd = {
      enable = true;
      openFirewall = false;
      interface = lanInterface;
    };

    avahi = {
      enable = true;
      openFirewall = false;
      allowInterfaces = [lanInterface];
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
      };
      extraServiceFiles.smb = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
        </service-group>
      '';
    };
  };

  networking.firewall.interfaces.${lanInterface} = {
    allowedTCPPorts = [
      445 # SMB file sharing
      5357 # wsdd: discovery in Windows Explorer
    ];
    allowedUDPPorts = [
      3702 # wsdd: WS-Discovery multicast
      5353 # avahi/mDNS: discovery in macOS Finder
    ];
  };

  systemd.services.samba-password = {
    description = "Provision the Samba user password";
    before = ["samba-smbd.service"];
    requiredBy = ["samba-smbd.service"];
    path = [config.services.samba.package];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      password="$(<${config.clan.core.vars.generators.samba.files.password.path})"
      printf '%s\n%s\n' "$password" "$password" | smbpasswd -a -s ${username}
    '';
  };
}
