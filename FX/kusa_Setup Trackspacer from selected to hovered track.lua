-- @description kusa_Setup Trackspacer from selected to hovered track
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function main()
    sel_tr = reaper.GetSelectedTrack(0, 0)
    if not sel_tr then return end
    
    screen_x, screen_y = reaper.GetMousePosition()
    dest_tr = reaper.GetTrackFromPoint(screen_x, screen_y)
    if not dest_tr then return end
    
    trckspcr_id = reaper.TrackFX_AddByName(dest_tr, 'Trackspacer 2.5 (Wavesfactory)', false, 1)
    if trckspcr_id == -1 then
        reaper.ShowMessageBox("Trackspacer is not installed.", "Error", 0)
        return
    end

    ch_cnt = reaper.GetMediaTrackInfo_Value(dest_tr, 'I_NCHAN')
    reaper.SetMediaTrackInfo_Value(dest_tr, 'I_NCHAN', math.max(4, ch_cnt))
    new_id = reaper.CreateTrackSend(sel_tr, dest_tr)
    reaper.SetTrackSendInfo_Value(sel_tr, 0, new_id, 'I_DSTCHAN', 2)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create Nested Folder Structure From Selected Tracks", -1)






