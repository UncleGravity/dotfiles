return {
    cmd          = { "nixd" },
    root_markers = { "flake.nix", "shell.nix", "default.nix" },
    filetypes    = { "nix" },
    settings     = {
        diagnostic = {
            suppress = { "sema-extra-with" }
        },
        options = {
            -- ["home-manager"] = {
            --     expr =
            --     "(builtins.getFlake (builtins.toString ./.)).darwinConfigurations.banana.options.home-manager.users.type.getSubOptions []"
            -- },
            darwin = {
                expr = "(builtins.getFlake (builtins.toString ./.)).darwinConfigurations.banana.options"
            },
            nixos = {
                expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.kiwi.options"
            },
            flake = {
                expr = "(builtins.getFlake (builtins.toString ./.)).outputs"
            }
        }
    }
}
