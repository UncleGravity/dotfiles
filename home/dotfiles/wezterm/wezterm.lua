local wezterm = require("wezterm")
local mux = wezterm.mux
local theme_switcher = require("theme_switcher")
-- local special_window = require("special_window")
local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.max_fps = 120

-- config.front_end = "WebGpu"

-- THEME
-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = 'Gruvbox Dark (Gogh)'
-- config.color_scheme = "Gruvbox Dark (Gogh)"
config.color_scheme = "Gruvbox Material (Gogh)"

-- FONT
config.font = wezterm.font("MesloLGS Nerd Font")
config.font_size = 13
-- config.freetype_load_target = "Light"
-- config.freetype_render_target = "HorizontalLcd"
config.freetype_load_flags = "NO_HINTING"

-- WINDOW
config.hide_tab_bar_if_only_one_tab = true
-- config.enable_tab_bar = false
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 90

-- Bind a key to trigger the theme switcher
config.keys = {
	{
		key = "t",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			theme_switcher.theme_switcher(window, pane)
		end),
	},
	-- Add these new keybindings
	{
		key = "h",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivateTabRelative(-1),
	},
	{
		key = "l",
		mods = "CMD|SHIFT",
		action = wezterm.action.ActivateTabRelative(1),
	},
	-- { key = "UpArrow", mods = "SHIFT", action = wezterm.action.ScrollByLine(-1) },
	-- { key = "DownArrow", mods = "SHIFT", action = wezterm.action.ScrollByLine(1) },
	-- {
	--   key="t",mods="CMD|SHIFT",
	--   action=wezterm.action_callback(function(window, pane)
	--     special_window.toggle_special_window(window)
	--     window:set_inner_size(1000, 500)
	--   end)
	-- },
}

-- config.mouse_bindings = {
-- 	-- Disable horizontal scrolling
-- 	{
-- 		event = { Down = { streak = 1, button = { WheelLeft = 1 } } },
-- 		mods = "NONE",
-- 		action = wezterm.action.Nop,
-- 	},
-- 	{
-- 		event = { Down = { streak = 1, button = { WheelRight = 1 } } },
-- 		mods = "NONE",
-- 		action = wezterm.action.Nop,
-- 	},
-- }

-- Test this with: `wezterm start --workspace caquita -- tmux new-session -A -s 1`
wezterm.on('gui-startup', function(cmd)
  local screen = wezterm.gui.screens().active
  print("Screen:", screen)
  local width = math.floor(screen.width / 2)
  local height = screen.height

  local tab, pane, window = mux.spawn_window(cmd or {
    -- x = screen.x,
    -- y = screen.y,
    -- origin = {Named=screen.name}
  })

  -- wezterm.sleep_ms(1000)

  print("Window", window)
  if window:get_workspace() == "caquita" then
    -- wezterm.sleep_ms(1000)  -- Delay to ensure the window is ready
    local gui_window = window:gui_window()
    wezterm.sleep_ms(50)
    gui_window:set_inner_size(width, height)
    gui_window:set_position(screen.x, -screen.y*2)  -- X = lower is more left, Y = lower is more up
    -- pane:send_text 'fastfetch\n'
  end
end)

-- and finally, return the configuration to wezterm
return config

