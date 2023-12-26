-- @description kusa_Timestretch item start, peak and end to Markers
-- @version 1.02
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog Applies to all item takes

local function print(string)
    reaper.ShowConsoleMsg(string .. "\n")
end

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

local function getUserInput()
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        showMessage("No item selected.", "Error", 0)
        return false
    end
    local retval, userMarkerId = reaper.GetUserInputs("Enter Marker ID", 1, "Marker ID:", "")
    local markerId = tonumber(userMarkerId)
    return markerId
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

local function main()
    local markerId = getUserInput()
    if not markerId then return end
    local item = reaper.GetSelectedMediaItem(0, 0)
    local take = reaper.GetActiveTake(item)
    if not take then
        showMessage("No active take in item.")
        return
    end
    if markerId and item then
        local positions = getMarkerPositions(markerId)
        if #positions >= 3 then
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
        else
            local userChoice = showMessage("Couldn't find all needed Markers. Would you like to visit the documentation ?", "Error", 4)
            if userChoice == 6 then
                openURL("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TIMESTRETCH%20ITEM%20START%2C%20PEAK%20AND%20END%20TO%20MARKERS%20-%20DOCUMENTATION.md")
            end
        end
    else
        showMessage("Invalid marker ID or no item selected.", "Error", 0)
    end
end


main()