-- @description kusa_Add stretchmarkers at start and end of item
-- @version 1.02
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

local function addStartEndStretchMarkers(item)
    local numTakes = reaper.GetMediaItemNumTakes(item)
    if numTakes == 0 then
        showMessage("No takes in item.", "Error", 0)
        return
    end
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    for takeIndex = 0, numTakes - 1 do
        local take = reaper.GetMediaItemTake(item, takeIndex)
        if take then
            local numMarkers = reaper.GetTakeNumStretchMarkers(take)
            local startMarkerExists = false
            local endMarkerExists = false
            for i = 0, numMarkers - 1 do
                local _, markerPos = reaper.GetTakeStretchMarker(take, i)
                if math.abs(markerPos) < 0.001 then
                    startMarkerExists = true
                end
                if math.abs(markerPos - itemLength) < 0.001 then
                    endMarkerExists = true
                end
            end
            if not startMarkerExists then
                reaper.SetTakeStretchMarker(take, -1, 0)
            end
            if not endMarkerExists then
                reaper.SetTakeStretchMarker(take, -1, itemLength)
            end
        end
    end
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