-- @description kusa_B like Pro Tools under mouse cursor
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local function main()
    reaper.Undo_BeginBlock()
    reaper.Main_OnCommand(42575, 0) -- Item: Split item under mouse cursor
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    reaper.Undo_EndBlock("B like Pro Tools under mouse cursor", 0)
end

main()