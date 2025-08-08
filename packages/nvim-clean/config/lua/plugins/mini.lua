----------------------------------------------------------------------------------------------------
---  mini.nvim
require('mini.basics').setup({
    options = {
        basic = true, -- Basic options ('number', 'ignorecase')
        -- extra_ui = true, -- Extra UI features ('winblend', 'cmdheight=0', ...)
        -- win_borders = 'double', -- ('single', 'double', ...)
    },

    mappings = {
        basic = true,                 -- Basic mappings (better 'jk', save with Ctrl+S, ...)
        option_toggle_prefix = [[\]], -- toggle common options ('wrap', 'spell', ...).
    },

    autocommands = { basic = true }, -- (highlight on yank, start Insert in terminal, ...)
    silent = false,                  -- Show non-error feedback
})

require('mini.splitjoin').setup({
    mappings = { toggle = 'gj' }
})

require('mini.tabline').setup({ tabpage_section = 'right' })
require('mini.move').setup()  -- Drag selections around, with Alt+<direction>
require('mini.pairs').setup() -- Auto surround  text with ()/{}/[]

----------------------------------------------------------------------------------------------------
-- require('mini.diff').setup({
--     view = {
--         style = 'sign', -- Force sign column style instead of number style
--     },
-- })
-- vim.keymap.set("n", "<leader>gp", function()
--     require('mini.diff').toggle_overlay()
-- end, { desc = "Git preview (toggle diff overlay)" })
