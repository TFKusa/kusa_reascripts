-- @description kusa_Exclusive solo
-- @version 1.00
-- @author Kusa
-- @website PORTFOLIO : https://thomashugofritz.wixsite.com/website
-- @website FORUM : https://forum.cockos.com/showthread.php?p=2745640#post2745640
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


local function getAllTracks()
    local tracks = {}  
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        tracks[i+1] = reaper.GetTrack(0, i)
    end 
    return tracks
end

local function getAllSelectedTracks()
    local selectedTracks = {}  
    local numSelectedTracks = reaper.CountSelectedTracks(0)
    for i = 0, numSelectedTracks - 1 do
        selectedTracks[i+1] = reaper.GetSelectedTrack(0, i)
    end 
    return selectedTracks
end

local function main()
    local allTracks = getAllTracks()
    local selectedTracks = getAllSelectedTracks()
    
    local selectedTrackSet = {}
    for _, track in ipairs(selectedTracks) do
        selectedTrackSet[track] = true
    end

    for _, track in ipairs(allTracks) do
        if not selectedTrackSet[track] then
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end

    for _, track in ipairs(selectedTracks) do
        local soloState = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        if soloState > 0 then
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        else
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 1)
        end
    end

    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
end


main()
