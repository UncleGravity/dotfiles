-- Taken from https://github.com/rachartier/tiny-inline-diagnostic.nvim
local function hex_to_rgb(hex)
  if hex == nil or hex == 'None' then
    return { 0, 0, 0 }
  end

  hex = hex:gsub('#', '')
  hex = string.lower(hex)

  return {
    tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16),
  }
end

-- Taken from https://github.com/rachartier/tiny-inline-diagnostic.nvim
---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
local function blend(foreground, background, alpha)
  alpha = type(alpha) == 'string' and (tonumber(alpha, 16) / 0xff) or alpha

  local fg = hex_to_rgb(foreground)
  local bg = hex_to_rgb(background)

  local blend_channel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format('#%02x%02x%02x', blend_channel(1), blend_channel(2), blend_channel(3)):upper()
end

return {
  {
    'rebelot/kanagawa.nvim',
    lazy = true,
    priority = 1000,
    opts = {
      commentStyle = { italic = false, bold = false },
      keywordStyle = { italic = false, bold = false },
      statementStyle = { italic = false, bold = false },
      functionStyle = { italic = false, bold = false },
      typeStyle = { italic = false, bold = false },
      background = { dark = 'dragon', light = 'lotus' },
      colors = {
        theme = {
          all = {
            ui = { bg_gutter = 'none' },
            diff = {
              add = 'none',
              change = 'none',
              delete = 'none',
              text = 'none',
            },
          },
        },
      },
      overrides = function(colors)
        local theme = colors.theme
        local palette = colors.palette

        return {
          -- Statusline
          StatusLine = { bg = theme.ui.bg_p1, fg = theme.syn.fun },
          --- modes
          StatusLineAccent = { bg = 'none', fg = palette.sakuraPink },
          StatusLineInsertAccent = { bg = 'none', fg = palette.springGreen },
          StatusLineVisualAccent = { bg = 'none', fg = palette.peachRed },
          StatusLineReplaceAccent = { bg = 'none', fg = palette.carpYellow },
          StatusLineCmdLineAccent = { bg = 'none', fg = palette.crystalBlue },
          StatusLineTerminalAccent = { bg = 'none', fg = palette.fujiGray },
          --- gitsigns
          StatusLineGitSignsAdd = { bg = theme.ui.bg_p1, fg = theme.vcs.added },
          StatusLineGitSignsChange = { bg = theme.ui.bg_p1, fg = theme.vcs.changed },
          StatusLineGitSignsDelete = { bg = theme.ui.bg_p1, fg = theme.vcs.removed },
          --- diagnostics
          StatusLineDiagnosticSignError = { bg = theme.ui.bg_p1, fg = palette.peachRed },
          StatusLineDiagnosticSignWarn = { bg = theme.ui.bg_p1, fg = theme.diag.warning },
          StatusLineDiagnosticSignInfo = { bg = theme.ui.bg_p1, fg = theme.diag.info },
          StatusLineDiagnosticSignHint = { bg = theme.ui.bg_p1, fg = theme.diag.hint },
          StatusLineDiagnosticSignOk = { bg = theme.ui.bg_p1, fg = theme.diag.ok },

          --- floats
          NormalFloat = { bg = theme.ui.bg_p1 },
          FloatBorder = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 },
          FloatTitle = { fg = theme.ui.shade0, bg = theme.ui.bg_p1, bold = false },
          FloatFooter = { fg = theme.ui.nontext, bg = theme.ui.bg_p1 },

          --- daignostics
          DiagnosticError = { fg = palette.peachRed },
          DiagnosticSignError = { fg = palette.peachRed },
          DiagnosticFloatingError = { fg = palette.peachRed },
          DiagnosticUnderlineError = { sp = palette.peachRed },
          DiagnosticVirtualTextError = { fg = palette.peachRed, bg = blend(palette.peachRed, theme.ui.bg, 0.10) },
          DiagnosticVirtualTextHint = { fg = theme.diag.hint, bg = blend(theme.diag.hint, theme.ui.bg, 0.10) },
          DiagnosticVirtualTextInfo = { fg = theme.diag.info, bg = blend(theme.diag.info, theme.ui.bg, 0.10) },
          DiagnosticVirtualTextOk = { fg = theme.diag.ok, bg = blend(theme.diag.ok, theme.ui.bg, 0.10) },
          DiagnosticVirtualTextWarn = { fg = theme.diag.warning, bg = blend(theme.diag.warning, theme.ui.bg, 0.10) },

          --- popups
          Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 }, -- add `blend = vim.o.pumblend` to enable transparency
          PmenuSel = { fg = 'NONE', bg = theme.ui.bg_p2 },
          PmenuSbar = { bg = theme.ui.bg_m1 },
          PmenuThumb = { bg = theme.ui.bg_p2 },

          --- misc
          ModeMsg = { fg = theme.syn.comment, bold = false },
          WinSeparator = { fg = theme.ui.bg_p2 },
          TelescopeSelection = { bg = theme.ui.bg_p2 },
          Cursor = { bg = 'none' },
          CursorLine = { bg = 'none' },
          CursorLineNr = { bold = false },
          Title = { bold = false },
          Boolean = { bold = false },
          MatchParen = { bold = false, bg = theme.ui.bg_p2 },
          IblIndent = { fg = theme.ui.bg_p2 },
          IblScope = { fg = theme.ui.whitespace },
          ['@variable.builtin'] = { link = 'Special' },
          ['@lsp.typemod.function.readonly'] = { link = 'Function' },
          ['@boolean'] = { link = 'Boolean' },
          ['@keyword.operator'] = { link = 'Keyword' },
          ['@string.escape'] = { link = 'PrePoc' },
          typescriptParens = { bg = 'none' },
        }
      end,
    },
  },

