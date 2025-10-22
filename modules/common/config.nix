{
  config,
  lib,
  pkgs,
  ...
}: {
  options.my = {
    profile = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "Username for the system";
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for the system";
      };
      isVM = lib.mkOption {
        type = lib.types.bool;
        description = "Flag indicating if the system is a virtual machine";
      };
      system = lib.mkOption {
        type = lib.types.enum [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
        description = "System architecture";
      };
      darwinStateVersion = lib.mkOption {
        type = lib.types.ints.positive;
        description = "System state version";
      };
      nixosStateVersion = lib.mkOption {
        type = lib.types.strMatching "[0-9]{2}\\.[0-9]{2}";
        description = "NixOS version in YY.MM format";
      };
      homeStateVersion = lib.mkOption {
        type = lib.types.strMatching "[0-9]{2}\\.[0-9]{2}";
        description = "Home state version in YY.MM format";
      };
    };

    global = {
      binaryCaches = {
        substituters = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "https://nix-community.cachix.org?priority=41"
            "https://numtide.cachix.org?priority=42"
            "https://unclegravity-nix.cachix.org?priority=43"
          ];
          description = "List of binary cache substituters";
        };

        trustedPublicKeys = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
            "unclegravity-nix.cachix.org-1:fnXTPHMhvKwMrqyU/z00iyf8SkUuK0YP2PpCYb1t3nI="
          ];
          description = "List of trusted public keys for binary caches";
        };
      };

      ssh = {
        publicKeys = lib.mkOption {
          type = with lib.types; listOf str;
          default = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzI2b0Spyh5wIm6mLVPKaDonuea0a7sdNFGN2V1HTRq" # Master
            "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLpjzihuPI+t7xYjznPNLALMCunS2WKw/cqYRMAG1YILTGiLmdYRWck9Ic7muK7SXWj0XP8nWTze1iRhA/iTyxA=" # CRISPR (termius)
          ];
          description = "List of SSH public keys for user authorization";
        };
      };

      locale = {
        timeZone = lib.mkOption {
          type = lib.types.str;
          default = "Asia/Taipei";
          description = "System timezone";
        };

        defaultLocale = lib.mkOption {
          type = lib.types.str;
          default = "en_US.UTF-8";
          description = "Default system locale";
        };
      };
    };
  };
}
