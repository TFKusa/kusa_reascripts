-- @description kusa_Peaks and Valleys - Sound Iterations Manager
-- @version 1.50
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog - Optimising performances


local function print(string)
    reaper.ShowConsoleMsg(string .. "\n")
end

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

if not reaper.APIExists("ImGui_GetVersion") then
    showMessage("This script requires ReaImGui to run. Please install it with ReaPack.", "Error", 0)
    return
end

local silenceItems = {}
local lastTrack = nil

-------------------------------------------------------------------------------------------
------------------------------GENERAL FUNCTIONS--------------------------------------------
-------------------------------------------------------------------------------------------

local function getChannelsOfSelectedItem(take)
    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil end

    local channels = reaper.GetMediaSourceNumChannels(source)
    return channels
end

local function selectNextTrack(currentTrack)
    local currentTrackIndex = reaper.GetMediaTrackInfo_Value(currentTrack, "IP_TRACKNUMBER") - 1
    local totalTracks = reaper.CountTracks(0)
    local nextTrackIndex = currentTrackIndex + 1
    if nextTrackIndex < totalTracks then
        local nextTrack = reaper.GetTrack(0, nextTrackIndex)
        reaper.SetOnlyTrackSelected(nextTrack)
    else
        showMessage("No next track available.", "Error", 0)
    end
end

local function cleanupAfterRender(item, track)
    reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0)
    local itemCount = reaper.GetTrackNumMediaItems(track)
    for i = 0, itemCount - 1 do
        local trackItem = reaper.GetTrackMediaItem(track, i)
        local trackItemPosition = reaper.GetMediaItemInfo_Value(trackItem, "D_POSITION")
        if trackItemPosition == itemPosition then
            reaper.SetMediaItemInfo_Value(trackItem, "B_MUTE", 1)
            break
        end
    end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE_ACTUAL", 1)
    reaper.Main_OnCommand(40635, 0) -- Time selection: Remove (unselect) time selection
end

local function addFades()
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.00001)
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.1)
    end
end

local function promptUserForNumber(promptTitle, fieldName)
    local userInputsOK, userInput = reaper.GetUserInputs(promptTitle, 1, fieldName, "")
    if userInputsOK then
        local numberInput = tonumber(userInput)
        if numberInput then
            return numberInput
        else
            showMessage("Please enter a valid number.", "Invalid Input", 0)
        end
    end
    return nil
end

local function alignItemWithMarker(markerId, peakTime, alignOnStart)
    local MAX_SEARCH_ITERATIONS = 1000
    local retval, isRegion, position, rgnEnd, name, markrgnIdxNumber, color
    local idx = 0
    local found = false

    repeat
        retval, isRegion, position, rgnEnd, name, markrgnIdxNumber, color = reaper.EnumProjectMarkers3(0, idx)
        if retval and not isRegion and markrgnIdxNumber == markerId then
            found = true
            break
        end
        idx = idx + 1
        if idx >= MAX_SEARCH_ITERATIONS then
            showMessage("Searched for " .. MAX_SEARCH_ITERATIONS .. " markers. Marker ID not found.", "Error", 0)
            return
        end
    until not retval

    if found then
        local selectedItem = reaper.GetSelectedMediaItem(0, 0)
        if selectedItem then
            if alignOnStart then
                reaper.SetMediaItemInfo_Value(selectedItem, "D_POSITION", position)
            else
                local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
                local peakOffset = peakTime - selectedItemPosition
                reaper.SetMediaItemInfo_Value(selectedItem, "D_POSITION", position - peakOffset)
            end
        end
    else
        showMessage("Marker with ID " .. markerId .. " not found.", "Error", 0)
    end
end

local function spaceSelectedItems(amount)
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount < 2 then return end
    local prevItem = reaper.GetSelectedMediaItem(0, 0)
    local prevItemEnd = reaper.GetMediaItemInfo_Value(prevItem, "D_LENGTH") + reaper.GetMediaItemInfo_Value(prevItem, "D_POSITION")
    for i = 1, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local newPosition = prevItemEnd + amount
        reaper.SetMediaItemPosition(item, newPosition, false)
        prevItemEnd = newPosition + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    end
end



local function getSelectedItemPlayrate(take)
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    return playrate
end

