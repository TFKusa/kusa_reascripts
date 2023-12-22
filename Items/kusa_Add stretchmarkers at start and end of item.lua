-- @description kusa_Add stretchmarkers at start and end of item
-- @version 1.00
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

local function addStartEndStretchMarkers(item)
    local take = reaper.GetActiveTake(item)
    if not take then
        showMessage("No active take in item.")
        return
    end
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    reaper.SetTakeStretchMarker(take, -1, 0)
    reaper.SetTakeStretchMarker(take, -1, itemLength)
end

function main()
    local itemCount = reaper.CountSelectedMediaItems(0)
    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            addStartEndStretchMarkers(item)
        end
    end
end


main()