-- @description kusa_The Intern - Structure selected tracks into a nested folder hierarchy
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function main()
    local trackCount = reaper.CountSelectedTracks(0)
    if trackCount < 2 then
        reaper.ShowMessageBox("Please select at least two tracks for this script to work.", "Not Enough Tracks Selected", 0)
        return
    end

    for i = 0, trackCount - 2 do
        local currentTrack = reaper.GetSelectedTrack(0, i)
        local nextTrack = reaper.GetSelectedTrack(0, i + 1)
        reaper.SetMediaTrackInfo_Value(currentTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(nextTrack, "I_FOLDERDEPTH", -1)
    end

    local lastTrack = reaper.GetSelectedTrack(0, trackCount - 1)
    reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", 0)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create Nested Folder Structure From Selected Tracks", -1)
