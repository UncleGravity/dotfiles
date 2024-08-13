-- This module is adapted from https://gist.github.com/arbelt/b91e1f38a0880afb316dd5b5732759f1
local M = {}

-- Configuration
local ESCAPE_DELAY = 0.1

-- State variables
local sendEscape = false
local lastMods = {}

-- Timer for delayed escape
local controlKeyTimer = hs.timer.delayed.new(ESCAPE_DELAY, function()
    sendEscape = false
end)

-- Handle control key events
local function controlHandler(evt)
    local newMods = evt:getFlags()
    
    -- Check if ctrl state has changed
    if lastMods["ctrl"] == newMods["ctrl"] then
        return false
    end
    
    if not lastMods["ctrl"] then
        -- Ctrl key pressed
        lastMods = newMods
        sendEscape = true
        controlKeyTimer:start()
    else
        -- Ctrl key released
        lastMods = newMods
        controlKeyTimer:stop()
        
        if sendEscape then
            -- Send escape key events
            return true, {
                hs.eventtap.event.newKeyEvent({}, "escape", true),
                hs.eventtap.event.newKeyEvent({}, "escape", false),
            }
        end
    end
    
    return false
end

-- Initialize the module
function M.init()
    local controlTap = hs.eventtap.new(
        { hs.eventtap.event.types.flagsChanged },
        controlHandler
    )
    controlTap:start()
end

return M