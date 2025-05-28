{ lib, config, pkgs, hostname, username, ... }:
{
  environment.systemPackages = [ config.services.samba.package ];
  
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
        "invalid users" = [ "root" ];
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      nas = {
        path = "/nas";
        "preserve case" = "yes";
        "short preserve case" = "yes";
        "browseable" = "yes";
        "writeable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "${username}";
        "fruit:aapl" = "yes";
        "vfs objects" = "catia fruit streams_xattr";
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
      "users"         # Wait for users to be available
      "setupSecrets"  # Wait for secrets to be available
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