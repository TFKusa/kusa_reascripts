-- @description kusa_Wwhisper
-- @version 2.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog :
--      # Changed Game Object system.
--      # Changed positioning system.
--      # Documentation is up to date for further details.

if not reaper.AK_Waapi_Connect then
    reaper.ShowMessageBox("Missing dependency, please install ReaWwise.", "Whoops !", 0)
    return
end

if not reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
    reaper.MB("Could not connect to Wwise.", "Whoops !", 0)
    return
end

local nextGameObjectID = 1
local gameObjectIDs = {}

local playingIDs = {}


------------------------------------------
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
    str = str .. "}"
    return str
end

local function registerObject(name)
    if gameObjectIDs[name] then
        return gameObjectIDs[name]
    end

    local registerArg = reaper.AK_AkJson_Map()
    local registerCommand = "ak.soundengine.registerGameObj"

    local gameObjectID = nextGameObjectID
    nextGameObjectID = nextGameObjectID + 1

    reaper.AK_AkJson_Map_Set(registerArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))
    reaper.AK_AkJson_Map_Set(registerArg, "name", reaper.AK_AkVariant_String(name))
    reaper.AK_Waapi_Call(registerCommand, registerArg, reaper.AK_AkJson_Map())

    gameObjectIDs[name] = gameObjectID
end

local function unregisterObject(name)
    local gameObjectID = gameObjectIDs[name]
    if gameObjectID then
        local unregisterArg = reaper.AK_AkJson_Map()
        local unregisterCommand = "ak.soundengine.unregisterGameObj"

        reaper.AK_AkJson_Map_Set(unregisterArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))
        reaper.AK_Waapi_Call(unregisterCommand, unregisterArg, reaper.AK_AkJson_Map())

        gameObjectIDs[name] = nil
    end
end

local function stopAll(name)
    local gameObjectID = gameObjectIDs[name]
    if gameObjectID then
        local stopArg = reaper.AK_AkJson_Map()
        reaper.AK_AkJson_Map_Set(stopArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))
        reaper.AK_Waapi_Call("ak.soundengine.stopAll", stopArg, reaper.AK_AkJson_Map())
    end
end

local function actionResetAllObj()
    for name, _ in pairs(gameObjectIDs) do
        stopAll(name)
        unregisterObject(name)
    end
end

local function waapiCleanUp()
    actionResetAllObj()
    reaper.AK_Waapi_Disconnect()
end


local function setDefaultListener()
    local listenerName = "Listener"
    registerObject(listenerName)

    local gameObjectID = gameObjectIDs[listenerName]
    if gameObjectID then
        local setDefaultListenersCommand = "ak.soundengine.setDefaultListeners"
        local defaultListenersArg = reaper.AK_AkJson_Map()
        local listenersArray = reaper.AK_AkJson_Array()

        reaper.AK_AkJson_Array_Add(listenersArray, reaper.AK_AkVariant_Int(gameObjectID))
        reaper.AK_AkJson_Map_Set(defaultListenersArg, "listeners", listenersArray)

        reaper.AK_Waapi_Call(setDefaultListenersCommand, defaultListenersArg, reaper.AK_AkJson_Map())
    else
        reaper.MB("Error setting default listener.", "Whoops !", 0)
    end
end

