-- Dropterm configuration for Hammerspoon using Kitty with tmux
local KITTY_BUNDLE_ID = "net.kovidgoyal.kitty"
local DROPTERM_TITLE = "DROPTERM"
local kittyPath = "/opt/homebrew/bin/kitty"

-- Create a window filter for Dropterm
local wf = hs.window.filter.new(function(win)
    return win:application():bundleID() == KITTY_BUNDLE_ID and win:title():find(DROPTERM_TITLE)
end)

-- Hotkey to toggle Dropterm
-- hs.hotkey.bind({"cmd"}, "escape", function()
--     toggleDropterm()
-- end)

-- Hotkey for cmd+shift+/
hs.hotkey.bind({"cmd", "shift"}, "/", function()
    toggleDropterm()
end)

function toggleDropterm()
    local dropterm = wf:getWindows()[1]
    
    if not dropterm then
        -- hs.alert.show("Dropterm not found, launching new session")
        launchKittyWithSession()
    else
        local currentSpace = hs.spaces.focusedSpace()
        local windowSpaces = hs.spaces.windowSpaces(dropterm)
        
        if windowSpaces and hs.fnutils.contains(windowSpaces, currentSpace) then
            if dropterm:isVisible() and dropterm == hs.window.focusedWindow() then
                -- hs.alert.show("Hiding Dropterm")
                dropterm:application():hide()
            else
                -- hs.alert.show("Raising Dropterm")
                dropterm:application():activate()
                positionDropterm(dropterm)
                dropterm:focus()
            end
        else
            -- Window is in a different space, move it to the current space
            -- hs.alert.show("Moving Dropterm to current space")
            local success, error = hs.spaces.moveWindowToSpace(dropterm, currentSpace)
            if success then
                dropterm:application():activate()
                positionDropterm(dropterm)
                dropterm:focus()
            else
                -- hs.alert.show("Error moving window: " .. (error or "Unknown error"))
            end
        end
    end
end

function launchKittyWithSession()
    if kittyPath ~= "" then
        -- hs.alert.show("Launching Kitty with tmux session")
        hs.task.new(kittyPath, nil, {
            "--title", DROPTERM_TITLE,
            "--directory", "~",
            "--", "tmux", "new-session", "-A", "-s", "DROPTERM"
        }):start()
        hs.timer.doAfter(1, function()
            local dropterm = wf:getWindows()[1]
            if dropterm then
                local currentSpace = hs.spaces.focusedSpace()
                local success, error = hs.spaces.moveWindowToSpace(dropterm, currentSpace)
                if success then
                    -- hs.alert.show("Successfully moved new Dropterm to current space")
                else
                    -- hs.alert.show("Error moving window: " .. (error or "Unknown error"))
                end
                positionDropterm(dropterm)
            end
        end)
    else
        -- hs.alert.show("Kitty not found. Path searched: " .. kittyPath)
    end
end

function positionDropterm(window)
    local screen = hs.mouse.getCurrentScreen()
    local screenFrame = screen:frame()
    local newFrame = hs.geometry.rect(
        screenFrame.x,
        screenFrame.y,
        screenFrame.w / 2,  -- 50% of screen width
        screenFrame.h       -- 100% of screen height
    )
    window:setFrame(newFrame)
end