-- @description kusa_Implode soundbank iterations from block to takes
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    local take = reaper.GetActiveTake(item)
    if not take then return nil end

    local accessor = reaper.CreateTakeAudioAccessor(take)
    local sampleRate = getSampleRateOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    local numSamples = math.floor((endTime - startTime) * sampleRate)

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
        local silenceEnd = itemPosition + silence["end"] - 0.15

        local splitItemEnd = reaper.SplitMediaItem(item, silenceEnd)
        
        local splitItemStart = reaper.SplitMediaItem(item, silenceStart)
        
        if splitItemStart and splitItemEnd then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(splitItemEnd), splitItemStart)
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

function padItemsToMatchLength()
    local numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 2 then return end

    local earliestStart = math.huge
    local latestEnd = 0

    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemStart + itemLength
    
        if itemStart < earliestStart then earliestStart = itemStart end
        if itemEnd > latestEnd then latestEnd = itemEnd end
    end
    reaper.GetSet_LoopTimeRange(true, false, earliestStart, latestEnd, false)
    reaper.Main_OnCommand(41385, 0)
    reaper.Main_OnCommand(40635, 0)
end

function addFades()
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.1)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.1)
    end
end

function main()
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    local minSilenceDuration = 0.2
    local silenceThreshold = 0.0001
    silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    deleteSilencesFromItem(item, silences)
    alignItemsByPeakTime()
    padItemsToMatchLength()
    addFades()
    reaper.Main_OnCommand(40543, 0)
    reaper.Undo_EndBlock("Split and align to takes", -1)
    reaper.UpdateArrange()
end

main()