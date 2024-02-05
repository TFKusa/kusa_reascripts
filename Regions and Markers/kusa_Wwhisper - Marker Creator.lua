-- @description kusa_Wwhisper - Marker Creator
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function concatenateWithUnderscore(...)
    -- Store all variable arguments in a table
    local args = {...}
    
    -- Concatenate the table elements with "_" as the separator
    local concatenatedString = table.concat(args, "_")
    
    return concatenatedString
end

local reaImguiAvailable = reaper.APIExists("ImGui_Begin")

if not reaImguiAvailable then
    reaper.MB("This script requires ReaImGui. Please install it via ReaPack.", "Error", 0)
    return
end

local ctx = reaper.ImGui_CreateContext('Wwhisper - Marker Creator')
--local size = reaper.GetAppVersion():match('OSX') and 13 or 20

local windowWidth = 543
local windowHeight = 296
reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, 0)


local currentItem = 0
local inputTextName, inputTextGameObjectName, inputTextValue, inputTextStartingValue, inputTextTargetValue, inputTextInterpTime, inputTextChildName, inputTextPosX, inputTextPosY, inputTextPosZ, inputTextTargetX, inputTextTargetY, inputTextTargetZ = "", "", "", "", "", "", "", "", "", "", "", "", ""
local shouldInterp = false
local markerName

function loop()
    local visible, open = reaper.ImGui_Begin(ctx, 'Wwhisper - Marker Creator', true)
    local width, height = reaper.ImGui_GetWindowSize(ctx)
    if visible then
        -- Combo box
        local changed, selectedItem = reaper.ImGui_Combo(ctx, 'Options', currentItem, "Event\0RTPC\0State\0Switch\0Position\0")
        if changed then
            currentItem = selectedItem
        end
        -- Conditional GUI elements based on the selection
        if currentItem == 0 then
            eventType = "Event"
            _, inputTextName = reaper.ImGui_InputText(ctx, 'Event name', inputTextName)
            _, inputTextGameObjectName = reaper.ImGui_InputText(ctx, 'Game Object name', inputTextGameObjectName)
            markerName = concatenateWithUnderscore(eventType, inputTextName, inputTextGameObjectName)
        elseif currentItem == 1 then
            if not shouldInterp then
                eventType = "RTPC"
                _, inputTextName = reaper.ImGui_InputText(ctx, 'RTPC name', inputTextName)
                _, inputTextValue = reaper.ImGui_InputText(ctx, 'Value', inputTextValue)
            else
                eventType = "RTPCInterp"
                _, inputTextName = reaper.ImGui_InputText(ctx, 'RTPC name', inputTextName)
                _, inputTextStartingValue = reaper.ImGui_InputText(ctx, 'Starting value', inputTextStartingValue)
                _, inputTextTargetValue = reaper.ImGui_InputText(ctx, 'Target value', inputTextTargetValue)
                _, inputTextInterpTime = reaper.ImGui_InputText(ctx, 'Interpolation Time (ms)', inputTextInterpTime)
            end
            _, inputTextGameObjectName = reaper.ImGui_InputText(ctx, 'Game Object name', inputTextGameObjectName)
            _, shouldInterp = reaper.ImGui_Checkbox(ctx, "Interpolation", shouldInterp)
            if shouldInterp then
                markerName = concatenateWithUnderscore(eventType, inputTextName, inputTextStartingValue, inputTextTargetValue, inputTextInterpTime, inputTextGameObjectName)
            else
                markerName = concatenateWithUnderscore(eventType, inputTextName, inputTextValue, inputTextGameObjectName)
            end            
        elseif currentItem == 2 then
            eventType = "State"
            _, inputTextName = reaper.ImGui_InputText(ctx, 'State group name', inputTextName)
            _, inputTextChildName = reaper.ImGui_InputText(ctx, 'State name', inputTextChildName)
            markerName = concatenateWithUnderscore(eventType, inputTextName, inputTextChildName)
        elseif currentItem == 3 then
            eventType = "Switch"
            _, inputTextName = reaper.ImGui_InputText(ctx, 'Switch group name', inputTextName)
            _, inputTextChildName = reaper.ImGui_InputText(ctx, 'Switch name', inputTextChildName)
            _, inputTextGameObjectName = reaper.ImGui_InputText(ctx, 'Game Object name', inputTextGameObjectName)
            markerName = concatenateWithUnderscore(eventType, inputTextName, inputTextChildName, inputTextGameObjectName)
        elseif currentItem == 4 then
            if shouldInterp then
                eventType = "SetPosInterp"
                _, inputTextPosX = reaper.ImGui_InputText(ctx, 'Start X', inputTextPosX)
                _, inputTextPosY = reaper.ImGui_InputText(ctx, 'Start Y', inputTextPosY)
                _, inputTextPosZ = reaper.ImGui_InputText(ctx, 'Start Z', inputTextPosZ)
                _, inputTextTargetX = reaper.ImGui_InputText(ctx, 'Target X', inputTextTargetX)
                _, inputTextTargetY = reaper.ImGui_InputText(ctx, 'Target Y', inputTextTargetY)
                _, inputTextTargetZ = reaper.ImGui_InputText(ctx, 'Target Z', inputTextTargetZ)
                _, inputTextInterpTime = reaper.ImGui_InputText(ctx, 'Interpolation Time (ms)', inputTextInterpTime)
                _, inputTextGameObjectName = reaper.ImGui_InputText(ctx, 'Game Object name', inputTextGameObjectName)
                markerName = concatenateWithUnderscore(eventType, inputTextPosX, inputTextPosY, inputTextPosZ, inputTextTargetX, inputTextTargetY, inputTextTargetZ, inputTextInterpTime, inputTextGameObjectName)  
            else
                eventType = "SetPos"
                _, inputTextPosX = reaper.ImGui_InputText(ctx, 'X', inputTextPosX)
                _, inputTextPosY = reaper.ImGui_InputText(ctx, 'Y', inputTextPosY)
                _, inputTextPosZ = reaper.ImGui_InputText(ctx, 'Z', inputTextPosZ)
                _, inputTextGameObjectName = reaper.ImGui_InputText(ctx, 'Game Object name', inputTextGameObjectName)
                markerName = concatenateWithUnderscore(eventType, inputTextPosX, inputTextPosY, inputTextPosZ, inputTextGameObjectName)  
            end
            _, shouldInterp = reaper.ImGui_Checkbox(ctx, "Interpolation", shouldInterp)
        end

        reaper.ImGui_Indent(ctx, 200)
        if reaper.ImGui_Button(ctx, 'Create Marker') then
            local cursorPos = reaper.GetCursorPosition()
            reaper.AddProjectMarker(0, false, cursorPos, 0, markerName, -1)
            markerName = ""
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