local function setGameObjectPosition(gameObjectID, gameObjectName, positionX, positionY, positionZ)
    if not gameObjectID then
        registerObject(gameObjectName)
    end
    local setGameObjectPositionCommand = "ak.soundengine.setPosition"
    local gameObjectPositionArg = reaper.AK_AkJson_Map()
    local positionMap = reaper.AK_AkJson_Map()

    local orientationFront = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(orientationFront, "x", reaper.AK_AkVariant_Int(1))
    reaper.AK_AkJson_Map_Set(orientationFront, "y", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(orientationFront, "z", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationFront", orientationFront)

    local orientationTop = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(orientationTop, "x", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(orientationTop, "y", reaper.AK_AkVariant_Int(1))
    reaper.AK_AkJson_Map_Set(orientationTop, "z", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationTop", orientationTop)

    local position = reaper.AK_AkJson_Map()
    reaper.AK_AkJson_Map_Set(position, "x", reaper.AK_AkVariant_Int(positionX))
    reaper.AK_AkJson_Map_Set(position, "y", reaper.AK_AkVariant_Int(positionY))
    reaper.AK_AkJson_Map_Set(position, "z", reaper.AK_AkVariant_Int(positionZ))
    reaper.AK_AkJson_Map_Set(positionMap, "position", position)

    reaper.AK_AkJson_Map_Set(gameObjectPositionArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))
    reaper.AK_AkJson_Map_Set(gameObjectPositionArg, "position", positionMap)

    reaper.AK_Waapi_Call(setGameObjectPositionCommand, gameObjectPositionArg, reaper.AK_AkJson_Map())
end



------------------------------------------


local function triggerWwiseEvent(eventName, gameObjectName)
    local gameObjectID = gameObjectIDs[gameObjectName]
    if not gameObjectID then
        waapiCleanUp()
        reaper.MB("No Game Object found.", "Whoops !", 0)
        return
    end

    local postEventCommand = "ak.soundengine.postEvent"
    local eventArg = reaper.AK_AkJson_Map()
    local eventNameVariant = reaper.AK_AkVariant_String(eventName)

    reaper.AK_AkJson_Map_Set(eventArg, "event", eventNameVariant)
    reaper.AK_AkJson_Map_Set(eventArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))

    reaper.AK_Waapi_Call(postEventCommand, eventArg, reaper.AK_AkJson_Map())
end

local function setRTPCValue(rtpcName, value, gameObjectID)
    local setRtpcCommand = "ak.soundengine.setRTPCValue"
    local rtpcArg = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(rtpcArg, "rtpc", reaper.AK_AkVariant_String(rtpcName))
    reaper.AK_AkJson_Map_Set(rtpcArg, "value", reaper.AK_AkVariant_Int(value))
    reaper.AK_AkJson_Map_Set(rtpcArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))

    reaper.AK_Waapi_Call(setRtpcCommand, rtpcArg, reaper.AK_AkJson_Map())
end

local function interpolateRTPCValue(rtpcName, currentRtpcValue, targetRtpcValue, gameObjectID, interpolationTimeMs)
    local startTime = reaper.time_precise()
    local endTime = startTime + interpolationTimeMs / 1000
    local duration = endTime - startTime

    local function updateRTPCValue()
        local currentTime = reaper.time_precise()
        local progress = (currentTime - startTime) / duration

        if progress < 1 then
            local newValue = currentRtpcValue + (targetRtpcValue - currentRtpcValue) * progress
            newValue = math.floor(newValue + 0.5)
            setRTPCValue(rtpcName, newValue, gameObjectID)
            reaper.defer(updateRTPCValue)
        else
            setRTPCValue(rtpcName, targetRtpcValue, gameObjectID)
        end
    end

    updateRTPCValue()
end

local function setSwitchValue(switchGroupName, switchGroupState, gameObjectID)
    local setSwitchCommand = "ak.soundengine.setSwitch"
    local switchArg = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(switchArg, "switchGroup", reaper.AK_AkVariant_String(switchGroupName))
    reaper.AK_AkJson_Map_Set(switchArg, "switchState", reaper.AK_AkVariant_String(switchGroupState))
    reaper.AK_AkJson_Map_Set(switchArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))

    reaper.AK_Waapi_Call(setSwitchCommand, switchArg, reaper.AK_AkJson_Map())
end

local function setStateValue(stateGroupName, stateName)
    local setStateCommand = "ak.soundengine.setState"
    local stateArg = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(stateArg, "stateGroup", reaper.AK_AkVariant_String(stateGroupName))
    reaper.AK_AkJson_Map_Set(stateArg, "state", reaper.AK_AkVariant_String(stateName))

    reaper.AK_Waapi_Call(setStateCommand, stateArg, reaper.AK_AkJson_Map())
end

local function interpolatePosValue(gameObjectID, gameObjectName, currentPosX, currentPosY, currentPosZ, targetPosX, targetPosY, targetPosZ, interpolationTimeMs)
    local startTime = reaper.time_precise()
    local endTime = startTime + interpolationTimeMs / 1000
    local duration = endTime - startTime

    local function updatePosValue()
        local currentTime = reaper.time_precise()
        local progress = (currentTime - startTime) / duration

        if progress < 1 then
            local newXValue = currentPosX + (targetPosX - currentPosX) * progress
            local newYValue = currentPosY + (targetPosY - currentPosY) * progress
            local newZValue = currentPosZ + (targetPosZ - currentPosZ) * progress
            newXValue = math.floor(newXValue + 0.5)
            newYValue = math.floor(newYValue + 0.5)
            newZValue = math.floor(newZValue + 0.5)
            setGameObjectPosition(gameObjectID, gameObjectName, newXValue, newYValue, newZValue)
            reaper.defer(updatePosValue)
        else
            setGameObjectPosition(gameObjectID, gameObjectName, targetPosX, targetPosY, targetPosZ)
        end
    end

    updatePosValue()
end


------------------------------------------


local function processMarker(name, trackName, expectedParts, actionFunc)
    local parts = {}
    for part in string.gmatch(name, "[^;]+") do
        table.insert(parts, part)
    end

    if #parts < expectedParts then
        reaper.Main_OnCommand(1016, 0) -- Stops the transport
        reaper.MB("Invalid marker format.", "Whoops !", 0)
        return false
    end

    return actionFunc(parts, trackName)
