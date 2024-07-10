local wezterm = require("wezterm")
local theme_switcher = require("theme_switcher")
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- config.front_end = "WebGpu"

-- THEME
-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = 'Dracula (Official)'
config.color_scheme = 'Apple System Colors'

-- FONT
config.font = wezterm.font("MesloLGS Nerd Font")
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