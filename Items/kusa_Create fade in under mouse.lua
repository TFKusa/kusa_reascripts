-- @description kusa_Create fade in under mouse
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local item, cursorPosition = reaper.BR_ItemAtMouseCursor()

if item then
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local fadeInLength = cursorPosition - itemStart
    if fadeInLength > 0 then
        reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fadeInLength)
    end
end

reaper.UpdateArrange()