local function hasBeenStretchedFunction(take, item, track)
    local retval, pos, srcpos = reaper.GetTakeStretchMarker(take, 0)
    local playrate = getSelectedItemPlayrate(take)
    if retval ~= -1 or playrate ~= 1 then
        local userChoice = showMessage("The item's playrate has been altered, analysing it will freeze REAPER. Would you like to render it now ? (keeps original)", "Warning", 4)
        if userChoice == 6 then
            local originalTrack = track
            reaper.Main_OnCommand(40290, 0) -- Set time selection to item
            local numChannels = getChannelsOfSelectedItem(take)
            reaper.SetOnlyTrackSelected(track)
            if numChannels == 1 then
                reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERMONOSMART"), 0)
            else
                reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWRENDERSTEREOSMART"), 0)
            end
            cleanupAfterRender(item, originalTrack)
            return true
        else
        return true
        end
    else
        return false
    end
end

-------------------------------------------------------------------------------------------
-------------------------------------BUFFER------------------------------------------------
-------------------------------------------------------------------------------------------

local function calculateDownsamplingFactor(totalSamples, numChannels)
    local maxBufferSize = 4159674
    local maxSamplesPerChannel = maxBufferSize / numChannels
    return math.max(1, math.ceil(totalSamples / maxSamplesPerChannel))
end

local function prepareItemAnalysis(item, take)
    if not take then return end
    local accessor = reaper.CreateTakeAudioAccessor(take)
    local retval, currentSampleRate = reaper.GetAudioDeviceInfo("SRATE")
    local sampleRate = tonumber(currentSampleRate)
    if not sampleRate then
        showMessage("Sample Rate could not be found. Is the Audio Device set ?", "Whoops", 0)
        return
    end
    local numChannels = getChannelsOfSelectedItem(take)
    local startTime = reaper.GetAudioAccessorStartTime(accessor)
    local endTime = reaper.GetAudioAccessorEndTime(accessor)
    return accessor, sampleRate, numChannels, startTime, endTime
end

local function calculateTotalSamples(startTime, endTime, sampleRate)
    return math.floor((endTime - startTime) * sampleRate)
end

local function populateBufferWithDownsampling(accessor, sampleRate, numChannels, startTime, totalSamples, isSilence)
    local downsamplingFactor = calculateDownsamplingFactor(totalSamples, numChannels)
    if isSilence then
        downsamplingFactor = downsamplingFactor * 8
    end
    local totalBlocks = math.ceil(totalSamples / downsamplingFactor)
    local buffer = reaper.new_array(totalBlocks * numChannels)
    buffer.clear()
    for i = 0, totalBlocks - 1 do
        local blockStartTime = startTime + (i * downsamplingFactor / sampleRate)
        local blockBuffer = reaper.new_array(numChannels)
        blockBuffer.clear()
        reaper.GetAudioAccessorSamples(accessor, sampleRate, numChannels, blockStartTime, 1, blockBuffer)
        for ch = 1, numChannels do
            buffer[i * numChannels + ch] = blockBuffer[ch]
        end
    end
    return buffer, downsamplingFactor, totalBlocks
end


local function getBufferReady(item, isSilence, take)
    local accessor, sampleRate, numChannels, startTime, endTime = prepareItemAnalysis(item, take)
    if not sampleRate then return end
    local totalSamples = calculateTotalSamples(startTime, endTime, sampleRate)
    local buffer, downsamplingFactor, numSamplesInBuffer = populateBufferWithDownsampling(accessor, sampleRate, numChannels, startTime, totalSamples, isSilence)
    return buffer, numSamplesInBuffer, numChannels, downsamplingFactor, accessor, sampleRate, startTime
end

-------------------------------------------------------------------------------------------
--------------------------------------PEAK-------------------------------------------------
-------------------------------------------------------------------------------------------

local function findPeakInBuffer(buffer, numSamplesInBuffer, numChannels, downsamplingFactor)
    local peakValue = 0
    local peakIndex = 0
    for i = 1, numSamplesInBuffer do
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

local function calculatePeakTime(take, item, peakIndex, sampleRate)
    local takeStartOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local peakTimeRelativeToSource = takeStartOffset + (peakIndex / sampleRate)
    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTimeRelativeToProject = itemPosition + peakTimeRelativeToSource
    local itemStartPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local peakTime = itemStartPos + (peakIndex / sampleRate)

    if peakTimeRelativeToSource < 0 then peakTimeRelativeToSource = 0 end
    return peakTime
end

