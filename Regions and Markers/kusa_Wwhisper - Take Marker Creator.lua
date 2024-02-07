-- @description kusa_Wwhisper - Take Marker Creator
-- @version 1.01
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog :
--      # Adjusted window height




local reaImguiAvailable = reaper.APIExists("ImGui_Begin")
if not reaImguiAvailable then
    reaper.MB("This script requires ReaImGui. Please install it via ReaPack.", "Error", 0)
    return
end

local colors = {
    {name = "Red", value = 33226752},
    {name = "Green", value = 16830208},
    {name = "Blue", value = 16806892},
    {name = "Yellow", value = 0},
    {name = "Orange", value = 32795136},
    {name = "Purple", value = 28901614},
}

local selectedColorValue = colors[1].value

function collectAndSortTakeMarkers()
    local markerData = {}
    local itemCount = reaper.CountMediaItems(0)

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
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

local function concatenateWithUnderscore(...)
    local args = {...}
    local concatenatedString = table.concat(args, "_")
    
    return concatenatedString
end

local function inputText(ctx, label, var)
    local _, newValue = reaper.ImGui_InputText(ctx, label, var)
    return newValue or var
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

local function duplicateTakeMarker(sortedTakeMarkers, closestIndex, closestPos, closestName, color)
    if closestIndex ~= -1 then
        local markerData = sortedTakeMarkers[closestIndex]
        local take = markerData.take
        local newPos = closestPos + 0.1
        
        if take then
            local newMarkerIndex = reaper.SetTakeMarker(take, -1, closestName, newPos, color)
        else
            reaper.ShowMessageBox("No take associated with the marker.", "Error", 0)
        end
    else
        reaper.ShowMessageBox("No marker found near the play cursor.", "Error", 0)
    end
end

local function duplicateNearestMarker()
    local playPosition = reaper.GetCursorPosition()
    local sortedTakeMarkers = collectAndSortTakeMarkers()
    local closestIndex, closestPos, closestName, color = getNearestTakeMarker(playPosition, sortedTakeMarkers)
    duplicateTakeMarker(sortedTakeMarkers, closestIndex, closestPos, closestName, color)
end

local ctx = reaper.ImGui_CreateContext('Wwhisper - Marker Creator')

local windowWidth = 543
local windowHeight = 330
reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, 0)


local currentOption = 0
local currentColorIndex = 0
local shouldInterp = false
local markerName

local inputs = {
    inputTextName = "",
    inputTextGameObjectName = "",
    inputTextValue = "",
    inputTextStartingValue = "",
    inputTextTargetValue = "",
    inputTextInterpTime = "",
    inputTextChildName = "",
    inputTextPosX = "",
    inputTextPosY = "",
    inputTextPosZ = "",
    inputTextTargetX = "",
    inputTextTargetY = "",
    inputTextTargetZ = "",
}

local eventTypeConfig = {
    {eventType = "Event", fields = {{"Event name", "inputs.inputTextName"}, {"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "RTPC", fields = {{"RTPC name", "inputs.inputTextName"}, {"Value", "inputs.inputTextValue"}, {"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "State", fields = {{"State group name", "inputs.inputTextName"}, {"State name", "inputs.inputTextChildName"}}},
    {eventType = "Switch", fields = {{"Switch group name", "inputs.inputTextName"}, {"Switch name", "inputs.inputTextChildName"}, {"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "SetPos", fields = {{"X", "inputs.inputTextPosX"}, {"Y", "inputs.inputTextPosY"}, {"Z", "inputs.inputTextPosZ"}, {"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "InitObj", fields = {{"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "UnRegObj", fields = {{"Game Object name", "inputs.inputTextGameObjectName"}}},
    {eventType = "ResetAllObj", fields = {}}
}

local function handleInputsAndMarkerName(ctx, currentOption, shouldInterp)
    local config = eventTypeConfig[currentOption + 1]

    local fields = config.fields
    local eventType = config.eventType
    if currentOption == 1 and shouldInterp then
        eventType = "RTPCInterp"
        fields = {{"RTPC name", "inputs.inputTextName"}, {"Starting value", "inputs.inputTextStartingValue"}, {"Target value", "inputs.inputTextTargetValue"}, {"Interpolation Time (ms)", "inputs.inputTextInterpTime"}, {"Game Object name", "inputs.inputTextGameObjectName"}}
    elseif currentOption == 4 and shouldInterp then
        eventType = "SetPosInterp"
        fields = {{"Start X", "inputs.inputTextPosX"}, {"Start Y", "inputs.inputTextPosY"}, {"Start Z", "inputs.inputTextPosZ"}, {"Target X", "inputs.inputTextTargetX"}, {"Target Y", "inputs.inputTextTargetY"}, {"Target Z", "inputs.inputTextTargetZ"}, {"Interpolation Time (ms)", "inputs.inputTextInterpTime"}, {"Game Object name", "inputs.inputTextGameObjectName"}}
    end

    local markerParts = {eventType}
    for _, field in ipairs(fields) do
        local label, varName = table.unpack(field)
        _G[varName] = inputText(ctx, label, _G[varName])
        table.insert(markerParts, _G[varName])
    end

    return concatenateWithUnderscore(table.unpack(markerParts))
end

local function handleMarkerColor(currentColorIndex)
    local colorConfig = colors[currentColorIndex + 1]
    local currentColorValue = colorConfig.value
    return currentColorValue
end

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Wwhisper - Take Marker Creator', true)
    if visible then

        local colorChanged, selectedColorIndex = reaper.ImGui_Combo(ctx, 'Take marker color', currentColorIndex, "Red\0Green\0Blue\0Yellow\0Orange\0Purple\0")
        if colorChanged then
            currentColorIndex = selectedColorIndex
        end
        
        local changed, selectedOption = reaper.ImGui_Combo(ctx, 'Type', currentOption, "Event\0RTPC\0State\0Switch\0Position\0Register Game Object\0Unregister Game Object\0Unregister all Game Objects\0")
        if changed then
            currentOption = selectedOption
        end

        local markerName = handleInputsAndMarkerName(ctx, currentOption, shouldInterp)
        if currentOption == 1 or currentOption == 4 then
            _, shouldInterp = reaper.ImGui_Checkbox(ctx, "Interpolation", shouldInterp)
        end

        reaper.ImGui_Indent(ctx, 200)
        if reaper.ImGui_Button(ctx, 'Create take marker') then
            local selectedItemCount = reaper.CountSelectedMediaItems(0)
            if selectedItemCount > 0 then
                local cursorPos = reaper.GetCursorPosition()
                local item = reaper.GetSelectedMediaItem(0, 0)
                if item then
                    local take = reaper.GetMediaItemTake(item, 0)
                    if take then
                        local colorToApply = handleMarkerColor(currentColorIndex)
                        reaper.SetTakeMarker(take, -1, markerName, cursorPos, colorToApply)
                    end
                end
            else
                reaper.ShowMessageBox("No item selected.", "Whoops.", 0)
            end
        end
        reaper.ImGui_Unindent(ctx, 40)
        if reaper.ImGui_Button(ctx, 'Duplicate nearest take marker') then
            duplicateNearestMarker()
        end
        reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(loop)
    else
        reaper.ImGui_DestroyContext(ctx)
    end
end

loop()
