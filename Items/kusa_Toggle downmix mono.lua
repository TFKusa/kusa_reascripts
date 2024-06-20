-- @description kusa_Toggle downmix mono
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local function tableIsEmpty(table)
    for _ in pairs(table) do
        return false
    end
    return true
end

local function storeSelectedMediaItems()
    local itemCount = reaper.CountSelectedMediaItems(0)
    local selectedItems = {}
    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if item and take then
            table.insert(selectedItems, item)
        end
    end
    if tableIsEmpty(selectedItems) then
        return nil
    else
        return selectedItems
    end
end

local function main()
    local selectedItems = storeSelectedMediaItems()
    if selectedItems then
        reaper.Undo_BeginBlock()
        for _, item in ipairs(selectedItems) do
            if item then
                local take = reaper.GetActiveTake(item)
                if take then
                    local chanMode = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE")
                    if chanMode == 0.0 then
                        -- Set take channel mode to mono (downmix)
                        reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 2.0)
                    elseif chanMode == 2.0 then
                        -- Set take channel mode to normal
                        reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 0.0)
                    end
                end
            end
        end
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("kusa_Create single loop from item", -1)
    end
end
    
main()