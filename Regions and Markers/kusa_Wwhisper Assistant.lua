-- @description kusa_Wwhisper Assistant
-- @version 2.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog :
--      # Can sync to Wwise to retrieve Event, RTPC, States and Switches names.
--      # New way of setting RTPC values. See documentation for further details.
--      # Can import a TXT Wwise Capture Log.
--      # Please have a look at the updated documentation : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/WWHISPER%20-%20DOCUMENTATION.md

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- INIT CHECKS

local reaImguiAvailable = reaper.APIExists("ImGui_Begin")
if not reaImguiAvailable then
    reaper.MB("This script requires ReaImGui. Please install it via ReaPack.", "Whoops !", 0)
    return
end

if not reaper.APIExists("CF_GetSWSVersion") then
    local userChoice = reaper.ShowMessageBox("This script requires the SWS Extension to run. Would you like to download it now ?", "Whoops !", 4)
    if userChoice == 6 then
        reaper.CF_ShellExecute("https://www.sws-extension.org/")
        return
    else
        return
    end
end

local function print(string)
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
    str = str .. "}" .. "\n"
    return str
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- INIT VARIABLES

local colors = {}

if os.getenv("HOME") ~= nil then
    colors = {
        {name = "Red", value = 33226752},
        {name = "Green", value = 16830208},
        {name = "Blue", value = 16806892},
        {name = "Yellow", value = 0},
        {name = "Orange", value = 32795136},
        {name = "Purple", value = 28901614},
        }
else
    colors = {
        {name = "Red", value = 16777471},
        {name = "Green", value = 16809984},
        {name = "Blue", value = 33226752},
        {name = "Yellow", value = 16842751},
        {name = "Orange", value = 16810239},
        {name = "Purple", value = 33489151},
        }
end   

local selectedColorValue = colors[1].value


local eventNamesTable = {}
local rtpcNamesTable = {}
local switchGroupNamesTable = {}
local switchNamesTable = {}
local stateGroupNamesTable = {}
local stateNamesTable = {}

local rtpcData = {}

local showRTPCMinMax = false
local selectedRTPC = ""

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- WINDOW LAYOUT

local generalItemWidth = 200
local windowWidth = 910
local windowHeight = 510

local showRightSection = false

local rightSectionWidthRatio = 0.47

local rightSectionWidth = windowWidth * rightSectionWidthRatio
local leftSectionWidth = windowWidth - rightSectionWidth - 4

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- SIMPLE FUNCTIONS

local function getActiveTakeOfFirstItemOnTrack(track)
    local item = reaper.GetTrackMediaItem(track, 0)
    if item then
        return reaper.GetActiveTake(item)
    end
    return nil
end

local function getNearestTakeMarker(playPosition, sortedTakeMarkers)
    local closestDist = math.huge
    local closestIndex = -1
    local closestPos = 0
    local closestName = ""

    for i, marker in ipairs(sortedTakeMarkers) do
        local dist = math.abs(marker.adjustedPos - playPosition)
        if dist < closestDist then
            closestDist = dist
            closestIndex = i
            closestPos = marker.adjustedPos
            closestName = marker.name
            color = marker.color
        end
    end

    return closestIndex, closestPos, closestName, color
end

local function concatenateWithSemicolon(...)
    local args = {...}
    local concatenatedString = table.concat(args, ";")
    
    return concatenatedString
end

local function inputText(ctx, label, var)
    reaper.ImGui_SetNextItemWidth(ctx, generalItemWidth)
    local _, newValue = reaper.ImGui_InputText(ctx, label, var)
    return newValue or var
end

local function isJSFXInstalled(pluginName)
    local found = false
    local index = 0
    while true do
        local retval, name, ident = reaper.EnumInstalledFX(index)
        if not retval then break end
        if name:find(pluginName) then
            found = true
            break
        end
        index = index + 1
    end

    return found
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- SPECIFIC FUNCTIONS

local function collectAndSortAllTakeMarkersByPos()
    local markerData = {}
    local selectedItemCount = reaper.CountSelectedMediaItems(0)

    for i = 0, selectedItemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        for takeIndex = 0, reaper.CountTakes(item) - 1 do
            local take = reaper.GetMediaItemTake(item, takeIndex)
            if take then
                local takeMarkerCount = reaper.GetNumTakeMarkers(take)
                for k = 0, takeMarkerCount - 1 do
                    local retval, name, color = reaper.GetTakeMarker(take, k)
                    if retval ~= -1 then
                        local adjustedMarkerPos = itemPos + retval
                        table.insert(markerData, {name = name, adjustedPos = adjustedMarkerPos, take = take, color = color})
                    end
                end
            end
        end
    end

    table.sort(markerData, function(a, b) return a.adjustedPos < b.adjustedPos end)

    return markerData
end

local function duplicateTakeMarker(sortedTakeMarkers, closestIndex, closestPos, closestName, color)
    if closestIndex ~= -1 then
        local markerData = sortedTakeMarkers[closestIndex]
        local take = markerData.take
        
        if take then
            local item = reaper.GetMediaItemTake_Item(take)
            if item then
                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local newPosRelative = closestPos - itemPos + 0.1
                local newMarkerIndex = reaper.SetTakeMarker(take, -1, closestName, newPosRelative, color)
            else
                reaper.ShowMessageBox("Failed to get the media item for the take.", "Whoops !", 0)
            end
        else
            reaper.ShowMessageBox("No take associated with the marker.", "Whoops !", 0)
        end
    else
        reaper.ShowMessageBox("No item selected, or no marker found near the play cursor.", "Whoops !", 0)
    end
end


local function duplicateNearestMarker()
    local playPosition = reaper.GetCursorPosition()
    local sortedTakeMarkers = collectAndSortAllTakeMarkersByPos()
    local closestIndex, closestPos, closestName, color = getNearestTakeMarker(playPosition, sortedTakeMarkers)
    duplicateTakeMarker(sortedTakeMarkers, closestIndex, closestPos, closestName, color)
end

local function deleteNearestMarker()
    local playPosition = reaper.GetCursorPosition()
    local sortedTakeMarkers = collectAndSortAllTakeMarkersByPos()
    local closestIndex, closestPos, closestName, color = getNearestTakeMarker(playPosition, sortedTakeMarkers)

    if closestIndex ~= -1 then
        local markerToDelete = sortedTakeMarkers[closestIndex]
        if markerToDelete and markerToDelete.take then
            reaper.DeleteTakeMarker(markerToDelete.take, closestIndex - 1)
        end
    end
end


local function handlePannerFX(track)
    local pluginName = "JS: kusa_Wwhisper Params"

    local found = isJSFXInstalled(pluginName)
    
    local shouldStop
    local fxIndex
    if found then
        fxIndex = reaper.TrackFX_GetByName(track, pluginName, true)
        local numParams = reaper.TrackFX_GetNumParams(track, fxIndex)
        for paramIndex = 0, math.min(3, numParams) - 1 do
            local envelope = reaper.GetFXEnvelope(track, fxIndex, paramIndex, true)
        end
        shouldStop = false
    else
        reaper.DeleteTrack(track)
        local userChoice = reaper.ShowMessageBox(pluginName .. " is not installed. It is required for spatialisation. Would you like to visit the documentation ?", "Whoops !", 4)
        if userChoice == 6 then
            reaper.CF_ShellExecute("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/WWHISPER%20-%20DOCUMENTATION.md")
        end
        shouldStop = true
    end
    return shouldStop
