-- @description Creates unique region for each selected item, two ways to rename the regions for rendering (user prompt), sets render matrix to Master Mix. I'm preparing a short video presenting this script.
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website


local function regionsOverlap(region1, region2)
    return (region1.endPos > region2.startPos) and (region1.startPos < region2.endPos)
end

local function mergeRegions(region1, region2)
    return {
        startPos = math.min(region1.startPos, region2.startPos),
        endPos = math.max(region1.endPos, region2.endPos),
        name = region1.name,
    }
end

local function getHighestRegionNumber(project, baseName)
    local highestNum = 0
    local markerIndex = 0
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(project, markerIndex)
    
    while retval ~= 0 do
        if isrgn then
            local nameStart = string.match(name, "^(.-)_%d+$")
            if nameStart == baseName then
                local num = tonumber(string.match(name, "_%d+$"):sub(2))
                if num > highestNum then
                    highestNum = num
                end
            end
        end
        markerIndex = markerIndex + 1
        retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(project, markerIndex)
    end
    
    return highestNum
end

function getNextRegionCounter(project, mergedRegion)
    local baseRegionName = mergedRegion.name
    local highestRegionNumber = getHighestRegionNumber(project, baseRegionName)
    local regionCounter = highestRegionNumber + 1
    return regionCounter
end

function addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
    local regionNameWithNumber = mergedRegion.name .. "_" .. string.format("%02d", regionCounter)
    local regionIndex = reaper.AddProjectMarker2(project, true, mergedRegion.startPos, mergedRegion.endPos, regionNameWithNumber, -1, 0)
    reaper.SetRegionRenderMatrix(project, regionIndex, reaper.GetMasterTrack(0), 1)

    return regionIndex
end

function getHierarchicalTrackNames(track)
    local trackNames = {}
    while track do
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        table.insert(trackNames, trackName)
        track = reaper.GetParentTrack(track)
    end
    local reversedTrackNames = {}
    for i = #trackNames, 1, -1 do
        table.insert(reversedTrackNames, trackNames[i])
    end

    return table.concat(reversedTrackNames, "_")
end

------------------------------------------------------------------------------------------------------------------------------------

local dialogResult, userChoice = reaper.GetUserInputs("Region Naming Source", 1, "1: Item Track | 2: Selected Track", "1")
userChoice = tonumber(userChoice)
if not dialogResult then
    return
end

local project = reaper.EnumProjects(-1)
if project then
    local numSelectedItems = reaper.CountSelectedMediaItems(project)
    if numSelectedItems > 0 then
        local regionData = {}
        local lastRegionName = ""

        for i = 0, numSelectedItems - 1 do
            local selectedItem = reaper.GetSelectedMediaItem(project, i)
            local itemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
            local itemEndPosition = itemPosition + reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
            local regionName
            if userChoice == 1 then
                local parentTrack = reaper.GetMediaItemTrack(selectedItem)
                local parentTrackFromItem = reaper.GetMediaItemTrack(selectedItem)
                regionName = getHierarchicalTrackNames(parentTrackFromItem)
            elseif userChoice == 2 then
                local selectedTrack = reaper.GetSelectedTrack(0, 0)
                regionName = getHierarchicalTrackNames(selectedTrack)
            else
                reaper.MB("you don't have the right, O you don't have the right.", "Error", 0)
                return
            end

            table.insert(regionData, { name = regionName, startPos = itemPosition, endPos = itemEndPosition })
        end

        table.sort(regionData, function(a, b) return a.startPos < b.startPos end)
        local regionCounter = 1
        local mergedRegion = regionData[1]
        for i = 2, #regionData do
            if regionsOverlap(mergedRegion, regionData[i]) then
                mergedRegion = mergeRegions(mergedRegion, regionData[i])
            else
                regionCounter = getNextRegionCounter(project, mergedRegion)
                local regionIndex = addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
                lastRegionName = mergedRegion.name
                mergedRegion = regionData[i]
            end
        end

        regionCounter = getNextRegionCounter(project, mergedRegion)
        local regionIndex = addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
        reaper.UpdateArrange()
    else
        reaper.MB("No selected items.", "Error", 0)
    end
else
    reaper.MB("No project is open.", "Error", 0)
end