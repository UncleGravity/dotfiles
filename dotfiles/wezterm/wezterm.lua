local wezterm = require("wezterm")
local theme_switcher = require("theme_switcher")
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.front_end = "WebGpu"

local mocha = {
  rosewater = '#f5e0dc',
  flamingo = '#f2cdcd',
  pink = '#f5c2e7',
  mauve = '#cba6f7',
  red = '#f38ba8',
  maroon = '#eba0ac',
  peach = '#fab387',
  yellow = '#f9e2af',
  green = '#a6e3a1',
  teal = '#94e2d5',
  sky = '#89dceb',
  sapphire = '#74c7ec',
  blue = '#89b4fa',
  lavender = '#b4befe',
  text = '#cdd6f4',
  subtext1 = '#bac2de',
  subtext0 = '#a6adc8',
  overlay2 = '#9399b2',
  overlay1 = '#7f849c',
  overlay0 = '#6c7086',
  surface2 = '#585b70',
  surface1 = '#45475a',
  surface0 = '#313244',
  base = '#1f1f28',
  mantle = '#181825',
  crust = '#11111b',
}

local colorscheme = {
  foreground = mocha.text,
  background = mocha.base,
  cursor_bg = mocha.rosewater,
  cursor_border = mocha.rosewater,
  cursor_fg = mocha.crust,
  selection_bg = mocha.surface2,
  selection_fg = mocha.text,
  ansi = {
     '#0C0C0C', -- black
     '#C50F1F', -- red
     '#13A10E', -- green
     '#C19C00', -- yellow
     '#0037DA', -- blue
     '#881798', -- magenta/purple
     '#3A96DD', -- cyan
     '#CCCCCC', -- white
  },
  brights = {
     '#767676', -- black
     '#E74856', -- red
     '#16C60C', -- green
     '#F9F1A5', -- yellow
     '#3B78FF', -- blue
     '#B4009E', -- magenta/purple
     '#61D6D6', -- cyan
     '#F2F2F2', -- white
  },
  tab_bar = {
     background = 'rgba(0, 0, 0, 0.4)',
     active_tab = {
        bg_color = mocha.surface2,
        fg_color = mocha.text,
     },
     inactive_tab = {
        bg_color = mocha.surface0,
        fg_color = mocha.subtext1,
     },
     inactive_tab_hover = {
        bg_color = mocha.surface0,
        fg_color = mocha.text,
     },
     new_tab = {
        bg_color = mocha.base,
        fg_color = mocha.text,
     },
     new_tab_hover = {
        bg_color = mocha.mantle,
        fg_color = mocha.text,
        italic = true,
     },
  },
  visual_bell = mocha.surface0,
  indexed = {
     [16] = mocha.peach,
     [17] = mocha.rosewater,
  },
  scrollbar_thumb = mocha.surface2,
  split = mocha.overlay0,
  compose_cursor = mocha.flamingo, -- nightbuild only
}

-- THEME
config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = 'Dracula (Official)'
config.color_scheme = 'Apple System Colors'
-- config.colors = colorscheme

-- FONT
config.font = wezterm.font("MesloLGS NF")
config.font_size = 13
-- config.freetype_load_target = "Light"
-- config.freetype_render_target = "HorizontalLcd"
config.freetype_load_flags = 'NO_HINTING'

-- WINDOW
config.hide_tab_bar_if_only_one_tab = true
-- config.enable_tab_bar = false
-- config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 90

-- Bind a key to trigger the theme switcher
config.keys = {
  {key="t", mods="CTRL|SHIFT", action=wezterm.action_callback(function(window, pane)
    theme_switcher.theme_switcher(window, pane)
  end)},
}

-- ??
wezterm.on('update-right-status', function(window, pane)
  -- "Wed Mar 3 08:14"
  local date = wezterm.strftime '%a %b %-d %H:%M '

  local bat = ''
  for _, b in ipairs(wezterm.battery_info()) do
    bat = '🔋 ' .. string.format('%.0f%%', b.state_of_charge * 100)
  end

  window:set_right_status(wezterm.format {
    { Text = bat .. '   ' .. date },
  })
end)

-- and finally, return the configuration to wezterm
return config