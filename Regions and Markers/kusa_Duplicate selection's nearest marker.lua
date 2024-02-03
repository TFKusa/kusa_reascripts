-- @description kusa_Duplicate selection's nearest marker
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function getNearestMarker(playPosition)
    local numMarkers = reaper.CountProjectMarkers(0)
    local closestDist = math.huge
    local closestIndex = -1
    local closestPos = 0
    local closestName = ""
    for i = 0, numMarkers - 1 do
        local retval, isRegion, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if not isRegion then
            local dist = math.abs(pos - playPosition)
            if dist < closestDist then
                closestDist = dist
                closestIndex = markrgnindexnumber
                closestPos = pos
                closestName = name
            end
        end
    end
    return closestIndex, closestPos, closestName
end

local function duplicateMarker(closestIndex, closestPos, closestName)
    if closestIndex ~= -1 then
        local newPos = closestPos + 0.1
        reaper.AddProjectMarker2(0, false, newPos, 0, closestName, -1, 0)
    else
        reaper.ShowMessageBox("No marker found near the play cursor.", "Error", 0)
    end
end

local function main()
    local playPosition = reaper.GetCursorPosition()
    local closestIndex, closestPos, closestName = getNearestMarker(playPosition)
    duplicateMarker(closestIndex, closestPos, closestName)
end

main()