end

local function actionEvent(parts, trackName)
    local eventName = parts[2]
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end

    triggerWwiseEvent(eventName, gameObjectName)
    return true
end

local function actionRTPC(parts, trackName)
    local rtpcName = parts[2]
    local newRtpcValue = tonumber(parts[3])
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end
    if type(newRtpcValue) ~= "number" or newRtpcValue % 1 ~= 0 then
        reaper.Main_OnCommand(1016, 0) -- Stops the transport
        reaper.MB("RTPC value needs to be an integer.", "Whoops !", 0)
        return
    end

    setRTPCValue(rtpcName, newRtpcValue, gameObjectID)
    return true
end

local function actionRTPCInterp(parts, trackName)
    local rtpcName = parts[2]
    local currentRtpcValue = tonumber(parts[3])
    local targetRtpcValue = tonumber(parts[4])
    local interpolationTimeMs = tonumber(parts[5])
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end

    local numbers = {currentRtpcValue, targetRtpcValue, interpolationTimeMs}
    for _, number in ipairs(numbers) do
        if type(number) ~= "number" or number % 1 ~= 0 then
            reaper.Main_OnCommand(1016, 0) -- Stops the transport
            reaper.MB("RTPC values or interpolation time need to be integers.", "Whoops !", 0)
            return
        end
    end

    interpolateRTPCValue(rtpcName, currentRtpcValue, targetRtpcValue, gameObjectID, interpolationTimeMs)
    return true
end

local function actionSwitch(parts, trackName)
    local switchGroupName = parts[2]
    local switchGroupState = parts[3]
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end

    setSwitchValue(switchGroupName, switchGroupState, gameObjectID)
    return true
end

local function actionState(parts)
    local stateGroupName = parts[2]
    local stateName = parts[3]

    setStateValue(stateGroupName, stateName)
    return true
end

local function actionSetPos(parts, trackName)
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end

    local positionX = tonumber(parts[2])
    local positionY = tonumber(parts[3])
    local positionZ = tonumber(parts[4])

    local positions = {positionX, positionY, positionZ}
    for _, position in ipairs(positions) do
        if type(position) ~= "number" or position % 1 ~= 0 then
            reaper.Main_OnCommand(1016, 0) -- Stops the transport
            reaper.MB("Coordinates need to be integers.", "Whoops !", 0)
            return
        end
    end

    setGameObjectPosition(gameObjectID, gameObjectName, positionX, positionY, positionZ)
    return true
end

local function actionPosInterp(parts, trackName)
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID == nil then
        registerObject(gameObjectName)
        gameObjectID = gameObjectIDs[gameObjectName]
    end

    local currentPosX = tonumber(parts[2])
    local currentPosY = tonumber(parts[3])
    local currentPosZ = tonumber(parts[4])
    local targetPosX = tonumber(parts[5])
    local targetPosY = tonumber(parts[6])
    local targetPosZ = tonumber(parts[7])
    local interpolationTimeMs = tonumber(parts[8])
    local positions = {currentPosX, currentPosY, currentPosZ, targetPosX, targetPosY, targetPosZ, interpolationTimeMs}
    for _, position in ipairs(positions) do
        if type(position) ~= "number" or position % 1 ~= 0 then
            reaper.Main_OnCommand(1016, 0) -- Stops the transport
            reaper.MB("Coordinates or interpolation time need to be integers.", "Whoops !", 0)
            return
        end
    end

    interpolatePosValue(gameObjectID, gameObjectName, currentPosX, currentPosY, currentPosZ, targetPosX, targetPosY, targetPosZ, interpolationTimeMs)
    return true
end

local function actionInitObj(parts, trackName)
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if not gameObjectID then
        registerObject(gameObjectName)
    end
    return true
end

local function actionUnRegObj(parts, trackName)
    local gameObjectName = trackName
    local gameObjectID = gameObjectIDs[gameObjectName]

    if gameObjectID then
        unregisterObject(gameObjectName)
    end
    return true
end


local actionMapping = {
    Event = {func = actionEvent, parts = 2},
    RTPC = {func = actionRTPC, parts = 3},
    RTPCInterp = {func = actionRTPCInterp, parts = 5},
    Switch = {func = actionSwitch, parts = 3},
    State = {func = actionState, parts = 3},
    SetPos = {func = actionSetPos, parts = 4},
    SetPosInterp = {func = actionPosInterp, parts = 8},
    InitObj = {func = actionInitObj, parts = 1},
    UnRegObj = {func = actionUnRegObj, parts = 1},
    ResetAllObj = {func = actionResetAllObj, parts = 1}
}


