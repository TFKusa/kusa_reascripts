-- @description kusa_Bounce in place all items in the session via Master
-- @version 1.00
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

local tail = 3 -- in seconds

local function showMessage(string, title, errType)
    local userChoice = reaper.MB(string, title, errType)
    return userChoice
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function initParameters(trackIdx)
    local track = reaper.GetTrack(0, trackIdx)
    if not track then return nil end
    local itemCount = reaper.CountTrackMediaItems(track)

    return track, itemCount
end

local function setRenderArea(item, tail)
    local startSelection = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = startSelection + itemLength
    local endSelection = itemEnd + tail
    reaper.GetSet_LoopTimeRange(true, false, startSelection, endSelection, false)
    return startSelection
end

local function selectTrackByIndex(trackIdx)
    local track = reaper.GetTrack(0, trackIdx)
    if track then
        reaper.SetOnlyTrackSelected(track, true)
    end
end

local function getCurrentProjectRenderPath()
    local renderPath = reaper.GetProjectPath()
    return renderPath
end

local function stereoItemsInTrack(track, itemCount)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            local channels = reaper.GetMediaSourceNumChannels(source)
            if channels > 1 then
                return true
            end
        end
    end
    return false
end

local function getRenderSettings(track, itemCount)
    local renderPath = getCurrentProjectRenderPath()
    local stereoItemInTrack = stereoItemsInTrack(track, itemCount)
    local channels
    if stereoItemInTrack then
        channels = 2
    else
        channels = 1
    end
    return channels, renderPath
end

local function setRenderSettings(channels, renderPath)
    reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 128, true) -- Selected Track via Master
    reaper.GetSetProjectInfo(0, 'RENDER_ADDTOPROJ', 1, true) -- Add rendered file to project
    reaper.GetSetProjectInfo(0, 'RENDER_BOUNDSFLAG', 2, true) -- Bounds Time Selection
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", channels, true) -- Channels
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$track", true) -- Naming
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderPath, true) -- Render Path
end

local function getLastTrackAndIndex()
    local proj = 0
    local numTracks = reaper.GetNumTracks()
    local lastTrackIndex = numTracks - 1
    local lastTrack = reaper.GetTrack(proj, lastTrackIndex)
    return lastTrack, lastTrackIndex
end

local function createNewTrackAtEnd()
    local numTracks = reaper.GetNumTracks()
    reaper.InsertTrackAtIndex(numTracks, true)
end

local function getTrackName(track)
    local retval, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == "" then
        trackName = " "
    end
    return trackName
end

local function setTrackName(track, newName)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newName, true)
end

function setTrackColorToPaleRed(track)
    local paleRedColor = 0xFF6666
    reaper.SetTrackColor(track, paleRedColor)
end

local function newHostTrack(track)
    createNewTrackAtEnd()
    originalTrackName = getTrackName(track)
    lastTrack, lastTrackIndex = getLastTrackAndIndex()
    setTrackName(lastTrack, originalTrackName)
    setTrackColorToPaleRed(lastTrack)
end

local function moveItemsFromLastTrackUp()
    local proj = 0
    local numTracks = reaper.GetNumTracks()

    if numTracks < 2 then
        return
    end

    local lastTrack = reaper.GetTrack(proj, numTracks - 1)
    local destTrack = reaper.GetTrack(proj, numTracks - 2)
    local numItems = reaper.GetTrackNumMediaItems(lastTrack)

    for i = 0, numItems - 1 do
        local item = reaper.GetTrackMediaItem(lastTrack, i)
        reaper.MoveMediaItemToTrack(item, destTrack)
    end
    return lastTrack
end

local function cleanUp(track, itemCount, item)
    local lastTrack = moveItemsFromLastTrackUp()
    reaper.DeleteTrack(lastTrack)
end

local function iterateTrackItems(trackIdx, track, itemCount, tail)
    newHostTrack(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        selectTrackByIndex(trackIdx)
        local itemStartPosition = setRenderArea(item, tail)
        local channels, renderPath = getRenderSettings(track, itemCount)
        setRenderSettings(channels, renderPath)
        reaper.Main_OnCommand(42230, 0) -- Render, auto close render window
        cleanUp(track, itemCount, item)
    end
end

local function main(tail)
    local numTracks = reaper.GetNumTracks()

    for trackIdx = 0, numTracks - 1 do
        local track, itemCount = initParameters(trackIdx)
        if itemCount > 0 then
            iterateTrackItems(trackIdx, track, itemCount, tail)
        end
    end
end

reaper.Undo_BeginBlock()
local userInputMessage = showMessage("Have you set the desired Sample Rate and Bit Depth in the Render to File Window ?", "Warning", 3)
if userInputMessage == 6 then
    main(tail)
elseif userInputMessage == 7 then
    reaper.Main_OnCommand(40015, 0)
elseif userInputMessage == 2 then
    return
end
reaper.Undo_EndBlock("Bounce in place all items", -1)