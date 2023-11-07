-- @description kusa_The Intern - Render (Prompts)
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR


function createDirectory(path)
    local command
    if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        command = 'mkdir "' .. path .. '"'
    else
        command = 'mkdir -p "' .. path .. '"'
    end
    os.execute(command)
end

function getProjectName()
    local _, projectPath = reaper.EnumProjects(-1, "")
    if projectPath == "" then
        return "Untitled_Project"
    else
        return string.match(projectPath, "([^\\/]*)%.RPP$")
    end
end

function main()
    local retval, sampleRateChoice = reaper.GetUserInputs("Set Sample Rate", 1, "1=48   2=96    3=44.1", "")
    if not retval or sampleRateChoice == "" then return end
    local sampleRates = {["1"] = 48000, ["2"] = 96000, ["3"] = 44100}
    local sampleRate = sampleRates[sampleRateChoice] or 48000

    local retval, bitDepthChoice = reaper.GetUserInputs("Set Bit Depth", 1, "1=24   2=32    3=16,", "")
    if not retval or bitDepthChoice == "" then return end
    local bitDepths = {["1"] = " b=24", ["2"] = " b=32", ["3"] = " b=16"}
    local bitDepth = bitDepths[bitDepthChoice] or " b=24"

    local retval, channelsChoice = reaper.GetUserInputs("Set Channels", 1, "1=Mono  2=Stereo,", "")
    if not retval or channelsChoice == "" then return end
    local channels = (channelsChoice == "1") and 1 or 2

    local retval, keyword = reaper.GetUserInputs("Region Filter", 1, "Enter keyword (0 for all regions):", "")
    if not retval then return end

    local retval, exportPath = reaper.JS_Dialog_BrowseForFolder("Select export directory", "")
    if not retval or exportPath == "" then return end

    local projectName = getProjectName()
    local projectExportPath = exportPath .. "/" .. projectName .. "_Export"
    createDirectory(projectExportPath)

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, _, _, name = reaper.EnumProjectMarkers(i)
        if isRegion and (keyword == "0" or name:find(keyword)) then
            local segments = {}
            for segment in string.gmatch(name, "([^_]+)") do
                table.insert(segments, segment)
            end
            table.remove(segments) -- Remove the last segment (number)
            local currentPath = projectExportPath
            for _, segment in ipairs(segments) do
                currentPath = currentPath .. "/" .. segment
                createDirectory(currentPath)
            end
        end
    end

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, startPos, endPos, name, markrgnindex = reaper.EnumProjectMarkers(i)
        if isRegion and (keyword == "0" or name:find(keyword)) then
            local segments = {}
            for segment in string.gmatch(name, "([^_]+)") do
                table.insert(segments, segment)
            end
            table.remove(segments)
            local currentPath = projectExportPath
            for _, segment in ipairs(segments) do
                currentPath = currentPath .. "/" .. segment
            end

            local renderPath = currentPath
            reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), 1)
            reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 8, true)
            reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
            reaper.GetSetProjectInfo(0, "RENDER_SRATE", sampleRate, true)
            reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", channels, true)
            local format_config = "e=WAVE"
            format_config = format_config .. bitDepth
            reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", format_config, true)
            reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 1, true)
            reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", startPos, true)
            reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", endPos, true)
            reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderPath, true)
            reaper.Main_OnCommand(41823, 0)
            reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), -1)
        end
    end
end

main()
reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_ADD_ALLQUEUE"), 0)
reaper.Main_OnCommand(41207, 0)
