require('lualine').setup {
    options = {
        -- theme = 'gruvbox-material',
        theme = 'auto',
        globalstatus = true,
        -- ignore_focus = { 'neo-tree' },
        -- component_separators = { left = '', right = '' },
        -- section_separators = { left = '', right = '' },
    },
    sections = {
        lualine_a = {
            { 'mode' },
        },
        lualine_b = {
            { 'branch' },
            { 'diff' },
            { 'diagnostics' },
            { -- Show @recording messages
                require('noice').api.statusline.mode.get,
                cond = require('noice').api.statusline.mode.has,
                color = { fg = '#ff9e64' },
            },
            { 'filename', path = 3 },
        },
        lualine_c = {},
        lualine_x = {
            { 'encoding' },
            { 'filetype' },
        },
    },
}
