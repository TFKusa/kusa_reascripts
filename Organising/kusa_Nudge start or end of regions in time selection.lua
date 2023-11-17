-- @description kusa_Nudge start or end of regions in time selection
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


retval, userInput = reaper.GetUserInputs("Nudge Regions", 2, "Start 1/End 2,Nudge Amount (seconds)", "end,1")
if not retval then return end

nudgeStart, nudgeAmount = userInput:match("([^,]+),([^,]+)")
nudgeAmount = tonumber(nudgeAmount)
if nudgeStart ~= "yes" then nudgeStart = false else nudgeStart = true end

startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)

numRegions = reaper.CountProjectMarkers(0)
for i = 0, numRegions - 1 do
    local retval, isRegion, position, rgnEnd, name, markerIdx = reaper.EnumProjectMarkers(i)
    if isRegion then
        if position < endTime and rgnEnd > startTime then
            if nudgeStart then
                position = position + nudgeAmount
            else
                rgnEnd = rgnEnd + nudgeAmount
            end
            reaper.SetProjectMarkerByIndex(0, i, isRegion, position, rgnEnd, markerIdx, name, 0)
        end
    end
end
