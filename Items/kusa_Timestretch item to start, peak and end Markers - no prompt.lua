-- @description kusa_Timestretch item start, peak and end to Markers - no prompt
-- @version 1.10
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog :
--      # + Multi item selection support added.


local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

local function openURL(url)
    reaper.CF_ShellExecute(url)
end

if not reaper.APIExists("CF_GetSWSVersion") then
    local userChoice = showMessage("This script requires the SWS Extension to run. Would you like to download it ?", "Error", 4)
    if userChoice == 6 then
        openURL("https://www.sws-extension.org/")
    else
        return
    end
end

local selectedItems = {}

function getChannelsOfSelectedItem(take)
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local channels = reaper.GetMediaSourceNumChannels(source)
    return channels
end

function calculateDownsamplingFactor(totalSamples, numChannels)
    local maxBufferSize = 4159674
    return math.max(1, math.ceil(totalSamples / maxBufferSize))
end

function prepareItemAnalysis(item)
    local take = reaper.GetActiveTake(item)
    if not take then return end
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local retval, currentSampleRate = reaper.GetAudioDeviceInfo("SRATE")
    local sampleRate = tonumber(currentSampleRate)
    local numChannels = getChannelsOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    return take, accessor, sampleRate, numChannels, startTime, endTime
end

function calculateTotalSamples(startTime, endTime, sampleRate)
    return math.floor((endTime - startTime) * sampleRate)
end

function populatePeakBufferWithDownsampling(accessor, sampleRate, numChannels, startTime, totalSamples)
    local downsamplingFactor = calculateDownsamplingFactor(totalSamples, numChannels)
    local numSamples = math.ceil(totalSamples / downsamplingFactor)
    local buffer = reaper.new_array(numSamples * numChannels)
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, startTime, numSamples, buffer, downsamplingFactor)
    return buffer, downsamplingFactor
end

function findPeakInBuffer(buffer, numSamples, numChannels, downsamplingFactor)
    local peakValue = 0
    local peakIndex = 0
    local adjustedNumSamples = math.ceil(numSamples / downsamplingFactor)  
    for i = 1, adjustedNumSamples do
        local bufferIndex = (i - 1) * numChannels + 1
        if bufferIndex <= #buffer then
            for channel = 1, numChannels do
                local sampleIndex = bufferIndex + (channel - 1)
                if sampleIndex <= #buffer then
                    local sample = buffer[sampleIndex]
                    if sample > peakValue then
                        peakValue = sample
                        peakIndex = i
                    end
                end
            end
        end
    end
    peakIndex = peakIndex * downsamplingFactor
    return peakValue, peakIndex
end

function calculatePeakTime(take, item, peakIndex, sampleRate)
    local takeStartOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local peakTimeRelativeToSource = takeStartOffset + (peakIndex / sampleRate)
    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTimeRelativeToProject = itemPosition + peakTimeRelativeToSource
    local peakTime = itemPosition + (peakIndex / sampleRate)
    if peakTimeRelativeToSource < 0 then peakTimeRelativeToSource = 0 end
    return peakTime
end

function processItemsForPeaks(item)
    local take, accessor, sampleRate, numChannels, startTime, endTime = prepareItemAnalysis(item)
    if not take then return end
    local numSamples = calculateTotalSamples(startTime, endTime, sampleRate)
    local buffer, downsamplingFactor = populatePeakBufferWithDownsampling(accessor, sampleRate, numChannels, startTime, numSamples)
    local peakValue, peakIndex = findPeakInBuffer(buffer, numSamples, numChannels, downsamplingFactor)
    local peakTime = calculatePeakTime(take, item, peakIndex, sampleRate)
    reaper.DestroyAudioAccessor(accessor)
    return peakTime
end

function getClosestMarkerId(itemPos, radius)
    local closestMarkerId = nil
    local closestDistance = radius
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local totalItems = num_markers + num_regions

    for i = 0, totalItems - 1 do
        local retval, isrgn, pos, _, _, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if not isrgn and math.abs(pos - itemPos) <= closestDistance then
            closestDistance = math.abs(pos - itemPos)
            closestMarkerId = markrgnindexnumber
        end
    end
    return closestMarkerId
end

local function getClosestMarkerToItem()
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        showMessage("No item selected.", "Error", 0)
        return false
    end
    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    closestMarkerId = getClosestMarkerId(itemPos, 10)
    if closestMarkerId == 0 or closestMarkerId == nil then
        showMessage("There has to be at least one marker around the item.", "Error", 0)
    end
    return closestMarkerId
end

