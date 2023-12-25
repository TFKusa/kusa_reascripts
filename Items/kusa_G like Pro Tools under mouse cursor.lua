-- @description kusa_G like Pro Tools under mouse cursor
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

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


local item, cursorPosition = reaper.BR_ItemAtMouseCursor()

if item then
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemStart + itemLength

    local fadeOutLength = itemEnd - cursorPosition
    if fadeOutLength > 0 then
        reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fadeOutLength)
    end
end

reaper.UpdateArrange()