local function getPeakTime(item, take)
    local isSilence = false
    local peakBuffer, numSamplesInBuffer, numChannels, downsamplingFactor, peakAccessor, sampleRate, startTime = getBufferReady(item, isSilence, take)
    if not sampleRate then return end
    local peakValue, peakIndex = findPeakInBuffer(peakBuffer, numSamplesInBuffer, numChannels, downsamplingFactor)
    local peakTime = calculatePeakTime(take, item, peakIndex, sampleRate)
    reaper.DestroyAudioAccessor(peakAccessor)
    return peakTime
end

-------------------------------------------------------------------------------------------
------------------------------------SILENCES-----------------------------------------------
-------------------------------------------------------------------------------------------

local function detectSilences(buffer, silenceThreshold, minSilenceDuration, sampleRate, downsamplingFactor, numChannels)
    local silences = {}
    local silenceStartIndex = nil
    local currentSilenceDuration = 0
    local minSilenceSamples = minSilenceDuration * sampleRate / downsamplingFactor * numChannels

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

local function convertSilencesToTime(silences, startTime, sampleRate, downsamplingFactor, numChannels)
    local silencesInTime = {}
    for _, silence in ipairs(silences) do
        local startInTime = startTime + ((silence.start / numChannels) * downsamplingFactor - downsamplingFactor) / sampleRate
        local endInTime = startTime + ((silence["end"] / numChannels) * downsamplingFactor - downsamplingFactor) / sampleRate
        table.insert(silencesInTime, { start = startInTime, ["end"] = endInTime })
    end
    return silencesInTime
end


local function deleteSilencesFromItem(item, silences)
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

local function deleteShortItems(coeff)
    local selectedItemsCount = reaper.CountSelectedMediaItems(0)
    if selectedItemsCount == 0 then return end

    local totalLength = 0
    for i = 0, selectedItemsCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        totalLength = totalLength + length
    end

    local averageLength = totalLength / selectedItemsCount
    local minLength = averageLength / coeff

    for i = selectedItemsCount - 1, 0, -1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        if length < minLength then
            local track = reaper.GetMediaItem_Track(item)
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
end

local function createTemporaryItems(track, silences, itemPosition)
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

local function clearTemporaryItems(track)
    for _, item in ipairs(silenceItems) do
        if reaper.ValidatePtr(item, "MediaItem*") then
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
    silenceItems = {}
end

local function cleanup()
    if lastTrack then
        clearTemporaryItems(lastTrack)
        reaper.UpdateArrange()
    end
end

local function getSilenceTime(item, take)
    local isSilence = true
    local silenceBuffer, numSamplesInBuffer, numChannels, downsamplingFactor, silenceAccessor, sampleRate, startTime = getBufferReady(item, isSilence, take)
    if not sampleRate then return end
    local silences = detectSilences(silenceBuffer, silenceThreshold, minSilenceDuration, sampleRate, downsamplingFactor, numChannels)
    local silencesInTime = convertSilencesToTime(silences, startTime, sampleRate, downsamplingFactor, numChannels)
    reaper.DestroyAudioAccessor(silenceAccessor)
    return silencesInTime
end

-------------------------------------------------------------------------------------------
---------------------------------MAIN FUNCTIONS--------------------------------------------
-------------------------------------------------------------------------------------------

local function implodeToTakesKeepPosition()
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

local function alignItemsByPeakTime()
    local numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 2 then return end

    local firstItem = reaper.GetSelectedMediaItem(0, 0)
    local takeFirstItem = reaper.GetActiveTake(firstItem)
    local firstPeakTime = getPeakTime(firstItem, takeFirstItem)
    if not firstPeakTime then return end

    for i = 1, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local peakTime = getPeakTime(item, take)
        if not peakTime then return end
        if peakTime then
            local offset = firstPeakTime - peakTime
            local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local newPosition = itemPosition + offset
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", newPosition)
        end
    end
    return firstPeakTime
end

local function alignItemsByStartPosition()
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
    return earliestStart
end

local function splitMain(item, take, splitAndSpace, silencesInLoop)
    deleteSilencesFromItem(item, silencesInLoop)
    deleteShortItems(3)
    if splitAndSpace then
        spaceSelectedItems(1)
        addFades()
    end
end