--   {
--     'mcchrish/zenbones.nvim',
--     dependencies = { 'rktjmp/lush.nvim' },
--     event = 'VeryLazy',
--   },

  {
    'ellisonleao/gruvbox.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('gruvbox').setup {
        terminal_colors = true,
        undercurl = true,
        underline = true,
        bold = false,
        italic = {
          strings = false,
          emphasis = false,
          comments = false,
          operators = false,
          folds = false,
        },
        strikethrough = true,
        invert_selection = false,
        invert_signs = false,
        invert_tabline = false,
        invert_intend_guides = false,
        inverse = true,
        contrast = '',
        palette_overrides = {},
        overrides = {},
        dim_inactive = false,
        transparent_mode = true,
      }
    --   vim.cmd 'colorscheme gruvbox'
    end,
  },

  {
    'sainnhe/gruvbox-material',
    name = 'gruvbox-material',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.gruvbox_material_better_performance = 1
      -- Fonts
      vim.g.gruvbox_material_disable_italic_comment = 1
      vim.g.gruvbox_material_enable_italic = 0
      vim.g.gruvbox_material_enable_bold = 0
      vim.g.gruvbox_material_transparent_background = 1
      -- Themes
      -- vim.g.gruvbox_material_foreground = 'mix'
      vim.g.gruvbox_material_background = 'hard'
      -- vim.g.gruvbox_material_ui_contrast = 'high' -- The contrast of line numbers, indent lines, etc.
      vim.g.gruvbox_material_float_style = 'dim' -- Background of floating windows

      vim.cmd.colorscheme 'gruvbox-material'

      --------------------------------------------------------------------------------------
      -- Custom highlights
      local currentTheme = vim.g.colors_name

      if currentTheme == 'gruvbox-material' then
        vim.api.nvim_create_autocmd('VimEnter', {
          callback = function()
            local configuration = vim.fn['gruvbox_material#get_configuration']()
            local palette = vim.fn['gruvbox_material#get_palette'](configuration.background, configuration.foreground, configuration.colors_override)

            local isDarkTheme = vim.o.background == 'dark'

            local highlights_groups = {
              FoldColumn = { bg = 'none', fg = palette.grey0[1] },
              SignColumn = { bg = 'none' },
              EndOfBuffer = { bg = 'none', fg = palette.grey0[1] },
              Normal = { bg = 'none', fg = palette.fg0[1] },
              NormalNC = { bg = 'none' },
              NormalFloat = { bg = 'none', fg = palette.fg0[1] },
              FloatBorder = { bg = 'none' },
              FloatTitle = { bg = 'none', fg = palette.orange[1] },
              TelescopeTitle = { bg = 'none', fg = palette.fg0[1] },
              TelescopeBorder = { bg = 'none', fg = palette.fg0[1] },
              TelescopeNormal = { fg = 'none' },
              TelescopePromptNormal = { bg = 'none', fg = palette.fg0[1] },
              TelescopeResultsNormal = { bg = 'none', fg = palette.fg0[1] },
              TelescopeResultsDiffUntracked = { bg = 'none', fg = palette.orange[1] },
              TelescopeSelection = { bg = palette.bg5[1], fg = palette.fg0[1] },
              TelescopePreviewDirectory = { fg = palette.red[1] },
              TelescopePromptCounter = { bg = 'none', fg = palette.fg0[1] },
              TelescopeMatching = { bold = false, bg = 'none', fg = palette.green[1] },
              -- Visual = {bg = palette.bg_visual_red[1]},
              Cursor = { bg = isDarkTheme and palette.bg_red[1] or palette.fg0[1], fg = palette.bg_dim[1] },
              CursorReset = { bg = palette.fg0[1], fg = palette.bg_dim[1] },
            --   ColorColumn = { bg = palette.grey0[1] },
              ColorColumn = { bg = palette.bg0[1] },
              CursorLine = { bg = palette.bg5[1], blend = 25 },
              -- GitSignsAdd = { bg = 'none', fg = palette.green[1] },
              -- GitSignsChange = { bg = 'none', fg = palette.yellow[1] },
              -- GitSignsDelete = { bg = 'none', fg = palette.red[1] },
              -- DiffAdd = { bg = 'none', fg = palette.green[1] },
              -- DiffChange = { bg = 'none', fg = palette.yellow[1] },
              -- DiffDelete = { bg = 'none', fg = palette.red[1] },
              -- DiffText = { bg = 'none', fg = palette.blue[1] },
              -- Make MatchParen more visible
              MatchParen = { bg = palette.bg_yellow[1], fg = palette.bg0[1], bold = true },
            }

            for group, styles in pairs(highlights_groups) do
              vim.api.nvim_set_hl(0, group, styles)
            end
          end,
        })
      end
    end,
  },
}