end

local function pannerOnTrackSetup(track)
    reaper.SetTrackAutomationMode(track, 4) -- 4 = Latch
    local shouldStop = handlePannerFX(track)
    return shouldStop
end

local function handleTrackForMIDIItem(gameObjectName)
    local trackIndex
    local selectedTrack = reaper.GetSelectedTrack(0, 0)
    if selectedTrack then
        trackIndex = reaper.GetMediaTrackInfo_Value(selectedTrack, "IP_TRACKNUMBER")
    else
        trackIndex = reaper.GetNumTracks()
    end
    reaper.InsertTrackAtIndex(trackIndex, true)

    local newTrack
    if selectedTrack then
        newTrack = reaper.GetTrack(0, trackIndex)
    else
        newTrack = reaper.GetTrack(0, trackIndex)
    end
    reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", gameObjectName, true)
    local shouldStop = pannerOnTrackSetup(newTrack)
    return shouldStop, newTrack
end

local function getStartEndPointSelectionOrSelectedItem()
    local loopStartTime, loopEndTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local itemStart, itemEnd
    if loopStartTime == loopEndTime then
        local item = reaper.GetSelectedMediaItem(0, 0)
        if item then
            itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            itemEnd = itemStart + itemLength
        else
            reaper.ShowMessageBox("No item selected or time selection.", "Whoops !", 0)
            return
        end
    else
        itemStart = loopStartTime
        itemEnd = loopEndTime
    end

    return itemStart, itemEnd
end


local function createGameObjectTrack(gameObjectName)
    local itemStart, itemEnd = getStartEndPointSelectionOrSelectedItem()
    if itemStart and itemEnd then
        local shouldStop, track = handleTrackForMIDIItem(gameObjectName)
        if not shouldStop then
            local midiItem = reaper.CreateNewMIDIItemInProj(track, itemStart, itemEnd, false)
            reaper.SetMediaItemInfo_Value(midiItem, "B_LOOPSRC", 0)
        else return end
    end
end

local function handleMarkerColor(currentColorIndex)
    local colorConfig = colors[currentColorIndex + 1]
    local currentColorValue = colorConfig.value
    return currentColorValue
end

local ctx = reaper.ImGui_CreateContext('Wwhisper - Marker Creator')


local currentOption = 0
local currentColorIndex = 0
local markerName

local inputs = {
    inputTextName = "",
    inputTextGameObjectName = "",
    inputTextValue = "",
    inputTextMinValue = "",
    inputTextMaxValue = "",
    inputTextInterpTime = "",
    inputTextChildName = "",
}

local eventTypeConfig = {
    {eventType = "Event", fields = {{"Event name", "inputs.inputTextName"}}},
    {eventType = "RTPC", fields = {{"RTPC name", "inputs.inputTextName"}, {"Min Value", "inputs.inputTextMinValue"}, {"Max Value", "inputs.inputTextMaxValue"}}},
    {eventType = "State", fields = {{"State group name", "inputs.inputTextName"}, {"State name", "inputs.inputTextChildName"}}},
    {eventType = "Switch", fields = {{"Switch group name", "inputs.inputTextName"}, {"Switch name", "inputs.inputTextChildName"}}},
    {eventType = "InitObj;"},
    {eventType = "UnRegObj;"},
    {eventType = "ResetAllObj;", fields = {}}
}
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- Generate project from profiler txt




local function isValidLine(line)
    return not line:match("^Timestamp") and line:match("%S")
end

local function shouldProcessObjectSimple(objectType)
    return objectType == "Event" or objectType == "Switch" or objectType == "State Changed"
end

local function extractDescription(description)
    return description and description:match("\"([^\"]*)\"") or ""
end

local function insertResult(results, timestamp, objectType, objectName, gameObject, description, posOrValue, interpTime)
    table.insert(results, {
        timestamp = timestamp,
        objectType = objectType,
        objectName = objectName,
        gameObject = gameObject,
        description = description,
        posOrValue = posOrValue,
        interpTime = interpTime
    })
end

local function shouldProcessObjectPosition(description)
    return string.sub(description, 1, 11) == "SetPosition"
end

local function shouldProcessObjectRTPC(description)
    return string.sub(description, 1, 13) == "SetRTPCValue:"
end

local function shouldProcessObjectRTPCInterp(description)
    return string.sub(description, 1, 27) == "SetRTPCValueWithTransition:"
end

local function shouldProcessObjectInit(description)
    return string.sub(description, 1, 15) == "RegisterGameObj"
end

local function parsePositionGameObject(description)

    local positionsTable = {}
    local positionPattern = "Position:%(X:(%-?%d+%.?%d*),Y:(%-?%d+%.?%d*),Z:(%-?%d+%.?%d*)%)"
    local posX, posY, posZ = string.match(description, positionPattern)
    positionsTable["Position"] = {X = posX, Y = posY, Z = posZ}

    local orientationFrontPattern = "Front:%(X:(%-?%d+%.?%d*[eE]?%-?%d*),Y:(%-?%d+%.?%d*[eE]?%-?%d*),Z:(%-?%d+%.?%d*[eE]?%-?%d*)%)"
    local frontX, frontY, frontZ = string.match(description, orientationFrontPattern)
    positionsTable["OrientationFront"] = {X = frontX, Y = frontY, Z = frontZ}
    
    local orientationTopPattern = "Top:%(X:(%-?%d+%.?%d*[eE]?%-?%d*),Y:(%-?%d+%.?%d*[eE]?%-?%d*),Z:(%-?%d+%.?%d*[eE]?%-?%d*)%)"
    local topX, topY, topZ = string.match(description, orientationTopPattern)
    positionsTable["OrientationTop"] = {X = topX, Y = topY, Z = topZ}

    return positionsTable
end

local function parseRTPCGameObject(description)
    local rtpcPattern = "%s*(-?%d+%.?%d*)"
    local value = string.match(description, rtpcPattern)
    return value
end

local function parseRTPCInterpGameObject(description)
    local rtpcPattern = "Target Value:%s*(-?%d+%.?%d*[eE]?[+-]?%d*),%s*Over%s*(%d%d):(%d%d)%.(%d%d%d)%s*ms"
    local value, mins, secs, ms = string.match(description, rtpcPattern)
    value = tonumber(value)
    local interpTime = (tonumber(mins) * 60 + tonumber(secs)) * 1000 + tonumber(ms)
    local rtpcInterpTable = {
        value = value,
        interpTime = interpTime
    }

    return rtpcInterpTable
end


