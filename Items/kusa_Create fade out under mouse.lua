-- @description kusa_Create fade out under mouse
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


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
