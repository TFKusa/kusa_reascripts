-- @description kusa_S like Pro Tools under mouse cursor
-- @version 1.01
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function main()
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(42577, 0) -- Item: Split item under mouse cursor (select right)
    reaper.Main_OnCommand(40697, 0) -- Remove items/tracks/envelope points (depending on focus)
    reaper.Undo_EndBlock("S like Pro Tools under mouse cursor", 0)
end

main()