local function parseLogLine(line)
    local parts = {}
    for part in line:gmatch("[^\t]+") do
        table.insert(parts, part)
    end
    local gameObject = ""
    if (parts[2] == "Event" or parts[2] == "Switch" or parts[2] == "State Changed" or parts[2] == "API Call") then
        local timestamp = parts[1]
        local objectType = parts[2]
        local description = parts[3]
        local objectName = parts[4]
        if parts[2] == "State Changed" then
            gameObject = "Transport/Soundcaster"
        else
            gameObject = parts[5]
        end
        if shouldProcessObjectPosition(description) then 
            gameObject = parts[4]
        end

        if shouldProcessObjectRTPC(description) then
            if parts[7] then
                objectType = "SetRTPCValue"
            end
        end

        if shouldProcessObjectRTPCInterp(description) then
            if parts[7] then
                objectType = "SetRTPCValueInterp"
            end
        end

        if description:match("^\"") and description:match("\"$") then
            description = description:sub(2, -2) -- Remove leading and trailing quotes
        end

        return timestamp, objectType, description, objectName, gameObject
    else
        return nil
    end
end

local function filterConsecutiveEntries(entries)
    local filtered = {}
    local previous = nil
    local duplicates = {}

    local function addFromDuplicates()
        if #duplicates > 0 then
            table.insert(filtered, duplicates[1])
            if #duplicates > 1 then
                table.insert(filtered, duplicates[#duplicates])
            end
            duplicates = {}
        end
    end

    for _, entry in ipairs(entries) do
        if not previous or (previous.gameObject ~= entry.gameObject or previous.posOrValue.Position.X ~= entry.posOrValue.Position.X or previous.posOrValue.Position.Y ~= entry.posOrValue.Position.Y or previous.posOrValue.Position.Z ~= entry.posOrValue.Position.Z or previous.posOrValue.OrientationFront.X ~= entry.posOrValue.OrientationFront.X or previous.posOrValue.OrientationFront.Y ~= entry.posOrValue.OrientationFront.Y or previous.posOrValue.OrientationFront.Z ~= entry.posOrValue.OrientationFront.Z) then
            addFromDuplicates()
            table.insert(filtered, entry)
        else
            table.insert(duplicates, entry)
        end
        previous = entry
    end
    addFromDuplicates()

    return filtered
end

local function processLogFile(filePath)
    local file, err = io.open(filePath, "r")
    if not file then
        reaper.ShowMessageBox("Failed to open file: " .. err, "Error", 0)
        return
    end

    local results = {}
    for line in file:lines() do
        if isValidLine(line) then
            local timestamp, objectType, description, objectName, gameObject = parseLogLine(line)

            if shouldProcessObjectSimple(objectType) then
                local extractedDescription = extractDescription(description)
                insertResult(results, timestamp, objectType, objectName, gameObject, extractedDescription, nil, nil)
            elseif description then
                if shouldProcessObjectPosition(description) then
                    local positionsTable = parsePositionGameObject(description)
                    objectType = description:match("(%w+)}?")
                    insertResult(results, timestamp, objectType, _, gameObject, _, positionsTable, nil)
                elseif shouldProcessObjectRTPC(description) then
                    local rtpcValue = parseRTPCGameObject(description)
                    objetType = "SetRTPCValue"
                    insertResult(results, timestamp, objectType, objectName, gameObject, _, rtpcValue, nil)
                elseif shouldProcessObjectRTPCInterp(description) then
                    local rtpcInterpTable = parseRTPCInterpGameObject(description)
                    objetType = "SetRTPCValueInterp"
                    insertResult(results, timestamp, objectType, objectName, gameObject, _, rtpcInterpTable.value, rtpcInterpTable.interpTime)
                elseif shouldProcessObjectInit(description) then
                    local pattern = "RegisterGameObj:%s([%w_%.]+)%s%(%ID:(%d+)%)"
                    gameObject, _ = string.match(description, pattern)
                    objectType = "InitObj"
                    insertResult(results, timestamp, objectType, _, gameObject, _, _, _)
                end
            end
        end
    end
    
    file:close()
    return results
end

local function createTracksForGameObjects(entries)
    local uniqueGameObjects = {}
    local createdTracks = {}
    for _, entry in ipairs(entries) do
        if entry then
            uniqueGameObjects[entry.gameObject] = true
        end
    end
    for gameObjectName, _ in pairs(uniqueGameObjects) do
        local trackIndex = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(trackIndex, true)
        local track = reaper.GetTrack(0, trackIndex)

        if track then
            reaper.GetSetMediaTrackInfo_String(track, "P_NAME", gameObjectName, true)
            table.insert(createdTracks, {track = track, name = gameObjectName})
        end
    end
    return createdTracks
end

local function convertTimestampToSeconds(timestamp)
    local hours, minutes, seconds, milliseconds = timestamp:match("(%d+):(%d+):(%d+).(%d+)")
    hours = tonumber(hours)
    minutes = tonumber(minutes)
    seconds = tonumber(seconds)
    milliseconds = tonumber(milliseconds) / 1000
    return (hours * 3600) + (minutes * 60) + seconds + milliseconds
end

local function getTotalDurationInSeconds(entries)
    local minTimestamp = nil
    local maxTimestamp = nil
    local minTimestampValue = math.huge
    local maxTimestampValue = -math.huge

    for _, entry in ipairs(entries) do
        local timestampValue = convertTimestampToSeconds(entry.timestamp)
        if timestampValue < minTimestampValue then
            minTimestamp = entry.timestamp
            minTimestampValue = timestampValue
        end
        if timestampValue > maxTimestampValue then
            maxTimestamp = entry.timestamp
            maxTimestampValue = timestampValue
        end
    end
    local totalDurationInSeconds = maxTimestampValue - minTimestampValue + 1 -- Margin

    return totalDurationInSeconds, minTimestampValue
end

local function createMIDIItems(createdTracks, entries, totalDurationInSeconds)
    local createdItems = {}
    for _, trackInfo in ipairs(createdTracks) do
        local track = trackInfo.track
        local newItem = reaper.CreateNewMIDIItemInProj(track, 0, totalDurationInSeconds + 1)
        reaper.SetMediaItemInfo_Value(newItem, "B_LOOPSRC", 0)
        table.insert(createdItems, {item = newItem, track = track})
    end
    return createdItems
end

local function getColorValue(colors, colorName)
    for _, colorInfo in ipairs(colors) do
        if colorInfo.name == colorName then
            return colorInfo.value
        end
    end
    return 0
end

local function filterEntriesByType(entries, objectTypeFilter, offsetInSecondsToStartProject)
    local filteredEntries = {}
    for _, entry in ipairs(entries) do
        if entry.objectType == objectTypeFilter then
            local timestampInSeconds = convertTimestampToSeconds(entry.timestamp) - offsetInSecondsToStartProject
            table.insert(filteredEntries, {timestamp = timestampInSeconds, objectName = entry.objectName, gameObject = entry.gameObject, description = entry.description, posOrValue = entry.posOrValue, interpTime = entry.interpTime, initialValue = entry.initialValue, minValue = entry.minValue, maxValue = entry.maxValue})
        end
    end
    return filteredEntries
end

local function findTrackInTable(createdTracks, trackName)
    for _, trackInfo in ipairs(createdTracks) do
        if trackInfo.name == trackName then
            return trackInfo.track
        end
    end
    return nil
end

local function roundToNearest(value)
    if value ~= nil then
        if value >= 0 then
        return math.floor(value + 0.5)
        else
        return math.floor(value - 0.5)
        end
    end
end

local function findClosestRTPCMarkerBeforeTimestamp(take, timestamp, objectName)
    local numMarkers = reaper.GetNumTakeMarkers(take)
    local closestMarkerName = nil
    local closestMarkerPosition = -1
    local closestPattern = nil
    local patterns = {"RTPCLeg;", "RTPCInterp;"}

    for i = 0, numMarkers - 1 do
        local retval, name, _ = reaper.GetTakeMarker(take, i)
        local components = {}
        for str in string.gmatch(name, "([^;]+)") do
            table.insert(components, str)
        end
        local componentName = components[2]

        for _, pattern in ipairs(patterns) do
            -- Check if the name starts with the pattern, is before the timestamp, and COMPONENT2 matches objectName
            if retval and retval <= timestamp and string.sub(name, 1, string.len(pattern)) == pattern and componentName == objectName then
                if retval > closestMarkerPosition then
                    closestMarkerPosition = retval
                    closestMarkerName = name
                    closestPattern = pattern
                end
            end
        end
    end

    if closestMarkerName then
        closestPattern = string.sub(closestPattern, 1, -2)
    end

    return closestMarkerName, closestPattern
end


local function prepareForProfilerMarkers(entry, createdTracks)
    local track = findTrackInTable(createdTracks, entry.gameObject)
    if not track then
        local trackIndex = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(trackIndex, true)
        track = reaper.GetTrack(0, trackIndex)
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", entry.gameObject, true)
        table.insert(createdTracks, {track = track, name = entry.gameObject})
    end
    local item = reaper.GetTrackMediaItem(track, 0)
    local take = reaper.GetActiveTake(item)
    return take
end

local function gatherAllRTPCInfo()
    if reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
        local args = reaper.AK_AkJson_Map()

        local ofTypeArray = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(ofTypeArray, reaper.AK_AkVariant_String("GameParameter"))

        local from = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(from, "ofType", ofTypeArray)
        reaper.AK_AkJson_Map_Set(args, "from", from)

        local returnArray = reaper.AK_AkJson_Array()
        reaper.AK_AkJson_Array_Add(returnArray, reaper.AK_AkVariant_String("name"))
        reaper.AK_AkJson_Array_Add(returnArray, reaper.AK_AkVariant_String("min"))
        reaper.AK_AkJson_Array_Add(returnArray, reaper.AK_AkVariant_String("max"))
        reaper.AK_AkJson_Array_Add(returnArray, reaper.AK_AkVariant_String("initialValue"))
        
        local options = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(options, "return", returnArray)

        local dummy = reaper.AK_AkJson_Map()
    
        local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)
        
        if result then
            local status = reaper.AK_AkJson_GetStatus(result)
            if status then
                local rtpcs = reaper.AK_AkJson_Map_Get(result, "return")
                if rtpcs then
                    local numRtpcs = reaper.AK_AkJson_Array_Size(rtpcs)
                    if numRtpcs > 0 then
                        for i = 0, numRtpcs - 1 do
                            local rtpc = reaper.AK_AkJson_Array_Get(rtpcs, i)
                            local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(rtpc, "name"))
                            local minValue = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc, "min"))
                            local maxValue = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc, "max"))
                            local initialValue = reaper.AK_AkVariant_GetDouble(reaper.AK_AkJson_Map_Get(rtpc, "initialValue"))
                            table.insert(rtpcData, {name = name, minValue = minValue, maxValue = maxValue, initialValue = initialValue})
                        end
                    end
                end
            end
        else
            reaper.ShowConsoleMsg("Failed to call WAAPI.\n")
        end
        
    else
        reaper.ShowMessageBox("Could not connect to WAAPI. RTPC data could not be gathered", "Whoops!", 0)
    end
    return rtpcData
