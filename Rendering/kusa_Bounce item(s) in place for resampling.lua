-- @description kusa_Bounce item(s) in place for resampling
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

if not reaper.APIExists("CF_GetSWSVersion") then
    local userChoice = showMessage("This script requires the SWS Extension to run. Would you like to download it ?", "Error", 4)
    if userChoice == 6 then
        openURL("https://www.sws-extension.org/")
    else
        return
    end
end

local function tableIsEmpty(table)
    for _ in pairs(table) do
        return false
    end
    return true
end

local function getChannelsOfSelectedItem(take)
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local channels = reaper.GetMediaSourceNumChannels(source)
    return channels
end

local function getMediaItemAtPosition(track, position)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        if item then
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            if itemStart == position then
                return item
            end
        end
    end
    return nil
end

local function muteOriginalItem(item, originalTrack)
    reaper.SetMediaTrackInfo_Value(originalTrack, "B_MUTE", 0)
    local itemCount = reaper.GetTrackNumMediaItems(originalTrack)
    local trackItemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(item, "B_MUTE_ACTUAL", 1)
    return trackItemPosition
end

local function createChildTrack(parentTrack, childTrack, item, trackItemPosition)
    local trackName = "Original item"
    local parentTrackIndex = reaper.CSurf_TrackToID(parentTrack, false)
    reaper.ReorderSelectedTracks(parentTrackIndex, 1)
    local newItem = getMediaItemAtPosition(childTrack, trackItemPosition)
    reaper.MoveMediaItemToTrack(newItem, parentTrack)
    local originalItemTrack = findChildTrackByName(parentTrack, trackName)
    if originalItemTrack then
        reaper.MoveMediaItemToTrack(item, originalItemTrack)
        reaper.DeleteTrack(childTrack)
    else
        reaper.MoveMediaItemToTrack(item, childTrack)
        reaper.GetSetMediaTrackInfo_String(childTrack, "P_NAME", trackName, true)
    end
    reaper.SetMediaItemSelected(item, false)
    reaper.SetMediaItemSelected(newItem, true)
    reaper.UpdateArrange()
    return newItem
end


local function cleanupAfterRender(item, originalTrack, shouldKeepOriginal)
    local trackItemPosition = muteOriginalItem(item, originalTrack)
    reaper.Main_OnCommand(40635, 0) -- Time selection: Remove (unselect) time selection
    local track = reaper.GetMediaItem_Track(item)
    local childTrack = reaper.GetSelectedTrack(0, 0)
    local newItem
    if shouldKeepOriginal then
        newItem = createChildTrack(originalTrack, childTrack, item, trackItemPosition)

    else
        newItem = getMediaItemAtPosition(childTrack, trackItemPosition)
        reaper.MoveMediaItemToTrack(newItem, originalTrack)
        reaper.DeleteTrackMediaItem(originalTrack, item)
        reaper.DeleteTrack(childTrack)
        reaper.SetMediaItemSelected(newItem, true)
    end
    reaper.UpdateArrange()
end

local function bounceInPlace(item, track, shouldKeepOriginal)
    local take = reaper.GetActiveTake(item)
    reaper.SetOnlyTrackSelected(track)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemStart + itemLength
    reaper.GetSet_LoopTimeRange(true, false, itemStart, itemEnd, false)
    local numChannels = getChannelsOfSelectedItem(take)
    if numChannels == 1 then
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERMONOSMART"), 0)
    else
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERSTEREOSMART"), 0)
    end
    cleanupAfterRender(item, track, shouldKeepOriginal)
end

local function unselectEveryItem()
    local itemCount = reaper.CountMediaItems(0)
    for i = 0, itemCount - 1 do
        local currentItem = reaper.GetMediaItem(0, i)
        reaper.SetMediaItemSelected(currentItem, false)
    end
end

local function selectOnlyThisItem(item)
    unselectEveryItem()
    if item then
        reaper.SetMediaItemSelected(item, true)
    end
end

local function getItemPositionLengthEnd(item)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemStart + itemLength

    return itemStart, itemLength, itemEnd
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

local function main()
    reaper.Undo_BeginBlock()
    local selectedItems = storeSelectedMediaItems()
    if selectedItems then
        for _, item in ipairs(selectedItems) do
            selectOnlyThisItem(item)
            local track = reaper.GetMediaItem_Track(item)
            local shouldKeepOriginal = false
            bounceInPlace(item, track, shouldKeepOriginal)
        end
    end
    reaper.Undo_EndBlock("Bounce in place for resampling", -1)
end

main()