local function createMarkerIdMapping()
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local markerIdMap = {}
    for i = 0, num_markers + num_regions - 1 do
        local _, _, _, _, _, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        markerIdMap[markrgnindexnumber] = i
    end
    return markerIdMap
end

local function getInternalIndexForMarkerId(displayedId, markerIdMap)
    return markerIdMap[displayedId]
end

local function getMarkerPositions(displayedMarkerId)
    local markerIdMap = createMarkerIdMapping()
    local internalIndex = getInternalIndexForMarkerId(displayedMarkerId, markerIdMap)
    if not internalIndex then return {} end 
    local positions = {}
    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    local markerCounter = 0
    for i = internalIndex, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, _, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if not isrgn then
            table.insert(positions, pos)
            markerCounter = markerCounter + 1
            if markerCounter == 3 then break end
        end
    end
    if positions[2] == 0 then
        table.remove(positions, 2)
    end
    if positions[3] == 0 then
        table.remove(positions, 3)
    end
    return positions
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


local function updateEndStretchMarkerToMatchLastMarkerPosition(item, positions)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local lastMarkerPos = positions[3] - itemStart
    local numTakes = reaper.GetMediaItemNumTakes(item)
    for takeIndex = 0, numTakes - 1 do
        local take = reaper.GetMediaItemTake(item, takeIndex)
        if take then
            local endMarkerIdx = 2
            local idx, _ = reaper.GetTakeStretchMarker(take, endMarkerIdx)
            if idx ~= nil then
                reaper.SetTakeStretchMarker(take, idx, lastMarkerPos)
            else
                reaper.SetTakeStretchMarker(take, -1, lastMarkerPos)
            end
        end
    end
end


local function addStretchMarkerAtPeak(item, peakTime)
    local numTakes = reaper.GetMediaItemNumTakes(item)
    if numTakes == 0 then
        showMessage("No takes in item.", "Error", 0)
        return
    end
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local specificMarkerPosition = peakTime - itemStart
    if specificMarkerPosition < 0 or specificMarkerPosition > itemLength then
        showMessage("Peak time is outside of the item's boundaries.", "Error", 0)
        return
    end
    for takeIndex = 0, numTakes - 1 do
        local take = reaper.GetMediaItemTake(item, takeIndex)
        if take then
            local numMarkers = reaper.GetTakeNumStretchMarkers(take)
            local markerExists = false
            for i = 0, numMarkers - 1 do
                local _, markerPos = reaper.GetTakeStretchMarker(take, i)
                if math.abs(markerPos - specificMarkerPosition) < 0.001 then
                    markerExists = true
                    break
                end
            end
            if not markerExists then
                reaper.SetTakeStretchMarker(take, -1, specificMarkerPosition)
            end
        end
    end
end


local function updatePeakStretchMarkerToSecondMarkerPosition(item, positions)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local secondMarkerPos = positions[2] - itemStart
    local numTakes = reaper.GetMediaItemNumTakes(item)
    for takeIndex = 0, numTakes - 1 do
        local take = reaper.GetMediaItemTake(item, takeIndex)
        if take then
            local peakMarkerIdx = 1
            local idx, _ = reaper.GetTakeStretchMarker(take, peakMarkerIdx)
            if idx ~= nil then
                reaper.SetTakeStretchMarker(take, idx, secondMarkerPos)
            else
                reaper.SetTakeStretchMarker(take, -1, secondMarkerPos)
            end
        end
    end
end

function tableIsEmpty(table)
    for _ in pairs(table) do
        return false
    end
    return true
end

local function audioIsWav(take, item, track)
    local source = reaper.GetMediaItemTake_Source(take)
    local filenamebuf = ""
    filenamebuf = reaper.GetMediaSourceFileName(source, filenamebuf)
    if filenamebuf:match(".wav$") then
        return true
    else
        return false
    end
end

local function getSelectedItemPlayrate(take)
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    return playrate
end

local function hasBeenStretchedFunction(take, item, track)
    local retval, pos, srcpos = reaper.GetTakeStretchMarker(take, 0)
    local playrate = getSelectedItemPlayrate(take)
    local epsilon = 0.00000000000001
    if retval == 0 or math.abs(playrate - 1) > epsilon then
        return true
    else
        return false
    end
end

local function itemsAreValid(selectedItems)
    if not tableIsEmpty(selectedItems) then
        local itemsToConvert = {}
        for _, item in ipairs(selectedItems) do
            local take = reaper.GetActiveTake(item)
            local track = reaper.GetMediaItem_Track(item)
            local isWav = audioIsWav(take, item, track)
            local hasBeenStretched = hasBeenStretchedFunction(take, item, track)
            if not isWav or hasBeenStretched then
                table.insert(itemsToConvert, item)
            end
        end
        if tableIsEmpty(itemsToConvert) then
            return nil
        else
            return itemsToConvert
        end
    end
