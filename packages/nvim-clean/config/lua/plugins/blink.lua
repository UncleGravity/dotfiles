-- ╭───────────────────────────╮
-- │ blink.cmp                                   │
-- ╰───────────────────────────╯
require('blink.cmp').setup({
    keymap     = {
        preset    = 'default',
        ['<C-n>'] = { 'select_next', 'show' },                    -- try next; if no menu, open it
        ['<C-p>'] = { 'select_prev', 'show' },                    -- symmetric previous
    },
    sources    = { default = { 'lsp' } },                         -- only LSP for now
    fuzzy      = { implementation = 'prefer_rust_with_warning' }, -- typo-tolerant
    signature  = { enabled = true },                              -- Experimental
    completion = {
        menu = {
            max_height = 20, -- let it expand to 20 items if there’s room
            draw = {
                columns = {
                    { "label",     "label_description", gap = 1 },
                    { "kind_icon", "kind" }
                },
            }
        },
        documentation = {
            auto_show = true,       -- show whenever an item becomes selected
            auto_show_delay_ms = 0, -- instant
        },
    },
    cmdline    = {
        keymap = { preset = 'inherit' },
        completion = {
            ghost_text = { enabled = true },
            menu = { auto_show = true }
        },
    }
})
