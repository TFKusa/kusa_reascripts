-- @description kusa_The Intern - Toggle Hide/Show All Tracks Except Selected
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


if not reaper.HasExtState("ToggleHideShowScript", "State") then
    reaper.SetExtState("ToggleHideShowScript", "State", "show_all", false)
end

function main()
    local state = reaper.GetExtState("ToggleHideShowScript", "State")
    local count = reaper.CountTracks(0)
    if state == "show_all" then
        for i = 0, count - 1 do
            local track = reaper.GetTrack(0, i)
            if not reaper.IsTrackSelected(track) then
                reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
                reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end
        reaper.SetExtState("ToggleHideShowScript", "State", "hide_others", false)
    else
        for i = 0, count - 1 do
            local track = reaper.GetTrack(0, i)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
            reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        reaper.SetExtState("ToggleHideShowScript", "State", "show_all", false)
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Toggle Hide/Show All Tracks Except Selected", -1)
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
