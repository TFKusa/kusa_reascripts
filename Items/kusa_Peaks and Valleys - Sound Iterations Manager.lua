-- @description kusa_Peaks and Valleys - Sound Iterations Manager
-- @version 1.20
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function showMessage(message, title, errorType)
    reaper.MB(message, title, errorType)
end

if not reaper.APIExists("CF_GetSWSVersion") then
    showMessage("This script requires the SWS Extension to run.", "Error", 0)
    return
end

if not reaper.APIExists("ImGui_GetVersion") then
    showMessage("This script requires ReaImGui to run.", "Error", 0)
    return
end

local silenceItems = {}
local lastTrack = nil

-------------------------------------------------------------------------------------------
-----------------------------------FINDING SILENCES----------------------------------------
-------------------------------------------------------------------------------------------
function prepareAudioAccessor(item)
    local take = reaper.GetActiveTake(item)
    if not take then return nil end
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local sampleRate = getSampleRateOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    return take, accessor, sampleRate, startTime, endTime
end

function calculateTotalSamples(startTime, endTime, sampleRate)
    return math.floor((endTime - startTime) * sampleRate)
end

function calculateProcessedSamples(totalNumSamples, downsamplingFactor)
    local numSamplesProcessed = math.floor(totalNumSamples / downsamplingFactor)
    if totalNumSamples % downsamplingFactor > 0 then
        numSamplesProcessed = numSamplesProcessed + 1
    end
    return numSamplesProcessed
end

function isBufferTooLarge(numSamplesProcessed)
    return numSamplesProcessed > 4000000
end

function populateSilenceBuffer(accessor, sampleRate, startTime, numSamplesProcessed, downsamplingFactor)
    local buffer = reaper.new_array(numSamplesProcessed)
    buffer.clear()
    local tempBuffer = reaper.new_array(1)
    tempBuffer.clear()
    for i = 1, numSamplesProcessed do
        local samplePosition = startTime + ((i - 1) * downsamplingFactor) / sampleRate
        reaper.GetAudioAccessorSamples(accessor, sampleRate, 1, samplePosition, 1, tempBuffer)
        buffer[i] = tempBuffer[1]
    end
    return buffer
end

function detectSilences(buffer, silenceThreshold, minSilenceDuration, sampleRate, downsamplingFactor)
    local silences = {}
    local silenceStartIndex = nil
    local currentSilenceDuration = 0
    local minSilenceSamples = minSilenceDuration * sampleRate / downsamplingFactor

    for i = 1, #buffer do
        local sample = math.abs(buffer[i])
        local isSilent = sample <= silenceThreshold

        if isSilent then
            if silenceStartIndex == nil then
                silenceStartIndex = i
            end
            currentSilenceDuration = currentSilenceDuration + 1
        else
            if silenceStartIndex and currentSilenceDuration >= minSilenceSamples then
                local silenceEndTimeIndex = silenceStartIndex + currentSilenceDuration - 1
                table.insert(silences, { start = silenceStartIndex, ["end"] = silenceEndTimeIndex })
            end
            silenceStartIndex = nil
            currentSilenceDuration = 0
        end
    end

    if silenceStartIndex and currentSilenceDuration >= minSilenceSamples then
        local silenceEndTimeIndex = silenceStartIndex + currentSilenceDuration - 1
        table.insert(silences, { start = silenceStartIndex, ["end"] = silenceEndTimeIndex })
    end
    return silences
end

function convertSilencesToTime(silences, startTime, sampleRate, downsamplingFactor)
    local silencesInTime = {}

    for _, silence in ipairs(silences) do
        local startInTime = startTime + (silence.start * downsamplingFactor - downsamplingFactor) / sampleRate
        local endInTime = startTime + (silence["end"] * downsamplingFactor - downsamplingFactor) / sampleRate
        table.insert(silencesInTime, { start = startInTime, ["end"] = endInTime })
    end
    return silencesInTime
end

