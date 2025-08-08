----------------------------------------------------------------------------------------------------
--- Noice.nvim
require('noice').setup({
    routes = {
        -- Show undo/redo messages in small notification
        {
            filter = {
                event = 'msg_show',
                any = {
                    { find = '%d+L, %d+B' },
                    { find = '; after #%d+' },
                    { find = '; before #%d+' },
                },
            },
            view = 'mini',
        },
        -- Show "recording macro" message
        {
            view = 'notify',
            filter = { event = 'msg_showmode' },
        },
    },
    lsp = {
        -- CTRL-K behavior
        hover = {
            silent = true, -- Don't show a message if hover is not available
        },
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
            -- ['cmp.entry.get_documentation'] = true, -- requires hrsh7th/nvim-cmp
        },
    },
    presets = {
        bottom_search = true,         -- use a classic bottom cmdline for search
        command_palette = true,       -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = true,            -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true,        -- add a border to hover docs and signature help
    },
})
