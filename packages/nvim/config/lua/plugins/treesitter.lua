local ts = require('nvim-treesitter')

-- New nvim-treesitter API: setup only configures install behavior.
ts.setup({})

-- Enable treesitter highlighting per-buffer when a parser exists.
local tsGroup = vim.api.nvim_create_augroup('nvim_nix_treesitter', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
    group = tsGroup,
    callback = function(args)
        local ok = pcall(vim.treesitter.start, args.buf)
        if ok then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})

-- Enable folding with treesitter.
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldtext = "v:lua.require('extra.foldtext')()"
vim.o.foldlevel = 99 -- Make sure nothing is folded when opening a file
