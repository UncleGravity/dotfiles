{
  pkgs,
  self,
}: let
  inherit (pkgs) lib;

  optnix = pkgs.callPackage ./optnix.nix {inherit self;};
  common = {
    bootstrap = pkgs.callPackage ./bootstrap.nix {};
    optnix-fzf = pkgs.callPackage ./optnix-fzf.nix {inherit optnix;};
    nix-search-fzf = pkgs.callPackage ./nix-search-fzf.nix {};
    push = pkgs.callPackage ./push.nix {};
    t = pkgs.callPackage ./t.nix {};
    nvim = pkgs.callPackage ./nvim {};
    helix = pkgs.callPackage ./helix {};
    inference = pkgs.callPackage ./inference/nix/package.nix {};
    inherit optnix;
  };
in
  common
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    decrypt = pkgs.callPackage ./decrypt.nix {};
    encrypt = pkgs.callPackage ./encrypt.nix {};
  }
