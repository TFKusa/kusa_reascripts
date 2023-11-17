-- @description kusa_Align selected items on new takes or toggle visibility of inactive takes
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local function DetectFirstTransient(item)
    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetEditCurPos(itemPos, false, false)
    reaper.Main_OnCommand(40375, 0)
    local transientPos = reaper.GetCursorPosition()
    return transientPos
end

local function CreateTakeWithSource(firstItem, sourceItem, firstTransientOffset)
    local newTake = reaper.AddTakeToMediaItem(firstItem)
    local sourceTake = reaper.GetActiveTake(sourceItem)
    local source = reaper.GetMediaItemTake_Source(sourceTake)
    reaper.SetMediaItemTake_Source(newTake, source)
    local takeOffset = firstTransientOffset - reaper.GetMediaItemInfo_Value(firstItem, "D_POSITION")
    reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", takeOffset)
end

local itemCount = reaper.CountSelectedMediaItems(0)

if itemCount <= 1 then
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    reaper.Main_OnCommand(40435, 0)
    reaper.UpdateItemInProject(item)
    reaper.Undo_EndBlock("Toggle visibility of inactive takes", -1)
else
    reaper.Undo_BeginBlock()
    local firstItem = reaper.GetSelectedMediaItem(0, 0)
    local firstItemTrack = reaper.GetMediaItem_Track(firstItem)
    for i = 1, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if reaper.GetMediaItem_Track(item) ~= firstItemTrack then
            reaper.ShowMessageBox("All selected items must be on the same track.", "Error", 0)
            return
        end
        local firstTransientOffset = DetectFirstTransient(item)
        CreateTakeWithSource(firstItem, item, firstTransientOffset)
    end
    for i = itemCount - 1, 1, -1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.DeleteTrackMediaItem(firstItemTrack, item)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Align Items to First Item as Takes", -1)
end