end

local function handleProfilerEvents(entries, offsetInSecondsToStartProject, createdTracks)
    local eventEntries = filterEntriesByType(entries, "Event", offsetInSecondsToStartProject)

    for _, entry in ipairs(eventEntries) do
        local take = prepareForProfilerMarkers(entry, createdTracks)
        local takeMarkerName = "Event;" .. entry.objectName
        local color = getColorValue(colors, "Red")
        reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
    end
end

local function handleProfilerSwitch(entries, offsetInSecondsToStartProject, createdTracks)

    local switchEntries = filterEntriesByType(entries, "Switch", offsetInSecondsToStartProject)
    for _, entry in ipairs(switchEntries) do
        local take = prepareForProfilerMarkers(entry, createdTracks)
        local takeMarkerName = "Switch;" .. entry.objectName .. ";" .. entry.description
        local color = getColorValue(colors, "Blue")
        reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
    end
end

local function handleProfilerState(entries, offsetInSecondsToStartProject, createdTracks)

    local stateEntries = filterEntriesByType(entries, "State Changed", offsetInSecondsToStartProject)
    for _, entry in ipairs(stateEntries) do
        local take = prepareForProfilerMarkers(entry, createdTracks)
        local takeMarkerName = "State;" .. entry.objectName .. ";" .. entry.description
        local color = getColorValue(colors, "Green")
        reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
    end
end

local function handleProfilerPosition(entries, offsetInSecondsToStartProject, createdTracks)
    local posEntries = filterEntriesByType(entries, "SetPosition", offsetInSecondsToStartProject)
    local posEntriesFiltered = filterConsecutiveEntries(posEntries)
    for _, entry in ipairs(posEntriesFiltered) do
        local take = prepareForProfilerMarkers(entry, createdTracks)
        local roundedPosX = entry.posOrValue.Position.X
        local roundedPosY = entry.posOrValue.Position.Y
        local roundedPosZ = entry.posOrValue.Position.Z

        local roundedOrFrontX = 1
        local roundedOrFrontY = 0
        local roundedOrFrontZ = 0

        local roundedOrTopX = 0
        local roundedOrTopY = 1
        local roundedOrTopZ = 0

        if entry.posOrValue.OrientationFront.X then
            roundedOrFrontX = tonumber(entry.posOrValue.OrientationFront.X)
            roundedOrFrontY = tonumber(entry.posOrValue.OrientationFront.Y)
            roundedOrFrontZ = tonumber(entry.posOrValue.OrientationFront.Z)
        end
        if entry.posOrValue.OrientationTop.X then
            roundedOrTopX = tonumber(entry.posOrValue.OrientationTop.X)
            roundedOrTopY = tonumber(entry.posOrValue.OrientationTop.Y)
            roundedOrTopZ = tonumber(entry.posOrValue.OrientationTop.Z)
        end

        local takeMarkerName = "SetPos;" .. roundedPosX .. ";" .. roundedPosY .. ";" .. roundedPosZ .. ";" .. roundedOrFrontX .. ";" .. roundedOrFrontY .. ";" .. roundedOrFrontZ .. ";" .. roundedOrTopX .. ";" .. roundedOrTopY .. ";" .. roundedOrTopZ .. ";"
        local color = getColorValue(colors, "Yellow")
        reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
    end
end

local function handleProfilerRTPC(entries, offsetInSecondsToStartProject, createdTracks)
    local rtpcEntries = filterEntriesByType(entries, "SetRTPCValue", offsetInSecondsToStartProject)
    for _, entry in ipairs(rtpcEntries) do
        if entry.description then
            local take = prepareForProfilerMarkers(entry, createdTracks)
            if take then
                local takeMarkerName = "RTPCLeg;" .. entry.objectName .. ";" ..  entry.posOrValue
                local color = getColorValue(colors, "Orange")
                reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
            end
        end
    end
