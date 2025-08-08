--- Options
require('config.keymaps')
require('config.lsp')
require('config.options')

--- Plugins
require('plugins.blink')
require('plugins.gitsigns')
require('plugins.lualine')
require('plugins.mini')
require('plugins.noice')
require('plugins.scrollview')
require('plugins.snacks')
require('plugins.treesitter')
require('plugins.which-key')

----------------------------------------------------------------------------------------------------
-- Theme
require('kanagawa').setup({
    compile = true, -- `:KanagawaCompile`
    colors = { theme = { all = { ui = { bg_gutter = 'none' } } } }
})
vim.cmd("colorscheme kanagawa")

----------------------------------------------------------------------------------------------------
---  Flash
require('flash').setup({ modes = { char = { enabled = false, }, }, })
vim.keymap.set({ "n", "x", "o" }, "gw", function() -- just like helix = gw
    require("flash").jump()
end, { desc = "Flash Jump" })

----------------------------------------------------------------------------------------------------
--- Fidget
require('fidget').setup({
    notification = {
        override_vim_notify = true, -- Automatically override vim.notify() with Fidget
    },
})
----------------------------------------------------------------------------------------------------
--- TODO: comments
require('todo-comments').setup({
    signs = false
})
