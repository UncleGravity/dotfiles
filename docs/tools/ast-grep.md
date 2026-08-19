# ast-grep

```sh
ast-grep run -l nix -p 'lib.mkIf $C $B' machines/      # search
ast-grep run -l nix -p 'X' --debug-query=ast /dev/null # why won't my pattern parse
ast-grep run -l lua -p 'f($A)' --rewrite 'g($A)' path/ # rewrite (dry-run; -U to apply)
ast-grep run -l nix -p '...' --json=compact | jq       # pipe to tooling
ast-grep scan --inline-rules '<yaml>' path/            # one-off rule, no config file
ast-grep scan -c sgconfig.yml path/                    # run a checked-in ruleset
```