function findAllSilencesInItem(item, silenceThreshold, minSilenceDuration, downsamplingFactor)
    local take, accessor, sampleRate, startTime, endTime = prepareAudioAccessor(item)
    if not take then return nil end

    local totalNumSamples = calculateTotalSamples(startTime, endTime, sampleRate)
    local numSamplesProcessed = calculateProcessedSamples(totalNumSamples, downsamplingFactor)

    if isBufferTooLarge(numSamplesProcessed) then
        showMessage("This item at its current Sample Rate is overflowing the processing buffer, please trim it down.", "Error", 0)
        return false
    end

    local buffer = populateSilenceBuffer(accessor, sampleRate, startTime, numSamplesProcessed, downsamplingFactor)
    local silences = detectSilences(buffer, silenceThreshold, minSilenceDuration, sampleRate, downsamplingFactor)
    local silencesInTime = convertSilencesToTime(silences, startTime, sampleRate, downsamplingFactor)

    reaper.DestroyAudioAccessor(accessor)
    return silencesInTime
end

function deleteSilencesFromItem(item, silences)
    if not item or not silences then return end

    table.sort(silences, function(a, b) return a.start < b.start end)

    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    for i = #silences, 1, -1 do
        local silence = silences[i]
        local silenceStart = itemPosition + silence.start + 0.15
        local silenceEnd = itemPosition + silence["end"]--[[  - 0.01 ]]

        local splitItemEnd = reaper.SplitMediaItem(item, silenceEnd)
        
        local splitItemStart = reaper.SplitMediaItem(item, silenceStart)
        
        if splitItemStart and splitItemEnd then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(splitItemEnd), splitItemStart)
        end
    end
end

function deleteShortItems()
    local selectedItemsCount = reaper.CountSelectedMediaItems(0)
    if selectedItemsCount == 0 then return end

    local totalLength = 0
    for i = 0, selectedItemsCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        totalLength = totalLength + length
    end

    local averageLength = totalLength / selectedItemsCount
    local minLength = averageLength / 3

    for i = selectedItemsCount - 1, 0, -1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        if length < minLength then
            local track = reaper.GetMediaItem_Track(item)
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
end
-------------------------------------------------------------------------------------------
-------------------------------------FINDING PEAKS-----------------------------------------
-------------------------------------------------------------------------------------------
function prepareItemAnalysis(item)
    local take = reaper.GetActiveTake(item)
    if not take then return end
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local sampleRate = getSampleRateOfSelectedItem(take)
    local numChannels = getChannelsOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    return take, accessor, sampleRate, numChannels, startTime, endTime
end

function calculateTotalSamples(startTime, endTime, sampleRate)
    return math.floor((endTime - startTime) * sampleRate)
end

function populatePeakBuffer(accessor, sampleRate, numChannels, startTime, numSamples)
    local buffer = reaper.new_array(numSamples * numChannels)
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, startTime, numSamples, buffer)
    return buffer
end

function findPeakInBuffer(buffer, numSamples, numChannels)
    local peakValue = 0
    local peakIndex = 0
    for i = 1, numSamples do
        for channel = 1, numChannels do
            local sampleIndex = (i - 1) * numChannels + channel
            local sample = math.abs(buffer[sampleIndex])
            if sample > peakValue then
                peakValue = sample
                peakIndex = i
            end
        end
    end
    return peakValue, peakIndex
end

function calculatePeakTime(take, item, peakIndex, sampleRate)
    local takeStartOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local peakTimeRelativeToSource = takeStartOffset + (peakIndex / sampleRate)
    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTimeRelativeToProject = itemPosition + peakTimeRelativeToSource
    local itemStartPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTime = itemStartPos + (peakIndex / sampleRate)

    if peakTimeRelativeToSource < 0 then peakTimeRelativeToSource = 0 end
    return peakTime
end

function processItemsForPeaks(item)
    local take, accessor, sampleRate, numChannels, startTime, endTime = prepareItemAnalysis(item)
    if not take then return end

    local numSamples = calculateTotalSamples(startTime, endTime, sampleRate)
    local buffer = populatePeakBuffer(accessor, sampleRate, numChannels, startTime, numSamples)

    local peakValue, peakIndex = findPeakInBuffer(buffer, numSamples, numChannels)

    local peakTime = calculatePeakTime(take, item, peakIndex, sampleRate)

    reaper.DestroyAudioAccessor(accessor)
    return peakTime
