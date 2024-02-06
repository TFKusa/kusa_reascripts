-- @description kusa_Wwhisper - Marker Creator
-- @version 1.12
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @changelog : - Code clean up.


local reaImguiAvailable = reaper.APIExists("ImGui_Begin")
if not reaImguiAvailable then
    reaper.MB("This script requires ReaImGui. Please install it via ReaPack.", "Error", 0)
    return
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


local ctx = reaper.ImGui_CreateContext('Wwhisper - Marker Creator')

local windowWidth = 543
local windowHeight = 296
reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, 0)


local currentOption = 0
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

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Wwhisper - Marker Creator', true)
    local width, height = reaper.ImGui_GetWindowSize(ctx)
    if visible then
        
        local changed, selectedOption = reaper.ImGui_Combo(ctx, 'Options', currentOption, "Event\0RTPC\0State\0Switch\0Position\0Register Game Object\0Unregister Game Object\0Unregister all Game Objects\0")
        if changed then
            currentOption = selectedOption
        end


        local markerName = handleInputsAndMarkerName(ctx, currentOption, shouldInterp)
        if currentOption == 1 or currentOption == 4 then
            _, shouldInterp = reaper.ImGui_Checkbox(ctx, "Interpolation", shouldInterp)
        end

        reaper.ImGui_Indent(ctx, 200)
        if reaper.ImGui_Button(ctx, 'Create Marker') then
            local cursorPos = reaper.GetCursorPosition()
            reaper.AddProjectMarker(0, false, cursorPos, 0, markerName, -1)
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