end

local function handleProfilerRTPCInterp(entries, offsetInSecondsToStartProject, createdTracks)
    local rtpcInterpEntries = filterEntriesByType(entries, "SetRTPCValueInterp", offsetInSecondsToStartProject)
    if rtpcInterpEntries then
        --print(tableToString(rtpcInterpEntries))
        for _, entry in ipairs(rtpcInterpEntries) do
            if entry then
                local take = prepareForProfilerMarkers(entry, createdTracks)
                if take then
                    local initRTPCValue
                    local closestMarkerName, closestMarkerPattern = findClosestRTPCMarkerBeforeTimestamp(take, entry.timestamp, entry.objectName)
                    if not closestMarkerName and entry.initialValue then
                        closestMarkerName = "None"
                        initRTPCValue = entry.initialValue
                    elseif closestMarkerPattern == "RTPCLeg" then
                        local temp = closestMarkerName:match("([%d%.]+)$")
                        initRTPCValue = tonumber(temp)
                    elseif closestMarkerPattern == "RTPCInterp" then
                        local pattern = "[^;]*;[^;]*;[^;]*;([%d%.]+)"
                        local temp = closestMarkerName:match(pattern)
                        initRTPCValue = tonumber(temp)
                    elseif not initRTPCValue then
                        initRTPCValue = 0
                    end

                    local takeMarkerName = "RTPCInterp;" .. entry.objectName .. ";" ..  initRTPCValue .. ";" ..  entry.posOrValue .. ";" .. entry.interpTime
                    local color = getColorValue(colors, "Purple")
                    reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
                end
            end
        end
    end
end

local function handleProfilerInit(entries, offsetInSecondsToStartProject, createdTracks)
    local gameObjEntries = filterEntriesByType(entries, "InitObj", offsetInSecondsToStartProject)
    for _, entry in ipairs(gameObjEntries) do
        local take = prepareForProfilerMarkers(entry, createdTracks)
        local takeMarkerName = "InitObj;"
        local color = getColorValue(colors, "Red")
        reaper.SetTakeMarker(take, -1, takeMarkerName, entry.timestamp, color)
    end
end

local function enrichEntriesWithRtpcData(entries, rtpcData)
    for _, entry in ipairs(entries) do
        for _, rtpc in ipairs(rtpcData) do
            if entry.objectName == rtpc.name then
                entry.initialValue = rtpc.initialValue
                entry.maxValue = rtpc.maxValue
                entry.minValue = rtpc.minValue
                break
            end
        end
    end
    return entries
end

local function filterAndDeleteTakeMarkers(take, markerNamePatternToKeep)
    local markersToDelete = {}
    local numMarkers = reaper.GetNumTakeMarkers(take)
    for i = 0, numMarkers - 1 do
        local _, name = reaper.GetTakeMarker(take, i)
        if not string.match(name, markerNamePatternToKeep) then
            table.insert(markersToDelete, i)
        else
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", markerNamePatternToKeep, true)
        end
    end
    for i = #markersToDelete, 1, -1 do
        reaper.DeleteTakeMarker(take, markersToDelete[i])
    end
end

local function deleteOverlappingMarkersWithSameFirstComponent(take)
    local timestampMargin = 0.01
    local markers = {}
    local markersToDelete = {}

    local numMarkers = reaper.GetNumTakeMarkers(take)
    for i = 0, numMarkers - 1 do
        local retval, name = reaper.GetTakeMarker(take, i)
        if retval then
            local components = {}
            for component in string.gmatch(name, "([^;]+)") do
                table.insert(components, component)
            end
            local firstComponent = components[1] or ""
            table.insert(markers, {index = i, timestamp = retval, name = name, components = components, firstComponent = firstComponent})
        end
    end
    
    table.sort(markers, function(a, b) return a.timestamp < b.timestamp end)

    -- Adjusted logic to prefer keeping the last occurrence
    for i = 1, #markers - 1 do
        if not markersToDelete[markers[i].index] then -- Only compare markers that are not already marked for deletion
            for j = i + 1, #markers do
                if markers[i].firstComponent == markers[j].firstComponent and markers[i].firstComponent ~= "Event" then -- Components match and not Event
                    if math.abs(markers[i].timestamp - markers[j].timestamp) <= timestampMargin then -- Are Overlapping
                        -- Additional check if the second component of markers[i] is "0"
                        if markers[i].components[2] == "0" then
                            -- Mark the earlier marker (i) for deletion when the second component is "0"
                            markersToDelete[markers[i].index] = true
                            break -- Since i is marked for deletion, no need to compare it with further markers
                        else
                            -- Optionally, you can decide to delete marker j instead, or handle differently,
                            markersToDelete[markers[j].index] = true
                        end
                    else
                        -- Break early if markers are no longer overlapping, thanks to sorting
                        break
                    end
                end
            end
        end
    end


    -- Delete marked markers, iterating in reverse to maintain indices
    for i = numMarkers - 1, 0, -1 do
        if markersToDelete[i] then
            reaper.DeleteTakeMarker(take, i)
        end
    end
end

