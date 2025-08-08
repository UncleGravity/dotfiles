----------------------------------------------------------------------------------------------------
---  which-key.nvim
require('which-key').setup({
    preset = "helix",
    defaults = {},
    spec = {
        {
            mode = { 'n', 'v' },
            { '<leader>a', group = '[a]i', icon = { icon = ' ', color = 'azure' } },
            { '<leader>b', group = '[b]uffer', icon = { icon = '󰓩 ', color = 'orange' } },
            { '<leader>d', group = '[d]ebug', icon = { icon = ' ', color = 'red' } },
            { '<leader>g', group = '[g]it', mode = { 'n', 'v' }, icon = { icon = ' ', color = 'orange' } },
            { '<leader>l', group = '[l]sp', icon = { icon = ' ', color = 'azure' } },
            { '<leader>q', group = '[q]uit', icon = { icon = ' ', color = 'green' } },
            { '<leader>s', group = '[s]earch', icon = { icon = ' ', color = 'azure' } },
            { '<leader>u', group = '[u]i', icon = { icon = '󰙵 ', color = 'cyan' } },
            { '[', group = 'prev' },
            { ']', group = 'next' },
            { 'g', group = 'goto' },
            { 'z', group = 'fold' },

            -- better descriptions
            { '<leader>e', desc = 'Toggle Explorer', icon = { icon = '󰙅', color = 'blue' } },
            { '<leader>sg', desc = 'Git', icon = { icon = ' ', color = 'orange' } },
            { 'gx', desc = 'Open with system app' },
        },
    },
})

-- Keymaps for which-key itself
vim.keymap.set('n', '<c-w><space>', function()
    require('which-key').show({ keys = '<c-w>', loop = true })
end, { desc = 'Window Hydra Mode (which-key)' })
