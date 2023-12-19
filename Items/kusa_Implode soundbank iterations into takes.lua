-- @description kusa_Implode soundbank iterations from block to takes
-- @version 1.02
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function showMessage(string, title)
    reaper.MB(string, title, 0)
end
-------------------------------------------------------------------------------------------
function init()
    local silenceThreshold = 0.01
    local minSilenceDuration = 0.2
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        local track = reaper.GetMediaItem_Track(item)
        local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
        if not silences then return false end
        
        cleanup()
        createSilenceItems(track, silences, itemPosition)
        return true
    else
        showMessage("No item selected.", "Error")
        return false
    end
end

function findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    local take = reaper.GetActiveTake(item)
    if not take then return nil end

    local accessor = reaper.CreateTakeAudioAccessor(take)
    local sampleRate = getSampleRateOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    local numSamples = math.floor((endTime - startTime) * sampleRate)
    if numSamples > 4000000 then
        showMessage("This item at its current Sample Rate is overflowing the processing buffer, please trim it down.", "Error")
        return false
    end

    local buffer = reaper.new_array(numSamples)
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sampleRate, 1, startTime, numSamples, buffer)

    local silences = {}
    local silenceStartIndex = nil
    local currentSilenceDuration = 0
    local minSilenceSamples = minSilenceDuration * sampleRate

    for i = 1, numSamples do
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

    reaper.DestroyAudioAccessor(accessor)

    local silencesInTime = {}
    for _, silence in ipairs(silences) do
        local startInTime = startTime + (silence.start - 1) / sampleRate
        local endInTime = startTime + (silence["end"] - 1) / sampleRate
        table.insert(silencesInTime, { start = startInTime, ["end"] = endInTime })
    end

    return silencesInTime
end

function deleteSilencesFromItem(item, silences)
    if not item or not silences then return end

    table.sort(silences, function(a, b) return a.start < b.start end)

    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    for i = #silences, 1, -1 do
        local silence = silences[i]
        local silenceStart = itemPosition + silence.start + 0.15
        local silenceEnd = itemPosition + silence["end"] - 0.01

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

function processItemsForPeaks(item)
    local take = reaper.GetActiveTake(item)
    if not take then return end

    local accessor = reaper.CreateTakeAudioAccessor(take)
    local sampleRate = getSampleRateOfSelectedItem(take)
    local numChannels = getChannelsOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    local numSamples = math.floor((endTime - startTime) * sampleRate)

    local buffer = reaper.new_array(numSamples * numChannels)
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, startTime, numSamples, buffer)

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

    local takeStartOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local peakTimeRelativeToSource = takeStartOffset + (peakIndex / sampleRate)
    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTimeRelativeToProject = itemPosition + peakTimeRelativeToSource
    local middleIndex = peakIndex
    local itemStartPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTime = itemStartPos + (middleIndex / sampleRate)

    if peakTimeRelativeToSource < 0 then peakTimeRelativeToSource = 0 end

    reaper.DestroyAudioAccessor(accessor)
    return peakTime
end

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

function addFades()
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.1)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.1)
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

function main(silenceThreshold, minSilenceDuration)
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    deleteSilencesFromItem(item, silences)
    local track = reaper.GetMediaItem_Track(item)
    deleteShortItems()
    alignItemsByPeakTime()
    implodeToTakesKeepPosition()
    reaper.Undo_EndBlock("Split and align to takes", -1)
    reaper.UpdateArrange()
end

local silenceItems = {}
local lastTrack = nil

function cleanup()
    if lastTrack then
        clearTemporaryItems(lastTrack)
        reaper.UpdateArrange()
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

local ctx = reaper.ImGui_CreateContext("kusa_Implode soundbank iterations into takes")

local silenceThreshold = 0.01
local minSilenceDuration = 0.2

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "kusa_Implode soundbank iterations into takes", true)
    if visible then
        local changed
        thresholdChanged, silenceThreshold = reaper.ImGui_SliderDouble(ctx, 'Silence Threshold (0-1)', silenceThreshold, 0.0, 0.5, "%.3f")
        
        minDurChanged, minSilenceDuration = reaper.ImGui_SliderDouble(ctx, 'Minimum Silence Duration (seconds)', minSilenceDuration, 0.0, 2.0, "%.3f")

        if reaper.ImGui_Button(ctx, 'Go') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error")
                cleanup()
                return
            end
            local track = reaper.GetMediaItem_Track(item)
            cleanup()
            main(silenceThreshold, minSilenceDuration)
            reaper.UpdateArrange()
        end
        if thresholdChanged or minDurChanged then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if item then
                local track = reaper.GetMediaItem_Track(item)
                local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)        
                cleanup()
                createSilenceItems(track, silences, itemPosition)
            else
                showMessage("No item selected.", "Error")
                cleanup()
            end
        end

        -- Check if Enter key is pressed
        if reaper.ImGui_IsKeyPressed(ctx, 13, false) then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error")
                cleanup()
                return
            end
            local track = reaper.GetMediaItem_Track(item)
            cleanup()
            main(silenceThreshold, minSilenceDuration)
            reaper.UpdateArrange()
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

isValid = init()
if isValid then
    reaper.defer(loop)
end