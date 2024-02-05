-- @description kusa_Wwhisper - Marker Creator
-- @version 1.11
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function concatenateWithUnderscore(...)
    local args = {...}
    local concatenatedString = table.concat(args, "_")
    
    return concatenatedString
end

local reaImguiAvailable = reaper.APIExists("ImGui_Begin")

if not reaImguiAvailable then
    reaper.MB("This script requires ReaImGui. Please install it via ReaPack.", "Error", 0)
    return
end

local ctx = reaper.ImGui_CreateContext('Wwhisper - Marker Creator')

local windowWidth = 543
local windowHeight = 296
reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, 0)


local currentOption = 0
local inputTextName, inputTextGameObjectName, inputTextValue, inputTextStartingValue, inputTextTargetValue, inputTextInterpTime, inputTextChildName, inputTextPosX, inputTextPosY, inputTextPosZ, inputTextTargetX, inputTextTargetY, inputTextTargetZ = "", "", "", "", "", "", "", "", "", "", "", "", ""
local shouldInterp = false
local markerName


local function inputText(ctx, label, var)
    local _, newValue = reaper.ImGui_InputText(ctx, label, var)
    return newValue or var
end


local eventTypeConfig = {
    {eventType = "Event", fields = {{"Event name", "inputTextName"}, {"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "RTPC", fields = {{"RTPC name", "inputTextName"}, {"Value", "inputTextValue"}, {"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "State", fields = {{"State group name", "inputTextName"}, {"State name", "inputTextChildName"}}},
    {eventType = "Switch", fields = {{"Switch group name", "inputTextName"}, {"Switch name", "inputTextChildName"}, {"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "SetPos", fields = {{"X", "inputTextPosX"}, {"Y", "inputTextPosY"}, {"Z", "inputTextPosZ"}, {"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "InitObj", fields = {{"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "UnRegObj", fields = {{"Game Object name", "inputTextGameObjectName"}}},
    {eventType = "ResetAllObj", fields = {}}
}

local function handleInputsAndMarkerName(ctx, currentOption, shouldInterp)
    local config = eventTypeConfig[currentOption + 1]

    local fields = config.fields
    local eventType = config.eventType
    if currentOption == 1 and shouldInterp then
        eventType = "RTPCInterp"
        fields = {{"RTPC name", "inputTextName"}, {"Starting value", "inputTextStartingValue"}, {"Target value", "inputTextTargetValue"}, {"Interpolation Time (ms)", "inputTextInterpTime"}, {"Game Object name", "inputTextGameObjectName"}}
    elseif currentOption == 4 and shouldInterp then
        eventType = "SetPosInterp"
        fields = {{"Start X", "inputTextPosX"}, {"Start Y", "inputTextPosY"}, {"Start Z", "inputTextPosZ"}, {"Target X", "inputTextTargetX"}, {"Target Y", "inputTextTargetY"}, {"Target Z", "inputTextTargetZ"}, {"Interpolation Time (ms)", "inputTextInterpTime"}, {"Game Object name", "inputTextGameObjectName"}}
    end

    local markerParts = {eventType}
    for _, field in ipairs(fields) do
        local label, varName = table.unpack(field)
        _G[varName] = inputText(ctx, label, _G[varName])
        table.insert(markerParts, _G[varName])
    end

    return concatenateWithUnderscore(table.unpack(markerParts))
end

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
