{ pkgs, hostname, ... }:
{
  # ---------------------------------------------------------------------------
  # Samba - NAS file sharing
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "${hostname}";
        "netbios name" = "${hostname}";
        "security" = "user";
        "map to guest" = "bad user";
      };
      nas = {
        path = "/nas";
        browseable = "yes";
        writable = "yes";
        "guest ok" = "no";
        "read only" = "no";
        "valid users" = "angel";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.enable = true;
  networking.firewall.allowPing = true;

  # ---------------------------------------------------------------------------
  # Activation script to set Samba password for user 'angel'
  system.activationScripts.sambaUserAngel = {
    deps = [ "users" ]; # Ensure users are set up before this runs
    text = ''
      # Wait for passdb.tdb to be created if it's a new setup
      # and ensure samba service is available for smbpasswd
      # A more robust check might be needed for very first boot scenarios.
      sleep 5
      (echo "angel"; echo "angel") | ${pkgs.samba}/bin/smbpasswd -a -s angel
    '';
  };
}