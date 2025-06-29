-- `:Telescope colorscheme` to view all installed colorschemes

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
  -- kanagawa
  {
    'rebelot/kanagawa.nvim',
    -- enabled = false,
    lazy = false,
    priority = 1000,
    opts = {
      compile = true, -- `:KanagawaCompile`
      transparent = false,
      commentStyle = { italic = false, bold = false },
      keywordStyle = { italic = false, bold = false },
      statementStyle = { italic = false, bold = false },
      functionStyle = { italic = false, bold = false },
      typeStyle = { italic = false, bold = false },
      colors = { theme = { all = { ui = { bg_gutter = 'none' } } } },
      overrides = function(colors)
        local theme = colors.theme
        local palette = colors.palette
        --
        return {
          --- floats
          NormalFloat = { bg = 'none' },
          FloatBorder = { bg = 'none' },
          FloatTitle = { bg = 'none' },

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

          --- misc
          WinSeparator = { fg = theme.ui.bg_p2 },
        }
      end,
    },
    config = function(_, opts) -- Modified config function
      require('kanagawa').setup(opts)
      vim.cmd 'colorscheme kanagawa'
    end,
  },

  -- zenbones
  {
    'mcchrish/zenbones.nvim',
    enabled = false,
    dependencies = { 'rktjmp/lush.nvim' },
    event = 'VeryLazy',
  },

  -- gruvbox
  {
    'ellisonleao/gruvbox.nvim',
    enabled = false,
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

      -- Set highlight for MiniTablineFill
      vim.api.nvim_set_hl(0, 'MiniTablineFill', { bg = '#282828' })

      -- vim.cmd 'colorscheme gruvbox'
    end,
  },

  -- gruvbox-material
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
      -- Themes
      vim.g.gruvbox_material_background = 'hard'
      vim.g.gruvbox_material_foreground = 'dark'
      -- vim.g.gruvbox_material_ui_contrast = 'high' -- The contrast of line numbers, indent lines, etc.
      vim.g.gruvbox_material_float_style = 'dim' -- Background of floating windows

      vim.g.gruvbox_material_transparent_background = 2
      vim.g.gruvbox_material_menu_selection_background = 'orange' -- options `'grey'`, `'red'`, `'orange'`, `'yellow'`, `'green'``'aqua'`, `'blue'`, `'purple'`
      vim.g.gruvbox_material_current_word = 'high contrast background'
      vim.g.gruvbox_material_disable_terminal_colors = 1 -- Use built in terminal colors

      vim.g.gruvbox_material_diagnostic_virtual_text = 'colored'
      vim.g.material_diagnostic_text_highlight = 1
      vim.g.gruvbox_material_diagnostic_line_highlight = 1
      -- vim.cmd.colorscheme 'gruvbox-material'

      -- Set window separator width
      -- vim.opt.fillchars:append { vert = '█', horiz = '█', horizup = '█', horizdown = '█', vertleft = '█', vertright = '█' }

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
              -- FoldColumn = { bg = 'none', fg = palette.grey0[1] },
              -- SignColumn = { bg = 'none' },
              -- EndOfBuffer = { bg = 'none', fg = palette.grey0[1] },
              -- Normal = { bg = 'none', fg = palette.fg0[1] },
              -- NormalNC = { bg = 'none' },
              -- NormalFloat = { bg = 'none', fg = palette.fg0[1] },
              -- FloatBorder = { bg = 'none' },
              -- FloatTitle = { bg = 'none', fg = palette.orange[1] },
              WinSeparator = { fg = palette.grey1[1], bold = true },
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
              Cursor = { bg = isDarkTheme and palette.orange[1] or palette.red[1], fg = palette.bg0[1] },
              -- CursorReset = { bg = palette.fg0[1], fg = palette.bg_dim[1] },
              --   ColorColumn = { bg = palette.grey0[1] },
              -- ColorColumn = { bg = palette.bg0[1] },
              CursorLine = { bg = palette.bg5[1], blend = 25 },
              -- GitSignsAdd = { bg = 'none', fg = palette.green[1] },
              -- GitSignsChange = { bg = 'none', fg = palette.yellow[1] },
              -- GitSignsDelete = { bg = 'none', fg = palette.red[1] },
              -- DiffAdd = { bg = 'none', fg = palette.green[1] },
              -- DiffChange = { bg = 'none', fg = palette.yellow[1] },
              -- DiffDelete = { bg = 'none', fg = palette.red[1] },
              -- DiffText = { bg = 'none', fg = palette.blue[1] },
              -- MatchParen = { bg = palette.grey2[1], fg = palette.orange[1], bold = true },
              -- MiniTablineFill = { bg = palette.bg0[1] },
              MiniIndentscopeSymbol = { fg = palette.bg5[1] },
              -- MiniIndentscopeSymbolOff = { fg = palette.bg0[1] },
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