-- return {
--   'sainnhe/gruvbox-material',
--   priority = 1000,
--   config = function()
--     vim.o.background = 'dark' -- or "light" for light mode
--
--     vim.g.gruvbox_material_better_performance = 1
--
--     -- Fonts
--     vim.g.gruvbox_material_disable_italic_comment = 1
--     vim.g.gruvbox_material_enable_italic = 1
--     vim.g.gruvbox_material_enable_bold = 0
--     vim.g.gruvbox_material_transparent_background = 2
--
--     -- Themes
--     vim.g.gruvbox_material_foreground = 'hard'
--     vim.g.gruvbox_material_background = 'hard'
--     -- vim.g.gruvbox_material_ui_contrast = 'low' -- The contrast of line numbers, indent lines, etc.
--     vim.g.gruvbox_material_float_style = 'dim' -- Background of floating windows
--
--     vim.cmd('colorscheme gruvbox-material')
--
--     -- vim.cmd "let g:gruvbox_material_background= 'hard'"
--     -- vim.cmd 'let g:gruvbox_material_transparent_background=2'
--     -- vim.cmd "let g:gruvbox_material_cursor='red'"
--     -- vim.cmd 'let g:gruvbox_material_diagnostic_line_highlight=1'
--     -- -- vim.cmd("let g:gruvbox_material_diagnostic_virtual_text='colored'")
--     -- vim.cmd 'let g:gruvbox_material_enable_bold=1'
--     -- vim.cmd 'let g:gruvbox_material_enable_italic=1'
--     -- vim.cmd [[colorscheme gruvbox-material]] -- Set color scheme
--     --
--     -- changing bg and border colors
--     vim.api.nvim_set_hl(0, "FloatBorder", { link = "Normal" })
--     vim.api.nvim_set_hl(0, 'LspInfoBorder', { link = 'Normal' })
--     vim.api.nvim_set_hl(0, 'NormalFloat', { link = 'Normal' })
--   end,
-- }
