-- @description kusa_Strip silence and space items by one second
-- @version 1.1
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function print(string)
    reaper.ShowConsoleMsg(string .. "\n")
end

local function tableToString(tbl, depth)
    if depth == nil then depth = 1 end
    if depth > 5 then return "..." end

    local str = "{"
    for k, v in pairs(tbl) do
        local key = tostring(k)
        local value = type(v) == "table" and tableToString(v, depth + 1) or tostring(v)
        str = str .. "[" .. key .. "] = " .. value .. ", "
    end
    str = str:sub(1, -3)
    str = str .. "}"
    return str
end

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
--[[     else
        showMessage("No item selected.", "Error")
        return false ]]
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
        local silenceStart = itemPosition + silence.start + 0.15   ---------------------------------- + 0.15
        local silenceEnd = itemPosition + silence["end"] - 0.01    ---------------------------------- - 0.15

        local splitItemEnd = reaper.SplitMediaItem(item, silenceEnd)
        
        local splitItemStart = reaper.SplitMediaItem(item, silenceStart)
        
        if splitItemStart and splitItemEnd then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(splitItemEnd), splitItemStart)
        end
    end
end

function deleteShortItems(track)
    local numItems = reaper.CountTrackMediaItems(track)
    if numItems == 0 then return end

    local totalLength = 0
    for i = 0, numItems - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        totalLength = totalLength + length
    end

    local averageLength = totalLength / numItems
    local minLength = averageLength / 5
    for i = numItems - 1, 0, -1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        if length < minLength then
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

function addFades()
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.01)
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

function main(silenceThreshold, minSilenceDuration)
    reaper.Undo_BeginBlock()
    local item = reaper.GetSelectedMediaItem(0, 0)
    silences = findAllSilencesInItem(item, silenceThreshold, minSilenceDuration)
    deleteSilencesFromItem(item, silences)
    local track = reaper.GetMediaItem_Track(item)
    deleteShortItems(track)
    addFades()
    spaceSelectedItemsByOneSecond()
    reaper.Undo_EndBlock("Split and align to takes", -1)
    reaper.UpdateArrange()
end

-- Global or higher scope variables
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

local ctx = reaper.ImGui_CreateContext("kusa_Strip silence")

local silenceThreshold = 0.01
local minSilenceDuration = 0.2

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "kusa_Strip silence", true)
    if visible then
        local changed
        thresholdChanged, silenceThreshold = reaper.ImGui_SliderDouble(ctx, 'Silence Threshold (0-1)', silenceThreshold, 0.0, 0.5, "%.3f")
        
        minDurChanged, minSilenceDuration = reaper.ImGui_SliderDouble(ctx, 'Minimum Silence Duration (seconds)', minSilenceDuration, 0.0, 2.0, "%.3f")

        if reaper.ImGui_Button(ctx, 'Go') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error")
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration)
                reaper.UpdateArrange()
            end
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

        -- Check if Enter key is pressed using ASCII code
        if reaper.ImGui_IsKeyPressed(ctx, 13, false) then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error")
                cleanup()
            else
                local track = reaper.GetMediaItem_Track(item)
                cleanup()
                main(silenceThreshold, minSilenceDuration)
                reaper.UpdateArrange()
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

init()
reaper.defer(loop)