-- @description kusa_Set time selection to items, set repeat if time selection
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

reaper.Main_OnCommand(40635, 0)
reaper.Main_OnCommand(40290, 0)

local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

if startTime == endTime then
    local setRepeatCommandID = reaper.NamedCommandLookup("_SWS_UNSETREPEAT")

    if setRepeatCommandID ~= 0 then
        reaper.Main_OnCommand(setRepeatCommandID, 0)
    else
        reaper.ShowConsoleMsg("SWS action not found\n")
    end
else
    local unsetRepeatCommandID = reaper.NamedCommandLookup("_SWS_SETREPEAT")

    if unsetRepeatCommandID ~= 0 then
        reaper.Main_OnCommand(unsetRepeatCommandID, 0)
    else
        reaper.ShowConsoleMsg("SWS action not found\n")
    end
end