local function manageTrackFolderMarkers(outputTracks, uniqueMarkerNames, takeMarkers)
    for trackIndex, track in ipairs(outputTracks) do
        local take = getActiveTakeOfFirstItemOnTrack(track)
        if take then
            local markerNamePatternToKeep = uniqueMarkerNames[(trackIndex - 1) % #uniqueMarkerNames + 1]
            filterAndDeleteTakeMarkers(take, markerNamePatternToKeep)
        end
    end
end


local function duplicateTracks(parentTrack, parentTrackName, numTracks)
    local outputTracks = {}

    if numTracks and numTracks > 0 then

        table.insert(outputTracks, parentTrack)

        for i = 1, numTracks do
            reaper.SetOnlyTrackSelected(parentTrack)
            reaper.Main_OnCommand(40062, 0) -- Track: Duplicate tracks
            local childTrack = reaper.GetSelectedTrack(0, 0)
            table.insert(outputTracks, childTrack)
        end
        reaper.SetOnlyTrackSelected(parentTrack)

        parentTrackIdx = reaper.GetMediaTrackInfo_Value(parentTrack, "IP_TRACKNUMBER") - 1
        local lastChildTrack = reaper.GetTrack(0, parentTrackIdx + numTracks)
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(lastChildTrack, "I_FOLDERDEPTH", -1)
    end
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    return outputTracks
end

local function getUniqueMarkersData(takeMarkers)
    local uniqueMarkerNames = {}
    local markerNameSet = {}

    for _, marker in ipairs(takeMarkers) do
        if not markerNameSet[marker.name] then
            markerNameSet[marker.name] = true
            table.insert(uniqueMarkerNames, marker.name)
        end
    end

    local countUniqueNames = #uniqueMarkerNames

    return uniqueMarkerNames, countUniqueNames
end

local function isParentOfTrackNamed(parentTrack, childTrackName)
    local numTracks = reaper.CountTracks(0)
    
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        
        local _, currentTrackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if currentTrackName == childTrackName then
            local parent = reaper.GetParentTrack(track)
            
            if parent == parentTrack then
                return true, childTrack
            end
        end
    end
    return false
end

local function getTakeMarkers(item)
    local takeMarkers = {}
    local take = reaper.GetMediaItemTake(item, 0)

    if take then
        local numMarkers = reaper.GetNumTakeMarkers(take)
        for i = 0, numMarkers - 1 do
            local retval, name, _ = reaper.GetTakeMarker(take, i)
            if retval then
                local markerName = name:match("([^;]+)")
                if name:sub(1, 4) == "RTPC" then
                    markerName = "RTPC"
                end
                table.insert(takeMarkers, {name = markerName, id = i, take = take})
            end
        end
    end
    return takeMarkers
end

local function findItemForTrack(trackToFind, createdItems)
    for _, itemInfo in ipairs(createdItems) do
        if itemInfo.track == trackToFind then
            return itemInfo.item
        end
    end
    return nil
end

local function organizeTakeMarkers(createdTracks, createdItems, totalDurationInSeconds)
    for _, trackInfo in ipairs(createdTracks) do
        local track = trackInfo.track
        local name = trackInfo.name
        local item = findItemForTrack(trackInfo.track, createdItems)
        if item then
            local takeMarkers = getTakeMarkers(item)
            local uniqueMarkerNames, countUniqueNames = getUniqueMarkersData(takeMarkers)
            local take = reaper.GetMediaItemTake(item, 0)
            deleteOverlappingMarkersWithSameFirstComponent(take)
            local outputTracks = duplicateTracks(trackInfo.track, trackInfo.name, countUniqueNames - 1)
            manageTrackFolderMarkers(outputTracks, uniqueMarkerNames, takeMarkers)

            uniqueMarkerNames = {}
            countUniqueNames = 0
        else
            print("No matching item found for track named", name)
        end
    end
end

local function generateSessionFromProfilerTxt()
    local retval, filePath = reaper.GetUserFileNameForRead("", "Select Log File", "txt")
    if retval then
        local entries = processLogFile(filePath)
        if entries then
            local createdTracks = createTracksForGameObjects(entries)
            local totalDurationInSeconds, offsetInSecondsToStartProject = getTotalDurationInSeconds(entries)
            local createdItems = createMIDIItems(createdTracks, entries, totalDurationInSeconds)
            handleProfilerInit(entries, offsetInSecondsToStartProject, createdTracks)
            handleProfilerEvents(entries, offsetInSecondsToStartProject, createdTracks)
            handleProfilerSwitch(entries, offsetInSecondsToStartProject, createdTracks)
            handleProfilerState(entries, offsetInSecondsToStartProject, createdTracks)
            handleProfilerPosition(entries, offsetInSecondsToStartProject, createdTracks)
            rtpcData = gatherAllRTPCInfo()
            if rtpcData then 
                entries = enrichEntriesWithRtpcData(entries, rtpcData)
                handleProfilerRTPC(entries, offsetInSecondsToStartProject, createdTracks)
                handleProfilerRTPCInterp(entries, offsetInSecondsToStartProject, createdTracks)
            end
            organizeTakeMarkers(createdTracks, createdItems, totalDurationInSeconds)

            reaper.UpdateArrange()
        else
            reaper.ShowMessageBox("No entries found or failed to parse the file.", "Info", 0)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------



local function fetchAllWwiseObjectsNames(objectType)
    local args = reaper.AK_AkJson_Map()
    local ofTypeArray = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(ofTypeArray, reaper.AK_AkVariant_String(objectType))
    
    local fromMap = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(fromMap, "ofType", ofTypeArray)
    reaper.AK_AkJson_Map_Set(args, "from", fromMap)

    local options = reaper.AK_AkJson_Map()
    local returnFields = reaper.AK_AkJson_Array()
    reaper.AK_AkJson_Array_Add(returnFields, reaper.AK_AkVariant_String("name"))
    
    reaper.AK_AkJson_Array_Add(returnFields, reaper.AK_AkVariant_String("parent"))
    reaper.AK_AkJson_Array_Add(returnFields, reaper.AK_AkVariant_String("type"))
    
    reaper.AK_AkJson_Map_Set(options, "return", returnFields)

    local result = reaper.AK_Waapi_Call("ak.wwise.core.object.get", args, options)

    local wwiseObjectNames = {}

    if result then
        local status = reaper.AK_AkJson_GetStatus(result)
        if status then
            local objects = reaper.AK_AkJson_Map_Get(result, "return")
            if objects then
                local numObjects = reaper.AK_AkJson_Array_Size(objects)
                for i = 0, numObjects - 1 do
                    local item = reaper.AK_AkJson_Array_Get(objects, i)
                    local name = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(item, "name"))
                    local itemType = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(item, "type"))
                    local parent = reaper.AK_AkJson_Map_Get(item, "parent")

                    if itemType == "Switch" or itemType == "State" then
                        local groupName = ""
                        groupName = reaper.AK_AkVariant_GetString(reaper.AK_AkJson_Map_Get(parent, "name"))
                        name = groupName .. ": " .. name
                    end  
                    table.insert(wwiseObjectNames, name)
                end
            else
                reaper.ShowConsoleMsg("No objects found.\n")
            end
        else
            reaper.ShowMessageBox("Failed to fetch objects. Please check WAAPI connection and query.", "Whoops !", 0)
        end
    end

    return wwiseObjectNames
end

local function extractGroupNameFromName(fullName)
    local groupName = fullName:match("^(.-):")
    return groupName
end


local function filterNamesBasedOnInput(inputText, suggestionsTable, label, selectedGroupName)
    local filtered = {}
    for _, name in ipairs(suggestionsTable) do
        local shouldInclude = true
        local nameToMatch = ""
        if label == "Switch name" or label == "State name" then
            nameToMatch = name:match(":%s*(.*)") or name
            local groupName = extractGroupNameFromName(name)
            shouldInclude = groupName == selectedGroupName
        end
        if shouldInclude and (inputText == "" or name:lower():find(inputText:lower())) then
            table.insert(filtered, name)
        end
    end
    return filtered
end

local textBoxState = { shouldClearText = false }

