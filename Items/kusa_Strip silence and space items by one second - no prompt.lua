-- @description kusa_Strip silence and space items by one second - no prompt
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

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
        local silenceStart = itemPosition + silence.start + 0.1
        local silenceEnd = itemPosition + silence["end"] - 0.1

        local splitItemEnd = reaper.SplitMediaItem(item, silenceEnd)
        
        local splitItemStart = reaper.SplitMediaItem(item, silenceStart)
        
        if splitItemStart and splitItemEnd then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(splitItemEnd), splitItemStart)
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

function spaceSelectedItemsByOneSecond()
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount < 2 then return end

    local prevItem = reaper.GetSelectedMediaItem(0, 0)
    local prevItemEnd = reaper.GetMediaItemInfo_Value(prevItem, "D_LENGTH") + reaper.GetMediaItemInfo_Value(prevItem, "D_POSITION")

    for i = 1, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local newPosition = prevItemEnd + 1
        reaper.SetMediaItemPosition(item, newPosition, false)
        prevItemEnd = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + newPosition
    end
end

function main()
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    local minSilenceDuration = 0.2
    local silenceThreshold = 0.004
    silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    deleteSilencesFromItem(item, silences)
    addFades()
    spaceSelectedItemsByOneSecond()
    reaper.Undo_EndBlock("Split and align to takes", -1)
    reaper.UpdateArrange()
end

main()