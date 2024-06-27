local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

M.theme_switcher = function(window, pane)
  local schemes = wezterm.get_builtin_color_schemes()
  local choices = {}
  local config_path = "/Users/useradmin/.config/wezterm/wezterm.lua"  -- Adjust the path as needed

  for key, _ in pairs(schemes) do
    table.insert(choices, { label = tostring(key) })
  end

  table.sort(choices, function(c1, c2)
    return c1.label < c2.label
  end)

  window:perform_action(
    act.InputSelector({
      title = "🎨 Pick a Theme!",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, _, label)
        -- Read the current configuration file
        local file = io.open(config_path, "r")
        local content = file:read("*all")
        file:close()

        -- Update the color scheme in the configuration file
        content = content:gsub('config.color_scheme = \'[^\']+\'', 'config.color_scheme = \'' .. label .. '\'')

        -- Write the updated configuration back to the file
        file = io.open(config_path, "w")
        file:write(content)
        file:close()

        -- Reload the configuration
        inner_window:perform_action(act.ReloadConfiguration, inner_pane)
      end),
    }),
    pane
  )
end

return M