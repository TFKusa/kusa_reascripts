-- @description kusa_The Intern - Assistant TO the Region Manager
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

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

reaper.GetSetProjectInfo_String(0, 'RENDER_PATTERN','$region', true)
local project = reaper.EnumProjects(-1)
    local numSelectedItems = reaper.CountSelectedMediaItems(project)
    if numSelectedItems > 0 then
        local dialogResult, userChoice = reaper.GetUserInputs("Region Naming Source", 1, "1: Item Track | 2: Selected Track", "1")
        userChoice = tonumber(userChoice)
        if not dialogResult then
            return
        end
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

        function sortRegionsID()
            local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
            local regions = {}
    
            for i = 0, num_markers + num_regions - 1 do
                local retval, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
                if retval and isRegion then
                    table.insert(regions, {index = markrgnindexnumber, position = pos, endPos = rgnend, name = name, color = color})
                end
            end

            table.sort(regions, function(a, b) return a.position < b.position end)        
            reaper.Undo_BeginBlock()
    
            for _, region in ipairs(regions) do
                reaper.DeleteProjectMarker(0, region.index, true)
            end
        
            for _, region in ipairs(regions) do
                local new_index = reaper.AddProjectMarker2(0, true, region.position, region.endPos, region.name, -1, region.color)
                reaper.SetRegionRenderMatrix(0, new_index, reaper.GetMasterTrack(0), 1)
            end
        
            reaper.Undo_EndBlock("Sort and Renumber Regions and Set Render Matrix to Master Mix", -1)
            reaper.UpdateArrange()
        end

        function sortIncrements()
            function parseRegionName(name)
                local baseName = name:match("^(.-)%d+$")
                return baseName
            end            
            function buildNewName(baseName, idx)
                return baseName .. string.format("%02d", idx)
            end            
            local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
            local regions = {}
            for i = 0, num_markers + num_regions - 1 do
                local retval, isRegion, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
                if retval and isRegion then
                    local baseName = parseRegionName(name)
                    if baseName then
                        table.insert(regions, {index = idx, position = pos, endPos = rgnend, name = name, baseName = baseName, color = color})
                    end
                end
            end           
            local groupedRegions = {}
            for _, region in ipairs(regions) do
                groupedRegions[region.baseName] = groupedRegions[region.baseName] or {}
                table.insert(groupedRegions[region.baseName], region)
            end
            reaper.Undo_BeginBlock()
            for baseName, group in pairs(groupedRegions) do
                table.sort(group, function(a, b) return a.position < b.position end)
                for i, region in ipairs(group) do
                    local newName = buildNewName(baseName, i)
                    if region.name ~= newName then
                        reaper.SetProjectMarker3(0, region.index, true, region.position, region.endPos, newName, region.color)
                    end
                end
            end
            
            reaper.Undo_EndBlock("Sequentially Renumber Regions", -1)
            reaper.UpdateArrange()
        end

        sortRegionsID()
        sortIncrements()

    end