end
-------------------------------------------------------------------------------------------
-----------------------------------SIMPLE FUNCTIONS----------------------------------------
-------------------------------------------------------------------------------------------
function initParameters()
    local silenceThreshold = 0.001
    local minSilenceDuration = 0.5
end

function getSampleRateOfSelectedItem(take)
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local sampleRate = reaper.GetMediaSourceSampleRate(source)
    return sampleRate
end

function getChannelsOfSelectedItem(take)
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local channels = reaper.GetMediaSourceNumChannels(source)
    return channels
end

function addFades()
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.00001)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.1)
    end
end

function clearTemporaryItems(track)
    for _, item in ipairs(silenceItems) do
        if reaper.ValidatePtr(item, "MediaItem*") then
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
    silenceItems = {}
end

function cleanup()
    if lastTrack then
        clearTemporaryItems(lastTrack)
        reaper.UpdateArrange()
    end
end

function getDownsamplingFactor(item)
    if item then
        local take = reaper.GetActiveTake(item)
        local retval, currentSampleRate = reaper.GetAudioDeviceInfo("SRATE")
        currentSampleRate = tonumber(currentSampleRate)
        if retval then
            local downsamplingFactor
            if currentSampleRate < 48001 then
                downsamplingFactor = 2
            elseif currentSampleRate >= 48001 and currentSampleRate < 96001 then
                downsamplingFactor = 4
            elseif currentSampleRate >= 96001 then
                downsamplingFactor = 8
            end
            return downsamplingFactor
        else
            showMessage("Could not retrieve current Audio device sample rate.")
        end
    end
end
-------------------------------------------------------------------------------------------
------------------------------------FUNCTIONS----------------------------------------------
-------------------------------------------------------------------------------------------
function alignItemsByPeakTime()
    local numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 2 then return end

    local firstItem = reaper.GetSelectedMediaItem(0, 0)
    local firstPeakTime = processItemsForPeaks(firstItem)

    for i = 1, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local peakTime = processItemsForPeaks(item)
        if peakTime then
            local offset = firstPeakTime - peakTime
            local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local newPosition = itemPosition + offset
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", newPosition)
        end
    end
end

function alignItemsByStartPosition()
    local numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 2 then return end

    local earliestStart = math.huge
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if itemPosition < earliestStart then
            earliestStart = itemPosition
        end
    end

    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", earliestStart)
    end
end

function implodeToTakesKeepPosition()
    local selectedItemsCount = reaper.CountSelectedMediaItems(0)
    if selectedItemsCount < 1 then return end

    for i = 0, selectedItemsCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "B_LOOPSRC", 0)

        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemPos + itemLength

        local minPos, maxEnd = itemPos, itemEnd
        for j = 0, selectedItemsCount - 1 do
            if i ~= j then
                local otherItem = reaper.GetSelectedMediaItem(0, j)
                local otherItemPos = reaper.GetMediaItemInfo_Value(otherItem, "D_POSITION")
                local otherItemLength = reaper.GetMediaItemInfo_Value(otherItem, "D_LENGTH")
                local otherItemEnd = otherItemPos + otherItemLength

                minPos = math.min(minPos, otherItemPos)
                maxEnd = math.max(maxEnd, otherItemEnd)
            end
        end

        reaper.BR_SetItemEdges(item, minPos, maxEnd)
    end

    reaper.Main_OnCommand(40543, 0) -- Command ID for "Take: Implode items on same track into takes"
end

function spaceSelectedItemsByOneSecond()
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount < 2 then return end

    local prevItem = reaper.GetSelectedMediaItem(0, 0)
    local prevItemEnd = reaper.GetMediaItemInfo_Value(prevItem, "D_LENGTH") + reaper.GetMediaItemInfo_Value(prevItem, "D_POSITION")

    for i = 1, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local newPosition = prevItemEnd + 1.0
        reaper.SetMediaItemPosition(item, newPosition, false)
        prevItemEnd = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + newPosition
    end