end

local function setAllFXStateOnTrack(track, state)
    local fxCount = reaper.TrackFX_GetCount(track)
    for fxIndex = 0, fxCount - 1 do
        reaper.TrackFX_SetEnabled(track, fxIndex, state)
    end
end

local function findChildTrackByName(parentTrack, trackName)
    local parentTrackIdx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER") - 1
    local trackCount = reaper.CountTracks(0)
    for i = parentTrackIdx + 1, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local isChild = reaper.GetParentTrack(track) == parentTrack
        retval, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if isChild and name == trackName then
            return track
        elseif reaper.GetTrackDepth(track) <= reaper.GetTrackDepth(parentTrack) then
            break
        end
    end
    return nil
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

local function muteOriginalItem(item, originalTrack)
    reaper.SetMediaTrackInfo_Value(originalTrack, "B_MUTE", 0)
    local itemCount = reaper.GetTrackNumMediaItems(originalTrack)
    local trackItemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(item, "B_MUTE_ACTUAL", 1)
    return trackItemPosition
end

local function cleanupAfterRender(item, originalTrack, shouldKeepOriginal, selectedItems)
    setAllFXStateOnTrack(originalTrack, true)
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

local function bounceInPlace(item, track, shouldKeepOriginal, selectedItems)
    local take = reaper.GetActiveTake(item)
    reaper.SetOnlyTrackSelected(track)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemStart + itemLength
    reaper.GetSet_LoopTimeRange(true, false, itemStart, itemEnd, false)
    local numChannels = getChannelsOfSelectedItem(take)
    setAllFXStateOnTrack(track, false)
    if numChannels == 1 then
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERMONOSMART"), 0)
    else
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERSTEREOSMART"), 0)
    end
    local shouldKeepOriginal = false
    cleanupAfterRender(item, track, shouldKeepOriginal, selectedItems)
end

local function askForBounce(shouldKeepOriginal, itemsToConvert, selectedItems)
    local userChoice = showMessage("The item's playrate has been altered, or the audio is not in WAV format. \nAnalysing it might freeze REAPER. \nWould you like to create a usable copy ?", "Warning", 4)
    if userChoice == 6 then
        for i, item in ipairs(itemsToConvert) do
            local track = reaper.GetMediaItem_Track(item)
            bounceInPlace(item, track, shouldKeepOriginal, selectedItems)
        end
        return true
    else
        unselectEveryItem()
        return false
    end
end

local function safeToExecute(selectedItems)
    local itemsToConvert = itemsAreValid(selectedItems)
    if itemsToConvert then
        reaper.Undo_BeginBlock()
        local goodToGo = askForBounce(shouldKeepOriginal, itemsToConvert, selectedItems)
        reaper.Undo_EndBlock("Bounce in place.", -1)
        if goodToGo then
            return true
        else
            return false
        end
    else
        return true
    end
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
    return selectedItems
end

local function main()
    local markerId = getClosestMarkerToItem()
    if not markerId then return end
    if safeToExecute(selectedItems) then
        local positions = getMarkerPositions(markerId)
        if #positions >= 3 then
            local selectedItems = storeSelectedMediaItems()
            for i, item in ipairs(selectedItems) do
                if item then
                    local take = reaper.GetActiveTake(item)
                    if not take then
                        showMessage("No active take in item.")
                        return
                    end     
                    local firstPosition = positions[1]
                    local lastPosition = positions[3]
                    local peakTime = processItemsForPeaks(item)
                    addStretchMarkerAtPeak(item, peakTime)
                    addStartEndStretchMarkers(item)
                    reaper.SetMediaItemPosition(item, firstPosition, true)
                    local itemStartPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local newLength = lastPosition - itemStartPosition
                    reaper.SetMediaItemLength(item, newLength, true)
                    updateEndStretchMarkerToMatchLastMarkerPosition(item, positions, take)
                    updatePeakStretchMarkerToSecondMarkerPosition(item, positions, take)
                end
            end
        else
            local userChoice = showMessage("Couldn't find all needed Markers. Would you like to visit the documentation ?", "Error", 4)
            if userChoice == 6 then
                openURL("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TIMESTRETCH%20ITEM%20START%2C%20PEAK%20AND%20END%20TO%20MARKERS%20-%20DOCUMENTATION.md")
            end
        end
    end
end


main()