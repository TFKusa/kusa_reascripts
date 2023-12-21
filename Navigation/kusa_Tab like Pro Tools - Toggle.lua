-- @description kusa_Tab like Pro Tools - Toggle
-- @version 1.00
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @about : Documentation : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md

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
    end

    is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, new_state and 1 or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

toggleState()
