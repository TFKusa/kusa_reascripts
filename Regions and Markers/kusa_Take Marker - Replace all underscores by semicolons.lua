-- @description kusa_Replace all underscores with semicolons for all take markers.
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function renameTakeMarkers()
    local markerData = {}
    local itemCount = reaper.CountMediaItems(0)

    if itemCount > 0 then
        for i = 0, itemCount - 1 do
            local item = reaper.GetMediaItem(0, i)
            if item then
                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                for takeIndex = 0, reaper.CountTakes(item) - 1 do
                    local take = reaper.GetMediaItemTake(item, takeIndex)
                    if take then
                        local takeMarkerCount = reaper.GetNumTakeMarkers(take)
                        if takeMarkerCount > 0 then
                            for k = 0, takeMarkerCount - 1 do
                                local retval, name, color = reaper.GetTakeMarker(take, k)
                                if retval ~= -1 and name then
                                    local newName = name:gsub("_", ";")
                                    reaper.SetTakeMarker(take, k, newName)
                                end
                            end
                        else
                            reaper.ShowConsoleMsg("No take marker found.")
                        end
                    else
                        reaper.ShowConsoleMsg("Item has no take.")
                    end
                end
            else
                reaper.ShowConsoleMsg("No item found.")
            end
        end
    else
        reaper.ShowConsoleMsg("No item found.")
    end
end

renameTakeMarkers()