-- Consider using mini.jump + mini.jump2d
return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  vscode = true,
  ---@type Flash.Config
  opts = {},
  -- stylua: ignore
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
  },
}
