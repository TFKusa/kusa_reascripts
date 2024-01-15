-- @description kusa_Create single loop from item
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

local function unselectEveryItem()
    local itemCount = reaper.CountMediaItems(0)
    for i = 0, itemCount - 1 do
        local currentItem = reaper.GetMediaItem(0, i)
        reaper.SetMediaItemSelected(currentItem, false)
    end
end

local function getItemPositionLengthEnd(item)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemStart + itemLength

    return itemStart, itemLength, itemEnd
end

local function tableIsEmpty(table)
    for _ in pairs(table) do
        return false
    end
    return true
end

local function storeSelectedMediaItems()
    local itemCount = reaper.CountSelectedMediaItems(0)
    local selectedItems = {}
    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if item and take then
            table.insert(selectedItems, item)
        end
    end
    if tableIsEmpty(selectedItems) then
        showMessage("No item selected.", "Whoops", 0)
        return nil
    else
        return selectedItems
    end
end

local function splitItem(item, nbrLoops)
    local item = item
    local rightItem
    local allResultingItems = {}
    local itemStart, itemLength, _ = getItemPositionLengthEnd(item)
    local loopLength = itemLength / nbrLoops
    local numSplits = math.floor(itemLength / loopLength)

    for i = 1, numSplits - 1 do
        local splitPosition = itemStart + (i * loopLength)
        rightItem = reaper.SplitMediaItem(item, splitPosition)
    end
    return item, rightItem
end

local function setFades(item, fadesLength)
    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fadesLength)
    reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fadesLength)
end

local function main()
    local selectedItems = storeSelectedMediaItems()
    if selectedItems then
        reaper.Undo_BeginBlock()
        for _, item in ipairs(selectedItems) do

        -- Get transition length
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local transitionTime = itemLength / 7

        -- Split item
        local originalFirstItem, originalSecondItem = splitItem(item, 2)

        -- Get global start time
        local originalFirstItemStart = reaper.GetMediaItemInfo_Value(originalFirstItem, "D_POSITION")
        -- Move new start to start
        reaper.SetMediaItemInfo_Value(originalSecondItem, "D_POSITION", originalFirstItemStart)
        -- Get end of new start
        local _, _, originalSecondItemEnd = getItemPositionLengthEnd(originalSecondItem)
        -- Set position of end loop item
        local originalFirstItemNewPos = originalSecondItemEnd - transitionTime
        reaper.SetMediaItemInfo_Value(originalFirstItem, "D_POSITION", originalFirstItemNewPos)

        -- Make sure we have only our items selected
        unselectEveryItem()
        reaper.SetMediaItemSelected(originalFirstItem, true)
        reaper.SetMediaItemSelected(originalSecondItem, true)
        reaper.Main_OnCommand(41193, 0) -- Item: Remove fade in and fade out
        setFades(originalFirstItem, 0.00001)
        setFades(originalSecondItem, 0.00001)
        reaper.Main_OnCommand(41059, 0) -- Item: Crossfade any overlapping items
        reaper.Main_OnCommand(41529, 0) -- Item: Set crossfade shape to type 2 (equal power)
        end

        reaper.UpdateArrange()
        reaper.Undo_EndBlock("kusa_Create single loop from item", -1)
    end
end

main()