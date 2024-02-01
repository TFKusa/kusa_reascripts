-- Event_eventName_gameObjectName
-- RTPC_rtpcName_value_gameObjectName
-- RTPCInterp_rtpcName_startingValue_targetValue_interpTimeInMs_gameObjectName
-- Switch_switchGroupName_switchGroupState_gameObjectName
-- State_stateGroupName_stateName

-- SetPos_gameObjectName_PosX_PosY_PosZ



-- Connect to Wwise
if not reaper.AK_Waapi_Connect("127.0.0.1", 8080) then
    reaper.ShowConsoleMsg("Failed to connect to Wwise\n")
    return
end

local nextGameObjectID = 1
local gameObjectIDs = {}

local playingIDs = {}

------------------------------------------

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

        gameObjectIDs[name] = nil -- Remove the ID from the table
    end
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
        reaper.ShowConsoleMsg("Error setting default listener: " .. listenerName .. "\n")
    end
end

local function setGameObjectPosition(gameObjectID, positionX, positionY, positionZ)
--[[     local setGameObjectPositionCommand = "ak.soundengine.setPosition"
    local gameObjectPositionArg = reaper.AK_AkJson_Map()
    local positionMap = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(positionMap, "orientationTop.x", reaper.AK_AkVariant_Object("orientationFront"))

    -- Set the position, orientationFront, and orientationTop within positionMap
    reaper.AK_AkJson_Map_Set(positionMap, "orientationFront.x", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationFront.y", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationFront.z", reaper.AK_AkVariant_Int(-1))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationTop.x", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationTop.y", reaper.AK_AkVariant_Int(1))
    reaper.AK_AkJson_Map_Set(positionMap, "orientationTop.z", reaper.AK_AkVariant_Int(0))
    reaper.AK_AkJson_Map_Set(positionMap, "x", reaper.AK_AkVariant_Int(positionX))
    reaper.AK_AkJson_Map_Set(positionMap, "y", reaper.AK_AkVariant_Int(positionY))
    reaper.AK_AkJson_Map_Set(positionMap, "z", reaper.AK_AkVariant_Int(positionZ))

    -- Set the gameObject and position in the main argument map
    reaper.AK_AkJson_Map_Set(gameObjectPositionArg, "gameObject", reaper.AK_AkVariant_Int(gameObjectID))
    reaper.AK_AkJson_Map_Set(gameObjectPositionArg, "position", positionMap)

    reaper.AK_Waapi_Call(setGameObjectPositionCommand, gameObjectPositionArg, reaper.AK_AkJson_Map()) ]]
end


------------------------------------------


local function triggerWwiseEvent(eventName, gameObjectName)
    local gameObjectID = gameObjectIDs[gameObjectName]
    if not gameObjectID then
        reaper.ShowConsoleMsg("No Game Object found")
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


------------------------------------------


local function processMarker(name, expectedParts, actionFunc)
    local parts = {}
    for part in string.gmatch(name, "[^_]+") do
        table.insert(parts, part)
    end

    if #parts < expectedParts then
        reaper.ShowConsoleMsg("Error: Invalid marker format.\n")
        return false
    end

    return actionFunc(parts)
end

local function actionEvent(parts)
    local eventName = parts[2]
    local gameObjectName = parts[3]
    local gameObjectID = gameObjectIDs[gameObjectName]

    if not gameObjectID then
        registerObject(gameObjectName)
    end

    registerObject(gameObjectName)
    triggerWwiseEvent(eventName, gameObjectName)
    return true
end

local function actionRTPC(parts)
    local rtpcName = parts[2]
    local newRtpcValue = tonumber(parts[3])
    local gameObjectName = parts[4]
    local gameObjectID = gameObjectIDs[gameObjectName]

    if not gameObjectID then
        reaper.ShowConsoleMsg("Error: Game object '" .. gameObjectName .. "' not found.\n")
        return false
    end

    setRTPCValue(rtpcName, newRtpcValue, gameObjectID)
    return true
end

local function actionRTPCInterp(parts)
    local rtpcName = parts[2]
    local currentRtpcValue = tonumber(parts[3])
    local targetRtpcValue = tonumber(parts[4])
    local interpolationTimeMs = tonumber(parts[5])
    local gameObjectName = parts[6]
    local gameObjectID = gameObjectIDs[gameObjectName]

    if not gameObjectID then
        reaper.ShowConsoleMsg("Error: Game object '" .. gameObjectName .. "' not found.\n")
        return false
    end

    interpolateRTPCValue(rtpcName, currentRtpcValue, targetRtpcValue, gameObjectID, interpolationTimeMs)
    return true
end

local function actionSwitch(parts)
    local switchGroupName = parts[2]
    local switchGroupState = parts[3]
    local gameObjectName = parts[4]
    local gameObjectID = gameObjectIDs[gameObjectName]

    if not gameObjectID then
        reaper.ShowConsoleMsg("Error: Game object '" .. gameObjectName .. "' not found.\n")
        return false
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

local function actionSetPos(parts)
    local gameObjectName = parts[2]
    local gameObjectID = gameObjectIDs[gameObjectName]
    local positionX = tonumber(parts[3])
    local positionY = tonumber(parts[4])
    local positionZ = tonumber(parts[5])

    setGameObjectPosition(gameObjectID, positionX, positionY, positionZ)
    return true
end


local function stopAll()
    local stopArg = reaper.AK_AkJson_Map()

    reaper.AK_AkJson_Map_Set(stopArg, "gameObject", reaper.AK_AkVariant_Int(0))
    reaper.AK_Waapi_Call("ak.soundengine.stopAll", stopArg, reaper.AK_AkJson_Map())
end


------------------------------------------


local lastMarker = -1

local function main()
    if reaper.GetPlayState() == 0 then
        reaper.ShowConsoleMsg("h")
        stopAll()
        reaper.AK_Waapi_Disconnect()
        return
    end

    local playPos = reaper.GetPlayPosition()
    local marginOfError = 0.05
    local retval, num_markers = reaper.CountProjectMarkers(0)

    local actionMapping = {
        Event = {func = actionEvent, parts = 3},
        RTPC = {func = actionRTPC, parts = 4},
        RTPCInterp = {func = actionRTPCInterp, parts = 6},
        Switch = {func = actionSwitch, parts = 4},
        State = {func = actionState, parts = 3},
        SetPos = {func = actionSetPos, parts = 5},
    }

    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if not isrgn and math.abs(playPos - pos) <= marginOfError and lastMarker ~= markrgnindexnumber then
            local namePrefix = name:match("^(.-)_")
            if namePrefix and actionMapping[namePrefix] then
                if processMarker(name, actionMapping[namePrefix].parts, actionMapping[namePrefix].func) then
                    lastMarker = markrgnindexnumber
                    break
                end
            end
        end
    end
    reaper.defer(main)
end


setDefaultListener()
reaper.OnPlayButton()
main()