------------------------------------------
local function collectAndSortTakeMarkers()
    local markerData = {}
    local itemCount = reaper.CountMediaItems(0)

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
        local track = reaper.GetMediaItem_Track(item)
        local _, trackName = reaper.GetTrackName(track)
        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        for takeIndex = 0, reaper.CountTakes(item) - 1 do
            local take = reaper.GetMediaItemTake(item, takeIndex)
            if take then
                local takeMarkerCount = reaper.GetNumTakeMarkers(take)
                for k = 0, takeMarkerCount - 1 do
                    local retval, name, pos = reaper.GetTakeMarker(take, k)
                    if retval ~= -1 then
                        local adjustedMarkerPos = itemPos + retval
                        table.insert(markerData, {name = name, adjustedPos = adjustedMarkerPos, trackName = trackName})
                    end
                end
            end
        end
    end

    table.sort(markerData, function(a, b) return a.adjustedPos < b.adjustedPos end)

    return markerData
end

------------------------------------------

local function preprocessMarkers(sortedMarkers)
    local playPos = reaper.GetCursorPosition()
    
    for i, marker in ipairs(sortedMarkers) do
        local pos = marker.adjustedPos
        local name = marker.name
        if pos < playPos and name:sub(1,1) == "!" then
            local actionName = name:match("^!(.-);")
            if actionName and actionMapping[actionName] then
                processMarker(name:sub(2), marker.trackName, actionMapping[actionName].parts, actionMapping[actionName].func)
            end
        end
    end
end

------------------------------------------

local function collectTracksForPositioning()
    local tracksForPos = {}
    local trackCount = reaper.CountTracks(0)

    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        if track then
            local envX = reaper.GetTrackEnvelopeByName(track, "Left/Right / kusa_Wwhisper Panner")
            local envY = reaper.GetTrackEnvelopeByName(track, "Up/Down / kusa_Wwhisper Panner")
            local envZ = reaper.GetTrackEnvelopeByName(track, "Front/Back / kusa_Wwhisper Panner")
            table.insert(tracksForPos, {track = track, envX = envX, envY = envY, envZ = envZ})
        end
    end

    return tracksForPos
end


local function evaluateEnvelope(env, time)
    if not env then return 0 end
    local retval, value = reaper.Envelope_Evaluate(env, time, 0, 1)
    return math.floor(value + 0.5)
end

local function adjustValueX(valueX, valueZ)
    local minMaxRange = math.abs(valueZ)
    return math.ceil((minMaxRange * valueX / 100))
end

------------------------------------------


local lastMarker = -1
local lastPlayPos = -1
local marginOfError = 0.040
local isFirstLoop = true
local markerCooldowns = {}
local cooldownPeriod = 1

local sortedMarkers = collectAndSortTakeMarkers()
local trackForPos = collectTracksForPositioning()

local function main()
    if reaper.GetPlayState() ~= 1 then
        waapiCleanUp()
        return
    end

    local playPos

    if isFirstLoop then
        playPos = reaper.GetCursorPosition()
        isFirstLoop = false
    else
        playPos = reaper.GetPlayPosition()
    end

    if playPos < lastPlayPos - marginOfError then
        if reaper.time_precise() - lastMarkerTime > cooldownPeriod then
            lastMarker = -1
        end
    end
    lastPlayPos = playPos

    for i, track in ipairs(trackForPos) do
        local time = reaper.GetPlayPosition()
        local valueX = evaluateEnvelope(track.envX, time)
        local valueY = evaluateEnvelope(track.envY, time)
        local valueZ = evaluateEnvelope(track.envZ, time)
        valueX = adjustValueX(valueX, valueZ)
        
        if not (valueX == 0 and valueY == 0 and valueZ == 0) then
            local _, trackName = reaper.GetTrackName(track.track)
            local posCommand = string.format("SetPos;%d;%d;%d", valueX, valueY, valueZ)
            processMarker(posCommand, trackName, 4, actionSetPos)
        end
    end


    for i, marker in ipairs(sortedMarkers) do
        if math.abs(playPos - marker.adjustedPos) <= marginOfError and lastMarker ~= i then
            if not markerCooldowns[i] or reaper.time_precise() - markerCooldowns[i] > cooldownPeriod then
                local namePrefix = marker.name:sub(1, 1) == "!" and marker.name:sub(2) or marker.name
                namePrefix = namePrefix:match("^(.-);")

                if namePrefix and actionMapping[namePrefix] then
                    if processMarker(marker.name, marker.trackName, actionMapping[namePrefix].parts, actionMapping[namePrefix].func) then
                        lastMarker = i
                        lastMarkerTime = reaper.time_precise()
                        markerCooldowns[i] = reaper.time_precise()
                    end
                end
            end
        end
    end

    reaper.defer(main)
end



setDefaultListener()
preprocessMarkers(sortedMarkers)
reaper.OnPlayButton()
main()
