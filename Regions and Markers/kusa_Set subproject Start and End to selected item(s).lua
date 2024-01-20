-- @description kusa_Set subproject Start and End to selected item(s)
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function getExtremeStartAndEnd()
    local usableStart = 99999999
    local usableEnd = 0
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount > 0 then
        for i = 0, itemCount - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local itemEnd = itemStart + itemLength
            if itemStart < usableStart then
                usableStart = itemStart
            end

            if itemEnd > usableEnd then
                usableEnd = itemEnd
            end
        end
        return usableStart, usableEnd
    else
        return nil, nil
    end

end

function positionNamedMarkers(usableStart, usableEnd)
    if usableStart and usableEnd then
        local numMarkers = reaper.CountProjectMarkers(0)
        for i = 0, numMarkers - 1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
            if retval and not isrgn and name == "=START" then
                reaper.SetProjectMarker(markrgnindexnumber, isrgn, usableStart, rgnend, name)
                break
            end
        end
        for i = 0, numMarkers - 1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
            if retval and not isrgn and name == "=END" then
                reaper.SetProjectMarker(markrgnindexnumber, isrgn, usableEnd, rgnend, name)
                break
            end
        end
    end
end

local function main()
    local usableStart, usableEnd = getExtremeStartAndEnd()
    positionNamedMarkers(usableStart, usableEnd)
end

main()