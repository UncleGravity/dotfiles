-- Remember Folds
-- Snippet from:
-- https://github.com/AstroNvim/AstroNvim/blob/271c9c3f71c2e315cb16c31276dec81ddca6a5a6/lua/astronvim/autocmds.lua#L98-L120

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local view_group = augroup("auto_view", { clear = true })
autocmd({ "BufWinLeave", "BufWritePost", "WinLeave" }, {
  desc = "Save view with mkview for real files",
  group = view_group,
  callback = function(args)
    if vim.b[args.buf].view_activated then vim.cmd.mkview { mods = { emsg_silent = true } } end
  end,
})
autocmd("BufWinEnter", {
  desc = "Try to load file view if available and enable view saving for real files",
  group = view_group,
  callback = function(args)
    if not vim.b[args.buf].view_activated then
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
      local ignore_filetypes = { "gitcommit", "gitrebase", "svg", "hgcommit" }
      if buftype == "" and filetype and filetype ~= "" and not vim.tbl_contains(ignore_filetypes, filetype) then
        vim.b[args.buf].view_activated = true
        vim.cmd.loadview { mods = { emsg_silent = true } }
      end
    end
  end,
})