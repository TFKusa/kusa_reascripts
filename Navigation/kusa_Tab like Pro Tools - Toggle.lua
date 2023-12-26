-- @description kusa_Tab like Pro Tools - Toggle
-- @version 1.11
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @about : Documentation : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md
-- @changelog Hi ! Check out installation instructions : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md

local function getCursorPos()
    local cursorPos = reaper.GetCursorPosition()
    return cursorPos
end

function isCursorOverItemOnSelectedTrack(cursorPos)
    local track = reaper.GetSelectedTrack(0, 0)

    if track then
        local itemCount = reaper.CountTrackMediaItems(track)

        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local itemEnd = itemStart + itemLength

            if cursorPos >= itemStart and cursorPos <= itemEnd then
                return true, item, itemEnd
            end
        end
    end

    return false
end

local state_key = "com.kusa.toggletablikeprotools"

function toggleState()
    local current_state = reaper.GetExtState(state_key, "ToggleState")
    local new_state

    if current_state == "true" then
        new_state = false
        reaper.SetExtState(state_key, "ToggleState", "false", true)
    else
        new_state = true
        reaper.SetExtState(state_key, "ToggleState", "true", true)
        local cursorPos = getCursorPos()
        local retval, item, itemEnd = isCursorOverItemOnSelectedTrack(cursorPos)
        if retval then
            reaper.Main_OnCommand(40289, 0)  -- Deselect all items
            reaper.SetMediaItemSelected(item, true)
        end
    end

    is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, new_state and 1 or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

toggleState()
