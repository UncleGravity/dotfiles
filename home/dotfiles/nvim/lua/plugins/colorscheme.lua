-- return {
--   'ellisonleao/gruvbox.nvim',
--   priority = 1000,
--   config = function()
--     require('gruvbox').setup {
--       terminal_colors = true,
--       undercurl = true,
--       underline = true,
--       bold = true,
--       italic = {
--         strings = true,
--         emphasis = true,
--         comments = true,
--         operators = false,
--         folds = true,
--       },
--       strikethrough = true,
--       invert_selection = false,
--       invert_signs = false,
--       invert_tabline = false,
--       invert_intend_guides = false,
--       inverse = true,
--       contrast = '',
--       palette_overrides = {},
--       overrides = {},
--       dim_inactive = false,
--       transparent_mode = true,
--     }
--     vim.cmd 'colorscheme gruvbox'
--   end,
-- }

return {
	"sainnhe/gruvbox-material",
	priority = 1000,
	config = function()
		vim.o.background = "dark" -- or "light" for light mode
		vim.cmd("let g:gruvbox_material_background= 'hard'")
		vim.cmd("let g:gruvbox_material_transparent_background=2")
		vim.cmd("let g:gruvbox_material_cursor='red'")
		vim.cmd("let g:gruvbox_material_diagnostic_line_highlight=1")
		-- vim.cmd("let g:gruvbox_material_diagnostic_virtual_text='colored'")
		vim.cmd("let g:gruvbox_material_enable_bold=1")
		vim.cmd("let g:gruvbox_material_enable_italic=1")
		vim.cmd([[colorscheme gruvbox-material]]) -- Set color scheme
		-- changing bg and border colors
		-- vim.api.nvim_set_hl(0, "FloatBorder", { link = "Normal" })
		vim.api.nvim_set_hl(0, "LspInfoBorder", { link = "Normal" })
		vim.api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })

	end,
}
