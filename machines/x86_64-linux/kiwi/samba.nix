{
  lib,
  config,
  pkgs,
  hostname,
  username,
  ...
}: {
  environment.systemPackages = [config.services.samba.package];

  # SOPS secret for samba password
  sops.secrets."samba/password" = {
    mode = "0600";
  };

  # ---------------------------------------------------------------------------
  # Samba - NAS file sharing
  # Inspo: https://github.com/notthebee/nix-config/blob/d1e172b521f5a0a027cf9b621e516e8caed74199/homelab/samba/default.nix
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "${hostname}";
        "netbios name" = "${hostname}";
        "security" = "user";
        "invalid users" = ["root"];
        "guest account" = "nobody";
        "map to guest" = "bad user";

        # Logging
        "log level" = "1";
        "log file" = "/var/log/samba/log.%m";
        "max log size" = "1000";

        # Apple
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:aapl" = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "0";
        "fruit:time machine max num files" = "0";
        "fruit:time machine max num folders" = "0";

        # Performance
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY";
        "use sendfile" = "yes";
        "read raw" = "yes";
        "write raw" = "yes";
        "min receivefile size" = "16384";
        "aio read size" = "16384";
        "aio write size" = "16384";
        "server multi channel support" = "yes";

        # Additional performance tweaks
        "deadtime" = "30";
        "getwd cache" = "yes";
        "lpq cache time" = "30";
        "max smbd processes" = "0"; # 0 = unlimited

        # # Disable unused services
        # "load printers" = "no";
        # "printing" = "bsd";
        # "printcap name" = "/dev/null";
        # "disable spoolss" = "yes";
      };
      # Main NAS share for general access
      nas = {
        path = "/nas";
        "comment" = "All the NAS folders";
        "preserve case" = "yes";
        "short preserve case" = "yes";
        "browseable" = "yes";
        "writeable" = "yes";
        "guest ok" = "no";
        "create mask" = "0664"; # Group-writable files
        "directory mask" = "0775"; # Group-writable directories
        "inherit acls" = "yes";
        "veto files" = "/._*/.DS_Store/.Trashes";
        "valid users" = "${username} @share";
      };
    };
  };

  # Enable samba-wsdd for Windows/Android discovery
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Enable avahi for better network discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
    extraServiceFiles = {
      # Add samba service to avahi
      smb = ''
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

  # ---------------------------------------------------------------------------
  # Set samba password
  system.activationScripts.sambaUser = {
    deps = [
      "users" # Wait for users to be available
      "setupSecrets" # Wait for secrets to be available
    ];
    text = ''
      # Wait for samba to be ready
      ${pkgs.systemd}/bin/systemctl is-active --quiet samba-smbd || ${pkgs.systemd}/bin/systemctl start samba-smbd
      sleep 2

      # Read password from secure location
      smb_password=$(cat "${config.sops.secrets."samba/password".path}")

      # Add/update user
      echo -e "$smb_password\n$smb_password\n" | ${lib.getExe' pkgs.samba "smbpasswd"} -a -s ${username}
    '';
  };
}
