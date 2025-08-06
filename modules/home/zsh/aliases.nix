{...}: {
  # Shell aliases configuration
  home.shellAliases = {
    # ------------ ls -> eza ------------
    ls = "eza";
    l = "eza --color=always --long --icons=always --git --no-time --no-user --no-permissions --no-filesize --dereference";
    la = "eza --all --color=always --long --icons=always --git --no-time --no-user --no-permissions --no-filesize --dereference";
    ll = "eza --long --header --git --icons=always";
    lla = "eza --all --long --header --git --icons=always";
    tree = "eza -T";

    # ------------ grep -> ripgrep ------------
    grep = "rg";

    # ------------ diff -> delta ------------
    diff = "delta";

    # ------------ cd ------------
    ".." = "cd ..";
    "..." = "cd ../..";
    "..3" = "cd ../../..";
    "..4" = "cd ../../../..";
    "..5" = "cd ../../../../..";

    # git
    lg = "lazygit";

    ff = "fastfetch";

    du = "dua";
    df = "duf --hide-mp '/dev, *ystem*, /private*, /nix*'";

    ts = "tailscale";
    j = "just";
    oc = "bunx opencode-ai@latest";

    no = "optnix-fzf";
    ns = "nix-search-fzf";
  };
}
