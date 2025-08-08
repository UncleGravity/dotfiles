More info: https://gpanders.com/blog/whats-new-in-neovim-0-11/
Most LSPs don't require any configuration. As they are already defined in nvim-lspconfig.

For custom config:
If the lsp is called "ABC", make a file called "ABC.lua" and return a config table.
```lua
return {
  cmd = { 'lua-language-server' },
  --- etc
}
```