local function showAutocompleteBox(ctx, inputText, suggestionsTable, label, selectedGroupName, textBoxState)
    local filteredNames = filterNamesBasedOnInput(inputText, suggestionsTable, label, selectedGroupName)
    local changed
    reaper.ImGui_SetNextItemWidth(ctx, generalItemWidth)
    if textBoxState.shouldClearText == true then
        inputText = ""
        textBoxState.shouldClearText = false
    end
    changed, inputText = reaper.ImGui_InputText(ctx, label, inputText, 256)
    

    if label ~= "State name" and label ~= "Switch name" then
        reaper.ImGui_SameLine(ctx, 0)
        if reaper.ImGui_Button(ctx, 'Sync with Wwise') then
            if not reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
                reaper.ShowMessageBox("Failed to connect to Wwise.", "Whoops !", 0)
                return
            end
            eventNamesTable = fetchAllWwiseObjectsNames("Event")
            rtpcNamesTable = fetchAllWwiseObjectsNames("GameParameter")
            switchGroupNamesTable = fetchAllWwiseObjectsNames("SwitchGroup")
            switchNamesTable = fetchAllWwiseObjectsNames("Switch")
            stateGroupNamesTable = fetchAllWwiseObjectsNames("StateGroup")
            stateNamesTable = fetchAllWwiseObjectsNames("State")

            rtpcData = gatherAllRTPCInfo()
            showRTPCMinMax = true
        end
    end

    if #filteredNames > 0 then
        if reaper.ImGui_BeginListBox(ctx, "##listbox" .. label, generalItemWidth, 50) then
            for i, name in ipairs(filteredNames) do
                if reaper.ImGui_Selectable(ctx, name .. "##" .. i, false) then
                    inputText = name
                    break
                end
            end
            reaper.ImGui_EndListBox(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
        end
    end

    return inputText
end


local selectedStateGroupName = ""
local selectedSwitchGroupName = ""

local function handleRTPCMinMaxValue(label, selectedName, data, varName)
    local value = nil
    if selectedName ~= "" then
        for _, entry in ipairs(data) do
            if entry.name == selectedName then
                value = entry[label == "Min Value" and "minValue" or "maxValue"]
                break
            end
        end
    end
    return value or _G[varName]
end

local function handleInputsAndMarkerName(ctx, currentOption, textBoxState)
    local config = eventTypeConfig[currentOption + 1]

    local fields = config.fields
    local eventType = config.eventType

    local markerParts = {eventType}
    if fields then
        for _, field in ipairs(fields) do
            local label, varName = table.unpack(field)

            if label == "Event name" then
                _G[varName] = showAutocompleteBox(ctx, _G[varName], eventNamesTable, "Event name", _, textBoxState)
            elseif label == "RTPC name" then
                _G[varName] = showAutocompleteBox(ctx, _G[varName], rtpcNamesTable, "RTPC name", _, textBoxState)
                selectedRTPC = _G[varName]
            elseif label == "State group name" then
                _G[varName] = showAutocompleteBox(ctx, _G[varName], stateGroupNamesTable, "State group name", _, textBoxState)
                selectedStateGroupName = _G[varName] 
            elseif label == "Switch group name" then
                _G[varName] = showAutocompleteBox(ctx, _G[varName], switchGroupNamesTable, "Switch group name", _, textBoxState)
                selectedSwitchGroupName = _G[varName]
            elseif label == "State name" or label == "Switch name" then
                local tempValue = showAutocompleteBox(ctx, _G[varName], (label == "State name") and stateNamesTable or switchNamesTable, label, (label == "State name") and selectedStateGroupName or selectedSwitchGroupName, textBoxState)
                local extractedValue = tempValue:match(":%s*(.*)") or tempValue
                _G[varName] = extractedValue
            elseif label == "Min Value" and showRTPCMinMax then
                local minValue = nil
                if selectedRTPC ~= "" then
                    for _, rtpc in ipairs(rtpcData) do
                        if rtpc.name == selectedRTPC then
                            minValue = rtpc.minValue
                            break
                        end
                    end
                end
                _G[varName] = inputText(ctx, label, minValue or _G[varName])
            elseif label == "Max Value" and showRTPCMinMax then
                local maxValue = nil
                if selectedRTPC ~= "" then
                    for _, rtpc in ipairs(rtpcData) do
                        if rtpc.name == selectedRTPC then
                            maxValue = rtpc.maxValue
                            break
                        end
                    end
                end
                _G[varName] = inputText(ctx, label, maxValue or _G[varName])
            else
                _G[varName] = inputText(ctx, label, _G[varName])
            end


            table.insert(markerParts, _G[varName])
        end
    end

    return concatenateWithSemicolon(table.unpack(markerParts))
end


-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------

local function createRTPCLane()
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
        local item = reaper.GetTrackMediaItem(track, 0)
        if item then
            local pluginName = "JS: kusa_Wwhisper Params"
            local found = isJSFXInstalled(pluginName)
            if found then
                local fxIndex = reaper.TrackFX_GetByName(track, pluginName, true)

                for envIndex = 3, 7 do
                    local rtpcEnvelope = reaper.GetFXEnvelope(track, fxIndex, envIndex, false)
                    
                    if not rtpcEnvelope then
                        rtpcEnvelope = reaper.GetFXEnvelope(track, fxIndex, envIndex, true)
                        return rtpcEnvelope, track
                    end
                end
                reaper.ShowMessageBox("All RTPC lanes are already created", "Whoops !", 0)
            else
                local userChoice = reaper.ShowMessageBox(pluginName .. " is not installed. It is required for spatialisation. Would you like to visit the documentation ?", "Whoops !", 4)
                if userChoice == 6 then
                    reaper.CF_ShellExecute("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/WWHISPER%20-%20DOCUMENTATION.md")
                end
            end
        else 
            reaper.ShowMessageBox("No item on the selected track", "Whoops !", 0)
            return false, false end
    else
        reaper.ShowMessageBox("No track selected", "Whoops !", 0)
    end
end


-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-- DELETE ALL TAKE MARKERS ON SELECTED ITEMS

local keyword = ""

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

function deleteTakeMarkersByKeyword(keyword)
    local selectedItems = storeSelectedMediaItems()
    if #selectedItems > 0 then
        for _, item in ipairs(selectedItems) do
            local take = reaper.GetActiveTake(item)
            local numTakeMarkers = reaper.GetNumTakeMarkers(take)
            for i = numTakeMarkers - 1, -1, -1 do
                if keyword == "" then
                    reaper.DeleteTakeMarker(take, i)
                else
                    local _, name = reaper.GetTakeMarker(take, i)
                    if name:find(keyword) then
                        reaper.DeleteTakeMarker(take, i)
                    end
                end
            end
        end
    end
end


-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------
local showUtilities = false
local utilitiesCheckboxState

local function loop()
    reaper.ImGui_SetNextWindowSize(ctx, 0, 0)
    local currentWindowWidth, currentWindowHeight = reaper.ImGui_GetWindowSize(ctx)
    local visible, open = reaper.ImGui_Begin(ctx, 'Wwhisper Assistant', true)
    if visible then
------------------------------------------------------------------------------------------------------
    -- CREATION
        if reaper.ImGui_BeginChild(ctx, 'LeftSection', leftSectionWidth, 410, true) then
            -- Title
            reaper.ImGui_Indent(ctx, 200)
            reaper.ImGui_Text(ctx, 'Creation')
            reaper.ImGui_Unindent(ctx, 200)
            -- Checkbox
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_Indent(ctx, 405)
            showUtilities, utilitiesCheckboxState = reaper.ImGui_Checkbox(ctx, "##unique_id", utilitiesCheckboxState)
            reaper.ImGui_Unindent(ctx, 405)
            -- Checkbox Label
            reaper.ImGui_Indent(ctx, 363)
            reaper.ImGui_Text(ctx, "Show Utilities")
            reaper.ImGui_Unindent(ctx, 363)

            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            -- Textbox
            _G[inputs.inputTextGameObjectName] = inputText(ctx, "Track / Game Object name", _G[inputs.inputTextGameObjectName])
            reaper.ImGui_Spacing(ctx)
            --reaper.ImGui_Spacing(ctx)

            reaper.ImGui_Indent(ctx, 137)

            if reaper.ImGui_Button(ctx, 'Create new track and item') then
                reaper.Undo_BeginBlock()

                local appVersionStr = reaper.GetAppVersion()
                local majorVersion = tonumber(string.match(appVersionStr, "(%d+)%."))

                if majorVersion and majorVersion < 7 then
                    reaper.ShowMessageBox("This feature requires REAPER version 7.0 or newer.", "Version Error", 0)
                else
                    createGameObjectTrack(_G[inputs.inputTextGameObjectName])
                    reaper.Undo_EndBlock("Create new MIDI Item", 0)
                end
            end

            reaper.ImGui_Unindent(ctx, 137)

            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            

            if currentOption ~= 1 then
                reaper.ImGui_SetNextItemWidth(ctx, generalItemWidth)
                local colorChanged, selectedColorIndex = reaper.ImGui_Combo(ctx, 'Take marker color', currentColorIndex, "Red\0Green\0Blue\0Yellow\0Orange\0Purple\0")
                if colorChanged then
                    currentColorIndex = selectedColorIndex
                end
            end
            
            reaper.ImGui_SetNextItemWidth(ctx, generalItemWidth)
            local changed, selectedOption = reaper.ImGui_Combo(ctx, 'Type', currentOption, "Event\0RTPC\0State\0Switch\0Register Game Object\0Unregister Game Object\0Unregister all Game Objects\0")
            if changed then
                currentOption = selectedOption
                textBoxState = { shouldClearText = true }
            end
            local markerName = handleInputsAndMarkerName(ctx, currentOption, textBoxState)

            if currentOption == 1 then -- IS RTPC
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Indent(ctx, 133)
                if showRTPCMinMax then

                end

                if reaper.ImGui_Button(ctx, 'Create RTPC automation lane') then
                    reaper.Undo_BeginBlock()                    
                    local rtpcEnvelope, track = createRTPCLane()
                    if rtpcEnvelope and track then
                        local item = reaper.GetTrackMediaItem(track, 0)
                        if item then
                            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                            local itemEnd = itemStart + itemLength
                            local rtpcPoolID = -1
                            local automItemID = reaper.InsertAutomationItem(rtpcEnvelope, rtpcPoolID, itemStart, itemEnd - itemStart)
                            reaper.GetSetAutomationItemInfo_String(rtpcEnvelope, 0, "P_POOL_NAME", markerName, true)
                        end
                    end
                    reaper.Undo_EndBlock("Create RTPC automation item", 0)
                    reaper.ImGui_Unindent(ctx, 133)
                end
            else -- IS NOT RTPC
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Indent(ctx, 165)
                if reaper.ImGui_Button(ctx, 'Create take marker') then
                    reaper.Undo_BeginBlock()
                    local selectedItemCount = reaper.CountSelectedMediaItems(0)
                    if selectedItemCount > 0 then
                        local cursorPos = reaper.GetCursorPosition()
                        local item = reaper.GetSelectedMediaItem(0, 0)
                        if item then
                            local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                            local markerPos = cursorPos - itemPos
                            local take = reaper.GetMediaItemTake(item, 0)
                            if take then
                                local colorToApply = handleMarkerColor(currentColorIndex)
                                reaper.SetTakeMarker(take, -1, markerName, markerPos, colorToApply)
                            end
                        end
                    else
                        reaper.ShowMessageBox("No item selected.", "Whoops !", 0)
                    end
                    reaper.Undo_EndBlock("Create take marker", 0)
                    reaper.ImGui_Unindent(ctx, 165)
                end
            end
            reaper.ImGui_EndChild(ctx)
        end
        reaper.ImGui_SameLine(ctx)
------------------------------------------------------------------------------------------------------
        -- UTILITIES TAB
        if utilitiesCheckboxState then
            if reaper.ImGui_BeginChild(ctx, 'RightSection', rightSectionWidth - 20, 410, true) then
                reaper.ImGui_Indent(ctx, 165)
                reaper.ImGui_Text(ctx, 'Utilities')
                reaper.ImGui_Unindent(ctx, 165)

                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)

                -- DUPLICATE NEAREST MARKER
                if reaper.ImGui_Button(ctx, 'Duplicate nearest take marker (selected items)') then
                    reaper.Undo_BeginBlock()
                    duplicateNearestMarker()
                    reaper.Undo_EndBlock("Duplicate nearest take marker", 0)
                end

                reaper.ImGui_Spacing(ctx)

                -- DELETE NEAREST MARKER
                if reaper.ImGui_Button(ctx, 'Delete nearest take marker (selected item)') then
                    reaper.Undo_BeginBlock()
                    deleteNearestMarker()
                    reaper.Undo_EndBlock("Delete nearest take marker", 0)
                end

                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)

                -- DELETE MARKER BY KEYWORD
                reaper.ImGui_SetNextItemWidth(ctx, generalItemWidth / 2)
                _, keyword = reaper.ImGui_InputText(ctx, 'Keyword', keyword)
                reaper.ImGui_SameLine(ctx, 0)
                if reaper.ImGui_Button(ctx, 'Delete markers on selected items') then
                    deleteTakeMarkersByKeyword(keyword)
                    keyword = ""
                end
                reaper.ImGui_Text(ctx, 'Leave empty to delete all markers')

                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                
                -- GENERATE FROM TXT BUTTON
                if reaper.ImGui_Button(ctx, 'Generate project from Profiler TXT') then
                    reaper.Undo_BeginBlock()
                    generateSessionFromProfilerTxt()
                    reaper.Undo_EndBlock("Generate project from Profiler TXT", 0)
                end

                reaper.ImGui_Spacing(ctx)

                -- SET SELECTED TRACK AS LISTENER
                if reaper.ImGui_Button(ctx, 'Set selected track as Listener') then
                    reaper.Undo_BeginBlock()
                    local trackCount = reaper.CountSelectedTracks(0)
                    if trackCount then
                        for i = 0, trackCount - 1 do
                            local track = reaper.GetSelectedTrack(0, i)
                            if track then
                                reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "Listener", true)
                            end
                        end
                    end
                    reaper.Undo_EndBlock("Set selected track as Listener", 0)
                end 

                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_Spacing(ctx)
                
                -- Toggle Envelopes
                if reaper.ImGui_Button(ctx, 'Toggle show/hide all envelopes') then
                    reaper.Main_OnCommand(41152, 0) -- Envelope: Toggle show all envelopes for all tracks
                end

                -- DELETE ALL TRACKS
                if reaper.ImGui_Button(ctx, 'Delete all tracks') then
                    reaper.Undo_BeginBlock()
                    local trackCount = reaper.CountTracks(0)
                    if trackCount then
                        for i = trackCount - 1, 0, -1 do
                            local track = reaper.GetTrack(0, i)
                            if track then
                                reaper.DeleteTrack(track)
                            end
                        end
                    end
                    reaper.UpdateArrange()
                    reaper.Undo_EndBlock("Delete all tracks", 0)
                end 
                -- END TAB
                reaper.ImGui_EndChild(ctx)
            end
        end
    reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    else
        reaper.AK_AkJson_ClearAll()
        reaper.AK_Waapi_Disconnect()
        reaper.ImGui_DestroyContext(ctx)
    end
end

loop()