end

function createSilenceItems(track, silences, itemPosition)
    cleanup()
    lastTrack = track
    local redColor = reaper.ColorToNative(255, 0, 0) | 0x1000000
    for _, silence in ipairs(silences) do
        local silenceStart = itemPosition + silence.start
        local silenceEnd = itemPosition + silence["end"]
        local silenceLength = silenceEnd - silenceStart

        local newItem = reaper.AddMediaItemToTrack(track)
        reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", silenceStart)
        reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", silenceLength)
        reaper.SetMediaItemInfo_Value(newItem, "D_FADEINLEN", 0)
        reaper.SetMediaItemInfo_Value(newItem, "D_FADEOUTLEN", 0)

        reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", redColor)
        table.insert(silenceItems, newItem)
    end
end

function main(silenceThreshold, minSilenceDuration, toBank, split, alignOnPeaks)
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    downsamplingFactor = getDownsamplingFactor(item)
    silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration, downsamplingFactor)
    if not silences then return end
    deleteSilencesFromItem(item, silences)
    local track = reaper.GetMediaItem_Track(item)
    if toBank then
        deleteShortItems()
        spaceSelectedItemsByOneSecond()
        addFades()
        reaper.Undo_EndBlock("Split and align to takes", -1)
        reaper.UpdateArrange() 
        return
    end 
    if split then
        addFades()
        reaper.Undo_EndBlock("Split and align to takes", -1)
        reaper.UpdateArrange() 
        return
    end
    if alignOnPeaks then
        deleteShortItems()
        alignItemsByPeakTime()
    else
        deleteShortItems()
        alignItemsByStartPosition()
    end
    addFades()
    implodeToTakesKeepPosition()
    reaper.Undo_EndBlock("Split and align to takes", -1)
    reaper.UpdateArrange()
end
-------------------------------------------------------------------------------------------
---------------------------------------UI--------------------------------------------------
-------------------------------------------------------------------------------------------
local ctx = reaper.ImGui_CreateContext("Peaks and Valleys by Kusa")

local silenceThreshold = 0.01
local minSilenceDuration = 0.2

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "Peaks and Valleys by Kusa", true)
    if visible then
        local selectedItem = reaper.GetSelectedMediaItem(0, 0)
        if not selectedItem then
            cleanup()
        end
        local changed
        thresholdChanged, silenceThreshold = reaper.ImGui_SliderDouble(ctx, 'Threshold', silenceThreshold, 0.001, 0.3, "%.3f")       
        minDurChanged, minSilenceDuration = reaper.ImGui_SliderDouble(ctx, 'Min Duration', minSilenceDuration, 0.0, 2.0, "%.3f")

        if reaper.ImGui_Button(ctx, 'Takes (peak)') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration, false, false, true)
                reaper.UpdateArrange()
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Takes (start)') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration, false, false, false)
                reaper.UpdateArrange()
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Split and space items') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration, true, false, false)
                reaper.UpdateArrange()
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Split') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration, false, true, false)
                reaper.UpdateArrange()
            end
        end
        if thresholdChanged or minDurChanged then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if item then
                local track = reaper.GetMediaItem_Track(item)
                local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                downsamplingFactor = getDownsamplingFactor(item)
                local silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration, downsamplingFactor)
                if silences then   
                    cleanup()
                    createSilenceItems(track, silences, itemPosition)
                end
            else
                showMessage("No item selected.", "Error", 0)
                cleanup()
            end
        end
        reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    else
        local item = reaper.GetSelectedMediaItem(0, 0)
        if not item then
            cleanup()
            reaper.ImGui_DestroyContext(ctx)
            return 
        end
        local track = reaper.GetMediaItem_Track(item)
        if not track then
            cleanup()
            reaper.ImGui_DestroyContext(ctx)
            return    
        end
        cleanup()
        reaper.UpdateArrange()
    end
end

initParameters()
reaper.defer(loop)