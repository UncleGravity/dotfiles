# Clan vars and identities

Nix modules declare var generators. Their outputs are named
`<generator>/<file>` and stored under `vars/per-machine/<host>/` or
`vars/shared/`. Public values use `value`; secrets use encrypted `secret`
files.

```sh
clan machines list # list all hosts
clan vars list <host> # list all secrets for a host (censored)
clan vars get <host> <generator>/<file> # print specific secret
clan vars check <host>
```

Each enrolled machine has a unique Age identity. NixOS stores it at
`/var/lib/sops-nix/key.txt` and loads its SSH host key from Clan vars at
`/run/secrets/vars/openssh/ssh.id_ed25519`.

Installation reuses these identities. Regenerating an existing machine's
`openssh` var changes its SSH fingerprint.
