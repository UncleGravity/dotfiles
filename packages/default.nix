{
  clanCli,
  pkgs,
  self,
}: let
  inherit (pkgs) lib;

  optnix = pkgs.callPackage ./optnix.nix {inherit self;};
  nvim = pkgs.callPackage ./nvim {};

  common = {
    bootstrap = pkgs.callPackage ./bootstrap.nix {};
    clan = pkgs.callPackage ./clan.nix {inherit clanCli;};
    clan-unwrapped = clanCli;
    optnix-fzf = pkgs.callPackage ./optnix-fzf.nix {inherit optnix;};
    nix-search-fzf = pkgs.callPackage ./nix-search-fzf.nix {};
    push = pkgs.callPackage ./push.nix {};
    t = pkgs.callPackage ./t.nix {inherit nvim;};
    helix = pkgs.callPackage ./helix {};
    inference = pkgs.callPackage ./inference/nix/package.nix {};
    inherit nvim optnix;
  };
in
  common
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    decrypt = pkgs.callPackage ./decrypt.nix {};
    encrypt = pkgs.callPackage ./encrypt.nix {};
  }