local function implodeMain(item, take, onPeak, shouldAlignToMarker, alignOnStart, silencesInLoop)
    reaper.Undo_BeginBlock()
    local splitAndSpace = false
    splitMain(item, take, splitAndSpace, silencesInLoop)
    if onPeak then
        firstPeakTime = alignItemsByPeakTime()
        if not firstPeakTime then return end
    else
        alignItemsByStartPosition()
    end
    addFades()
    implodeToTakesKeepPosition()
    if shouldAlignToMarker then
        local userMarkerChoice = promptUserForNumber("Align with marker", "Please enter the Marker ID")
        if firstPeakTime ~= nil then
            alignItemWithMarker(userMarkerChoice, firstPeakTime, alignOnStart)
        else
            showMessage("Could not retrieve Peak Amplitude. Was the item already collapsed ?", "Whoops!", 0)
        end
    end
    reaper.Undo_EndBlock("Implode to takes.", -1)
end

-------------------------------------------------------------------------------------------
---------------------------------------UI--------------------------------------------------
-------------------------------------------------------------------------------------------

local ctx = reaper.ImGui_CreateContext('Peaks and Valleys by Kusa')

silenceThreshold = 0.01
minSilenceDuration = 0.2

local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "Peaks and Valleys by Kusa", true)
    if visible then
        local selectedItem = reaper.GetSelectedMediaItem(0, 0)
        if not selectedItem then
            cleanup()
        end
        local thresholdChanged
        local minDurChanged
        local alignToMarkerChanged = false
        local hasBeenStretched = false
        thresholdChanged, silenceThreshold = reaper.ImGui_SliderDouble(ctx, 'Threshold', silenceThreshold, 0.001, 0.3, "%.3f")       
        minDurChanged, minSilenceDuration = reaper.ImGui_SliderDouble(ctx, 'Min Duration', minSilenceDuration, 0.001, 2.0, "%.3f")
        if thresholdChanged or minDurChanged then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if item then
                local track = reaper.GetMediaItem_Track(item)
                local take = reaper.GetActiveTake(item)
                hasBeenStretched = hasBeenStretchedFunction(take, item, track)
                if not hasBeenStretched then  
                    local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    silencesInLoop = getSilenceTime(item, take)
                    if silencesInLoop then   
                        cleanup()
                        createTemporaryItems(track, silencesInLoop, itemPosition)
                    end
                end
            else
                showMessage("No item selected.", "Error", 0)
                cleanup()
            end
        end
        alignToMarkerChanged, shouldAlignToMarker = reaper.ImGui_Checkbox(ctx, "Align to marker", shouldAlignToMarker)
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Takes (peak)') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local take = reaper.GetActiveTake(item)
                local track = reaper.GetMediaItem_Track(item)
                hasBeenStretched = hasBeenStretchedFunction(take, item, track)
                if not hasBeenStretched then
                    cleanup()
                    local onPeak = true
                    local alignOnStart = false
                    implodeMain(item, take, onPeak, shouldAlignToMarker, alignOnStart, silencesInLoop)
                    reaper.UpdateArrange()
                else
                    cleanup()   
                end
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Takes (start)') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local take = reaper.GetActiveTake(item)
                local track = reaper.GetMediaItem_Track(item)
                hasBeenStretched = hasBeenStretchedFunction(take, item, track)
                if not hasBeenStretched then
                    cleanup()
                    local onPeak = false
                    local alignOnStart = true
                    implodeMain(item, take, onPeak, shouldAlignToMarker, alignOnStart, silencesInLoop)
                    reaper.UpdateArrange()
                else
                    cleanup()   
                end
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Split and space items') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local take = reaper.GetActiveTake(item)
                local track = reaper.GetMediaItem_Track(item)
                hasBeenStretched = hasBeenStretchedFunction(take, item, track)
                if not hasBeenStretched then
                    cleanup()
                    local splitAndSpace = true
                    splitMain(item, take, splitAndSpace, silencesInLoop)
                    addFades()
                    reaper.UpdateArrange()
                else
                    cleanup()   
                end
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Split') then
            local item = reaper.GetSelectedMediaItem(0, 0)
            if not item then
                showMessage("No Item selected.", "Error", 0)
                cleanup()
            else
                local take = reaper.GetActiveTake(item)
                local track = reaper.GetMediaItem_Track(item)
                hasBeenStretched = hasBeenStretchedFunction(take, item, track)
                if not hasBeenStretched then
                    cleanup()
                    local splitAndSpace = false
                    splitMain(item, take, splitAndSpace, silencesInLoop)
                    addFades()
                    reaper.UpdateArrange()
                else
                    cleanup()   
                end
            end
        end
        reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    end
end

reaper.defer(loop)