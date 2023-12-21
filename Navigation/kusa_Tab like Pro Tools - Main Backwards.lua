-- @description kusa_Tab like Pro Tools - Main Backwards
-- @version 1.00
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR
-- @about : Documentation : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md
-- @changelog Hi ! Check out installation instructions : https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md


local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end

local function openURL(url)
    reaper.CF_ShellExecute(url)
end

local function stringToBool(str)
    if str == "true" then
        return true
    elseif str == "false" then
        return false
    else
        return nil
    end
end
------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function getCursorPos()
    local cursorPos = reaper.GetCursorPosition()
    return cursorPos
end

local function getItemPositionsOnSelectedTrack()
    local itemPositions = {}
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
        local itemCount = reaper.CountTrackMediaItems(track)
        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local endPos = startPos + itemLength

            table.insert(itemPositions, {start = startPos, ["end"] = endPos})
        end
    else
        showMessage("No track is selected", "Error", 0)
        return false
    end
    return itemPositions
end

local function getClosestSuperiorPosition(inputPosition)
    local itemPositions = getItemPositionsOnSelectedTrack()
    if not itemPositions then return end
    local closestPosition = nil
    local closestDiff = math.huge
    for _, pos in ipairs(itemPositions) do
        if pos.start < inputPosition then
            local diff = inputPosition - pos.start
            if diff < closestDiff then
                closestDiff = diff
                closestPosition = pos.start
            end
        end
        if pos["end"] < inputPosition then
            local diff = inputPosition - pos["end"]
            if diff < closestDiff then
                closestDiff = diff
                closestPosition = pos["end"]
            end
        end
    end
    return closestPosition or false
end

local function offToggle(cursorPos)
    closestEdge = getClosestSuperiorPosition(cursorPos)
    if not closestEdge then return end
    reaper.SetEditCurPos(closestEdge, true, false)
end

function isCursorOverItemOnSelectedTrack(cursorPos)
    local track = reaper.GetSelectedTrack(0, 0)

    if track then
        local itemCount = reaper.CountTrackMediaItems(track)

        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local itemEnd = itemStart + itemLength

            if cursorPos >= itemStart and cursorPos <= itemEnd then
                return true, item, itemStart
            end
        end
    end

    return false
end

local function main(toggleState)
    local toggleState = stringToBool(toggleState)
    local cursorPos = getCursorPos()
    local initialCursorPos = cursorPos
    local itemStart = nil
    if toggleState then
        isCursorOverItem, item, itemStart = isCursorOverItemOnSelectedTrack(cursorPos)
        if isCursorOverItem then
            reaper.Main_OnCommand(40376, 0) -- Move cursor to next previous in items
        else
            reaper.Main_OnCommand(40416, 0) -- Select and move to previous item (start)
            reaper.Main_OnCommand(40319, 0) -- Move cursor right to edge of item
        end
    else
        offToggle(cursorPos)
    end
    local newCursorPos = reaper.GetCursorPosition()
    if initialCursorPos == newCursorPos and itemStart ~= nil then
        reaper.SetEditCurPos(itemStart - 0.0000001, true, false)
        reaper.SetMediaItemSelected(item, false)
    end
end






local state_key = "com.kusa.toggletablikeprotools"
local toggleState = reaper.GetExtState(state_key, "ToggleState")
if toggleState == "" then
    local userChoice = showMessage('Please initialize the script by toggling "Tab to transients" at least once. Click "OK" to see the documentation.', "Error", 1)
    if userChoice == 1 then
        openURL("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/TOGGLE%20%26%20MAIN%20SCRIPTS%20SETUP.md")
    end
else
    main(toggleState)
end


