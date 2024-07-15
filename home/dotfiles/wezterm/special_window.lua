local wezterm = require 'wezterm'
local mux = wezterm.mux

-- Global variable to keep track of our special window
local special_window = nil

-- Function to toggle the special window
local function toggle_special_window(window)
  if special_window and not special_window:is_alive() then
    special_window = nil
  end

  if special_window then
    if special_window:is_visible() then
      special_window:focus()
      special_window:hide()
    else
      special_window:focus()
      special_window:show()
    end
  else
    -- Create a new window if it doesn't exist
    local screen = wezterm.gui.screens().active
    local width = math.floor(screen.width / 2)
    local height = screen.height
    local left = screen.width - width

    local tab, pane, window = wezterm.mux.spawn_window({
      position = { 
        x = left, 
        y = 0,
        origin = "ActiveScreen"
      },
      width = width,
      height = height,
    })
    special_window = window
  end
end

-- Return the function so it can be used in the main config
return {
  toggle_special_window = toggle_special_window
}
