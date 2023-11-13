-- @description kusa_The Intern
-- @version 1.2
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR



local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end


loadfile(libPath .. "scythe.lua")()
local GUI = require("gui.core")
local Table = require("public.table")
local Font = require("public.font")
local Text = require("public.text")
local ColorPicker = require("gui.elements.ColorPicker")
local Color = require("public.color")
local Button = require("gui.elements.Button")
local Menubox = require("gui.elements.Menubox")
local Textbox = require("gui.elements.Textbox")
local Buffer = require("public.buffer")


-----------------------------------------------------------------
--------------------------VARIABLES------------------------------
-----------------------------------------------------------------


-- GUI
local dividerHeight = 90
local guiWidth = 500
local guiHeight = 500
local halfGuiWidth = guiWidth / 2
local layers

-- REGIONS
local num_markers, num_regions
local regions

--FONTS
local fontPresets = {
    bigImpact = { "Impact", 45, ""},
    smallImpact = { "Impact", 25, ""},
    bigTNR = { "Times New Roman", 28, "b"},
    smallTNR = { "Times New Roman", 24, ""},
    smallTNRB = { "Times New Roman", 24, "b"},
    medMonaco = { "Monaco", 18, ""},
    smallMonaco = { "Monaco", 16, ""},
}

-- OPTIONS
local presetSettings = {
    [2] = { dpSR = 1, dpBD = 1 },
    [3] = { dpSR = 2, dpBD = 2 },
    [4] = { dpSR = 3, dpBD = 3 }
}


-----------------------------------------------------------------
---------------------RECALL USER COLORS--------------------------
-----------------------------------------------------------------

-- COLORS
clrDefaultBg = Color.fromRgba(246, 225, 187, 255)
clrDefaultButtons = Color.fromRgba(152, 0, 0, 255)
clrDefaultTxt = Color.fromRgba(114, 8, 6, 255)


local loadedButtonHexColor = reaper.GetExtState("The Intern", "buttonHexColor")
if loadedButtonHexColor and loadedButtonHexColor ~= "" then
    local loadedButtonColorTable = Color.fromHex(loadedButtonHexColor)

    uiButtonColor = loadedButtonColorTable
else
    uiButtonColor = clrDefaultButtons
end

local loadedTxtHexColor = reaper.GetExtState("The Intern", "txtHexColor")
if loadedTxtHexColor and loadedTxtHexColor ~= "" then
    local loadedTxtColorTable = Color.fromHex(loadedTxtHexColor)

    uiTxtColor = loadedTxtColorTable
else
    uiTxtColor = clrDefaultTxt
end

local loadedBgHexColor = reaper.GetExtState("The Intern", "bgHexColor")
if loadedBgHexColor and loadedBgHexColor ~= "" then
    local loadedBgColorTable = Color.fromHex(loadedBgHexColor)

    uiBgColor = loadedBgColorTable
    uiForBgColor = Color.toRgba(uiBgColor)
else
    uiBgColor = clrDefaultBg
end


-----------------------------------------------------------------
---------------------SETUP BG COLORS-----------------------------
-----------------------------------------------------------------


local function divideTableExceptLast(tbl, valueToDivide)
    local newTable = {}
    for i = 1, #tbl do
        if i == #tbl then
            newTable[i] = tbl[i]
        else
            newTable[i] = tbl[i] / valueToDivide
        end
    end
    return newTable
end
-----------------------------------------------------------------
uiBgColorDarkest = divideTableExceptLast(uiBgColor, 1.8)
uiBgColorInactiveTab = divideTableExceptLast(uiBgColor, 1.3)
uiBgColorLighter = divideTableExceptLast(uiBgColor, 0.93)


-----------------------------------------------------------------
---------------------------DEBUG---------------------------------
-----------------------------------------------------------------


local function tableToString(tbl, depth)
    if depth == nil then depth = 1 end
    if depth > 5 then return "..." end

    local str = "{"
    for k, v in pairs(tbl) do
        local key = tostring(k)
        local value = type(v) == "table" and tableToString(v, depth + 1) or tostring(v)
        str = str .. "[" .. key .. "] = " .. value .. ", "
    end
    str = str:sub(1, -3)
    str = str .. "}"
    return str
end


-----------------------------------------------------------------
---------------------WINDOW SETTINGS-----------------------------
-----------------------------------------------------------------


local window = GUI.createWindow({
    name = "The Intern by Kusa",
    x = 0,
    y = 0,
    w = guiWidth,
    h = guiHeight,
    anchor = "mouse",
    corner = "C"
    })
-----------------------------------------------------------------
function window:redraw()
    if self.layerCount == 0 then return end
    
    local w, h = self.currentW, self.currentH
    
    if self.layers:any(function(l) return l.needsRedraw end)
        or self.needsRedraw then
    
        gfx.dest = 0
        gfx.setimgdim(0, -1, -1)
        gfx.setimgdim(0, w, h)
    
        Color.set(uiBgColor)
        gfx.rect(0, 0, w, h, 1)
    
        for i = #self.sortedLayers, 1, -1 do
        local layer = self.sortedLayers[i]
            if  (layer.elementCount > 0 and not layer.hidden) then
    
            if layer.needsRedraw or self.needsRedraw then
                layer:redraw()
            end
    
            gfx.blit(layer.buffer, 1, 0, 0, 0, w, h, 0, 0, w, h, layer.x, layer.y)
            end
        end
    
        if Scythe.developerMode then
        self:drawDev()
        else
        self:drawVersion()
        end   
    end
    
    gfx.mode = 0
    gfx.set(0, 0, 0, 1)
    
    gfx.dest = -1
    gfx.blit(0, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)
    
    gfx.update()
    
    self.needsRedraw = false
end
-----------------------------------------------------------------
function window:drawVersion()

    if not Scythe.version then return 0 end
  
    local str = "Scythe "..Scythe.version
  
    Font.set("version")
    Color.set(uiTxtColor)
  
    local strWidth, strHeight = gfx.measurestr(str)
  
    gfx.x = (guiWidth / 2) - strWidth / 2
    gfx.y = gfx.h - strHeight - 4
  
    gfx.drawstr(str)
  
end
-----------------------------------------------------------------

  layers = table.pack( GUI.createLayers(
    {name = "Layer1", z = 1},
    {name = "Layer2", z = 2},
    {name = "Layer3", z = 3},
    {name = "Layer4", z = 4},
    {name = "Layer5", z = 5}
    ))
  
window:addLayers(table.unpack(layers))


-----------------------------------------------------------------
------------------------URL SETUP--------------------------------
-----------------------------------------------------------------


function openURL(url)
    reaper.CF_ShellExecute(url)
end
-----------------------------------------------------------------
function onClickReadMe()
    openURL("https://github.com/TFKusa/kusa_reascripts/blob/master/Documentation/THE%20INTERN%20-%20DOCUMENTATION.md")
end


-----------------------------------------------------------------
-----------------------GLOBAL ELTS-------------------------------
-----------------------------------------------------------------

local theIntern, tabs, divider, readMe = GUI.createElements(
    {
        name = "The Intern",
        type = "Label",
        x = (guiWidth / 2) - 75,
        y = dividerHeight / 2 - 5,
        caption = "The Intern",
        font = { table.unpack(fontPresets["bigImpact"]) },
        color = uiButtonColor,
        shadow = true,
        bg = uiBgColor
    },    
    {
        name = "tabs",
        type = "Tabs",
        x = 0,
        y = 0,
        w = 64,
        h = 20,
        tabW = 150,
        tabH = 30,
        textFont = { table.unpack(fontPresets["medMonaco"]) },
        textColor = uiTxtColor,
        bg = uiBgColorDarkest,
        tabColorActive = uiBgColor,
        tabColorInactive = uiBgColorInactiveTab,
        tabs = {
            {
            label = "Create Regions",
            layers = {layers[3]}
            },
            {
            label = "Render",
            layers = {layers[4]}
            },
            {
            label = "Options/About",
            layers = {layers[5]}
            }
        },
    },
    {
        name = "Divider",
        type = "Frame",
        x = 0,
        y = dividerHeight,
        w = window.w,
        h = 1,
    },
    {
        name = "README",
        type = "Button",
        x = guiWidth * 9/10,
        y = dividerHeight / 2,
        w = 25,
        h = 25,
        caption = "?",
        font = smallImpact,
        textColor = uiBgColorLighter,
        fillColor = uiButtonColor,
        func = onClickReadMe
    }
)
-----------------------------------------------------------------
layers[1]:addElements(theIntern, tabs, divider, readMe)

layers[2]:addElements( GUI.createElement(
    {
        name = "frmTabBackground",
        type = "Frame",
        x = 0,
        y = 0,
        w = 448,
        h = 20,
    }
))


-----------------------------------------------------------------
---------------------TAB 2 USER PROMPTS--------------------------
-----------------------------------------------------------------


myTextbox = GUI.createElement({
    name = "myTextbox",
    type = "Textbox",
    x = (guiWidth / 2) - 60,
    y = guiHeight * (1/2) + 15,
    w = 150,
    h = 30,
    color = uiTxtColor,
    captionFont = { table.unpack(fontPresets["medMonaco"]) },
    textFont = { table.unpack(fontPresets["smallMonaco"]) },
    captionPosition = "left",
    caption = "Filter regions",
    retval = "",
    bg = uiBgColor
})
local dpChannel = GUI.createElement({
    name = "mnuChannels",
    type = "Menubox",
    x = (guiWidth / 2) - 60,
    y = guiHeight * (1/3)- 5,
    w = 150,
    h = 30,
    caption = "Channels:",
    captionColor = uiTxtColor,
    textColor = uiTxtColor,
    retval = 2,
    captionFont = { table.unpack(fontPresets["medMonaco"]) },
    textFont = { table.unpack(fontPresets["smallMonaco"]) },
    options = {"Mono","Stereo"},
    bg = uiBgColor
})
local dpSR = GUI.createElement({
    name = "mnuSR",
    type = "Menubox",
    x = (guiWidth / 2) - 60,
    y = guiHeight * (1/3) + 30,
    w = 150,
    h = 30,
    caption = "Sample Rate:",
    retval = 2,
    captionColor = uiTxtColor,
    textColor = uiTxtColor,
    captionFont = { table.unpack(fontPresets["medMonaco"]) },
    textFont = { table.unpack(fontPresets["smallMonaco"]) },
    options = {"44.1 kHz","48 kHz","96 kHz","192 kHz"},
    bg = uiBgColor
})
local dpBD = GUI.createElement({
    name = "mnuBD",
    type = "Menubox",
    x = (guiWidth / 2) - 60,
    y = guiHeight * (1/2) - 20,
    w = 150,
    h = 30,
    caption = "Bit Depth:",
    captionColor = uiTxtColor,
    textColor = uiTxtColor,
    retval = 2,
    captionFont = { table.unpack(fontPresets["medMonaco"]) },
    textFont = { table.unpack(fontPresets["smallMonaco"]) },
    options = {"16 Bit","24 Bit","32 Bit FP"},
    bg = uiBgColor
})
local dpPresets = GUI.createElement({
    name = "Presets",
    type = "Menubox",
    x = (guiWidth / 2) - 60,
    y = guiHeight * (1/5),
    w = 150,
    h = 30,
    caption = "Presets",
    captionColor = uiTxtColor,
    textColor = uiTxtColor,
    captionFont = { table.unpack(fontPresets["medMonaco"]) },
    textFont = { table.unpack(fontPresets["smallMonaco"]) },
    options = {"-", "44.1/16","48/24","96/32"},
    bg = uiBgColor
})
-----------------------------------------------------------------
function Menubox:drawFrame()

    local w, h = self.w, self.h
    local r, g, b, a = table.unpack(Color.colors.shadow)
    gfx.set(r, g, b, 1)
    gfx.rect(w + 3, 1, w, h, 1)
    gfx.muladdrect(w + 3, 1, w + 2, h + 2, 1, 1, 1, a, 0, 0, 0, 0 )
  
    Color.set(uiBgColorLighter)
    gfx.rect(1, 1, w, h)
    gfx.rect(1, w + 3, w, h)
  
    Color.set(uiBgColorInactiveTab)
    gfx.rect(1, 1, w, h, 0)
    if not self.noArrow then gfx.rect(1 + w - h, 1, h, h, 1) end
  
    Color.set(uiButtonColor)
    gfx.rect(1, h + 3, w, h, 0)
    gfx.rect(2, h + 4, w - 2, h - 2, 0)
  
end
-----------------------------------------------------------------
function Textbox:init()

    local w, h = self.w, self.h
  
    self.buffer = Buffer.get()
  
    gfx.dest = self.buffer
    gfx.setimgdim(self.buffer, -1, -1)
    gfx.setimgdim(self.buffer, 2*w, h)
  
    Color.set(uiBgColorLighter)
    gfx.rect(0, 0, 2*w, h, 1)
  
    Color.set(uiBgColorInactiveTab)
    gfx.rect(0, 0, w, h, 0)
  
    Color.set(uiButtonColor)
    gfx.rect(w, 0, w, h, 0)
    gfx.rect(w + 1, 1, w - 2, h - 2, 0)
  
    if gfx.w > 0 then self:recalculateWindow() end
  
end
-----------------------------------------------------------------
layers[4]:addElements( GUI.createElements(
    myTextbox, dpChannel, dpSR, dpBD, dpPresets
))


-----------------------------------------------------------------
---------------------TAB 3 USER PROMPTS--------------------------
-----------------------------------------------------------------


local btnClrPicker = GUI.createElement({
    name = "pickerbtn",
    type = "ColorPicker",
    x = guiWidth * 2/6,
    y = 115,
    w = 35,
    h = 35,
    color = uiButtonColor,
    bg = uiBgColor,
    captionFont = medMonaco,
    captionColor = uiButtonColor,
    caption = "Buttons",
})
local txtClrPicker = GUI.createElement({
    name = "pickertxt",
    type = "ColorPicker",
    x = guiWidth * 3/6,
    y = 115,
    w = 35,
    h = 35,
    color = uiTxtColor,
    bg = uiBgColor,
    captionFont = medMonaco,
    captionColor = uiButtonColor,
    caption = "Text",
})
local bgClrPicker = GUI.createElement({
    name = "pickerbg",
    type = "ColorPicker",
    x = guiWidth * 1/6,
    y = 115,
    w = 35,
    h = 35,
    color = uiBgColor,
    bg = uiBgColor,
    caption = "Background",
    captionColor = uiButtonColor,
    captionFont = 3
})
-----------------------------------------------------------------
function ColorPicker:drawCaption()
    if not self.caption or self.caption == "" then return end

    Font.set(self.captionFont)
    local strWidth, strHeight = gfx.measurestr(self.caption)

    gfx.x = self.x + (self.w - strWidth) / 2
    gfx.y = self.y + self.h - strHeight + 20

    Text.drawBackground(self.caption, self.bg)
    Text.drawWithShadow(self.caption, self.captionColor, "shadow")
end
-----------------------------------------------------------------
layers[5]:addElements( GUI.createElements(
    btnClrPicker, txtClrPicker, bgClrPicker
))


-----------------------------------------------------------------
-----------------------COMMON FUNCTIONS--------------------------
-----------------------------------------------------------------


function enc(data)  -- THANK YOU MPL http://forum.cockos.com/showthread.php?t=188335
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
      return ((data:gsub('.', function(x) 
          local r,b='',x:byte()
          for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
          return r;
      end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
          if (#x < 6) then return '' end
          local c=0
          for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
          return b:sub(c+1,c+1)
      end)..({ '', '==', '=' })[#data%3+1])
end
-----------------------------------------------------------------
function getProjectName()
    local _, projectPath = reaper.EnumProjects(-1, "")
    if projectPath == "" or not projectPath:match("%.RPP$") then
        return "Untitled_Project"
    else
        return string.match(projectPath, "([^\\/]*)%.RPP$")
    end
end
-----------------------------------------------------------------
function getCurrentProject()
    local project = reaper.EnumProjects(-1)
    return project
end
-----------------------------------------------------------------
function getAllRegions()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local regions = {}

    for i = 0, num_markers + num_regions - 1 do
        local retval, isRegion, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        if retval and isRegion then
            table.insert(regions, {
                index = markrgnindexnumber,
                position = pos,
                endPos = rgnend,
                name = name,
                color = color
            })
        end
    end

    return regions, num_markers, num_regions
end
-----------------------------------------------------------------
function deleteAllRegions(regions)
    reaper.Undo_BeginBlock()
  
    for _, region in ipairs(regions) do
        reaper.DeleteProjectMarker(0, region.index, true)
    end
  
    reaper.Undo_EndBlock("Delete all regions", -1)
    reaper.UpdateArrange()
end
-----------------------------------------------------------------
function toggleSelectAllItems()
    local itemCount = reaper.CountMediaItems(project)
  
    local anyItemSelected = false
    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(project, i)
        if reaper.IsMediaItemSelected(item) then
            anyItemSelected = true
            break
        end
    end
  
    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(project, i)
        reaper.SetMediaItemSelected(item, not anyItemSelected)
    end
  
    reaper.UpdateArrange()
end
-----------------------------------------------------------------
function countAndLoopThroughSelectedItems(project)
    local numSelectedItems = reaper.CountSelectedMediaItems(project)
    local items = {}

    if numSelectedItems > 0 then
        for i = 0, numSelectedItems - 1 do
            local selectedItem = reaper.GetSelectedMediaItem(project, i)
            table.insert(items, selectedItem)
        end
    end

    return items, numSelectedItems
end
-----------------------------------------------------------------
function getHierarchicalTrackNames(track)
    local trackNames = {}
    while track do
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if trackName and trackName ~= "" then
            table.insert(trackNames, trackName)
        end
        track = reaper.GetParentTrack(track)
    end
    local reversedTrackNames = {}
    for i = #trackNames, 1, -1 do
        table.insert(reversedTrackNames, trackNames[i])
    end

    return table.concat(reversedTrackNames, "_")
end
-----------------------------------------------------------------
function determineNamingMethod(useSelectedTrack, selectedItem)
    local regionName
    if useSelectedTrack then
        local parentTrackFromItem = reaper.GetMediaItemTrack(selectedItem)
        regionName = getHierarchicalTrackNames(parentTrackFromItem)
    else
        local selectedTrack = reaper.GetSelectedTrack(0, 0)
        regionName = getHierarchicalTrackNames(selectedTrack)
    end
    return regionName
end
-----------------------------------------------------------------
function storeAndSortRegionsData(items, useSelectedTrack)
    local regionData = {}
    for _, selectedItem in ipairs(items) do
        local itemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
        local itemEndPosition = itemPosition + reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
        local regionName = determineNamingMethod(useSelectedTrack, selectedItem)
        table.insert(regionData, { name = regionName, startPos = itemPosition, endPos = itemEndPosition })
    end

    table.sort(regionData, function(a, b) return a.startPos < b.startPos end)
    return regionData
end
-----------------------------------------------------------------
local function regionsOverlap(region1, region2)
    return (region1.endPos > region2.startPos) and (region1.startPos < region2.endPos)
end
-----------------------------------------------------------------
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
-----------------------------------------------------------------
function getNextRegionCounter(project, mergedRegion)
    local baseRegionName = mergedRegion.name
    local highestRegionNumber = getHighestRegionNumber(project, baseRegionName)
    local regionCounter = highestRegionNumber + 1
    return regionCounter
end
-----------------------------------------------------------------
function addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
    local regionNameWithNumber = mergedRegion.name .. "_" .. string.format("%02d", regionCounter)
    local regionIndex = reaper.AddProjectMarker2(project, true, mergedRegion.startPos, mergedRegion.endPos, regionNameWithNumber, -1, 0)
  
    return regionIndex
end
-----------------------------------------------------------------
local function mergeRegions(region1, region2)
    return {
        startPos = math.min(region1.startPos, region2.startPos),
        endPos = math.max(region1.endPos, region2.endPos),
        name = region1.name,
    }
  end
-----------------------------------------------------------------
function mergeAndCreateRegions(project, regionData)
    local regionCounter = 1
    local mergedRegion = regionData[1]

    for i = 2, #regionData do
        if regionsOverlap(mergedRegion, regionData[i]) then
            mergedRegion = mergeRegions(mergedRegion, regionData[i])
        else
            regionCounter = getNextRegionCounter(project, mergedRegion)
            local regionIndex = addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
            mergedRegion = regionData[i]
        end
    end

    regionCounter = getNextRegionCounter(project, mergedRegion)
    local regionIndex = addRegionWithRenderMatrix(project, mergedRegion, regionCounter)
    reaper.UpdateArrange()
end
-----------------------------------------------------------------
function processRegionsAccordingToUser(useSelectedTrack)
    local project = getCurrentProject()
    local items = countAndLoopThroughSelectedItems(project)
    local regionData = storeAndSortRegionsData(items, useSelectedTrack)
    mergeAndCreateRegions(project, regionData)
end
-----------------------------------------------------------------
function getRegionBaseName(name)
    local baseName = name:match("^(.-)%d+$")
    return baseName
end  
-----------------------------------------------------------------
function buildNewName(baseName, idx)
    return baseName .. string.format("%02d", idx)
end  
-----------------------------------------------------------------
function groupByBaseName(regions)
    local groupedRegions = {}
    for _, region in ipairs(regions) do
        local baseName = getRegionBaseName(region.name)
        if baseName then
            groupedRegions[baseName] = groupedRegions[baseName] or {}
            table.insert(groupedRegions[baseName], region)
        end
    end
    return groupedRegions
end
-----------------------------------------------------------------
function sortAndRename(groupedRegions)
    for baseName, group in pairs(groupedRegions) do
        table.sort(group, function(a, b) return a.position < b.position end)
        for i, region in ipairs(group) do
            region.name = buildNewName(baseName, i)
        end
    end
end
-----------------------------------------------------------------
function fixRegionsIDs()
    allRegions = getAllRegions()
    table.sort(allRegions, function(a, b) return a.position < b.position end)
    deleteAllRegions(allRegions)
    for _, region in ipairs(allRegions) do
        local new_index = reaper.AddProjectMarker2(0, true, region.position, region.endPos, region.name, -1, region.color)
    end
end
-----------------------------------------------------------------
function fixRegionsNames()
    allRegions = getAllRegions()
    local groupedRegions = groupByBaseName(allRegions)
    sortAndRename(groupedRegions)
    for _, group in pairs(groupedRegions) do
        for _, region in ipairs(group) do
            reaper.SetProjectMarker3(0, region.index, true, region.position, region.endPos, region.name, region.color)
        end
    end
end
-----------------------------------------------------------------
function createDirectory(path)
    local command
    if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
        command = 'mkdir "' .. path .. '"'
    else
        command = 'mkdir -p "' .. path .. '"'
    end
    os.execute(command)
end
-----------------------------------------------------------------
local function mapUserInputToSetting(userInput, options)
    return options[userInput] or options.default
end
-----------------------------------------------------------------
function processKeywords(userInput)
    local orderedKeywords = {}

    if userInput:sub(1, 1) == '/' and not userInput:find('&') then
        table.insert(orderedKeywords, {keyword = "", action = "include"})
    end

    for op, word in string.gmatch(userInput, '([&/]?)([^&/]+)') do
        local action = op == '/' and 'exclude' or 'include'
        table.insert(orderedKeywords, {keyword = word, action = action})
    end

    return orderedKeywords
end
-----------------------------------------------------------------
local function processRenderSettings()

    local sampleRateOptions = { [1] = 44100, [2] = 48000, [3] = 96000, [4] = 192000, default = 48000 }
    local userSR = dpSR:val()
    local sampleRate = mapUserInputToSetting(userSR, sampleRateOptions)

    local userChannels = dpChannel:val()
    local channels = userChannels == 1 and 1 or 2

    local toFormConfOptions = { [1] = 16, [2] = 24, [3] = 32, default = 16 }
    local userBD = dpBD:val()
    local toFormConf = mapUserInputToSetting(userBD, toFormConfOptions)

    local form_conf = {[1]=toFormConf, [2]=1}
    local out_str = ''
    for i = 1, #form_conf do 
        if not form_conf[i] then form_conf[i] = 0 end 
        out_str = out_str..tostring(form_conf[i]):char() 
    end
    return sampleRate, out_str, channels
end
-----------------------------------------------------------------
local function processDirectories()
    local retval, exportPath = reaper.JS_Dialog_BrowseForFolder("Select export directory", "")
    if not retval or exportPath == "" then return end
    local projectName = getProjectName()
    local projectExportPath = exportPath .. "/" .. projectName .. "_Export"
    createDirectory(projectExportPath)

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local orderedKeywords = processKeywords(myTextbox:val())
    

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, _, _, name, markrgnindex = reaper.EnumProjectMarkers(i)
        if isRegion then
            reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), -1)
            local finalAction = (#orderedKeywords == 0) and 'include' or nil

            for _, entry in ipairs(orderedKeywords) do
                if name:find(entry.keyword) then
                    finalAction = entry.action
                end
            end

            if finalAction == 'include' then
                local segments = {}
                for segment in string.gmatch(name, "([^_]+)") do
                    table.insert(segments, segment)
                end
                table.remove(segments)
                local currentPath = projectExportPath
                for _, segment in ipairs(segments) do
                    currentPath = currentPath .. "/" .. segment
                    createDirectory(currentPath)
                end
            end
        end
    end

    return projectExportPath, num_markers, num_regions, userKeywords, retval, exportPath
end
-----------------------------------------------------------------
local function splitString(str, delimiter)
    local segments = {}
    for segment in string.gmatch(str, "([^" .. delimiter .. "]+)") do
        table.insert(segments, segment)
    end
    return segments
end
-----------------------------------------------------------------
local function constructRenderPath(basePath, name)
    local segments = splitString(name, "_")
    local path = basePath
    for _, segment in ipairs(segments) do
        path = path .. "/" .. segment
    end
    return path
end


-----------------------------------------------------------------
--------------------BUTTONS FUNCTIONS----------------------------
-----------------------------------------------------------------


function onClickSelectAllItems()
    toggleSelectAllItems()
end
-----------------------------------------------------------------
function onClickItemTrack()
    local project = getCurrentProject()
    local _, items = countAndLoopThroughSelectedItems(project)
    if items > 0 then
    processRegionsAccordingToUser(true)
    end
end
-----------------------------------------------------------------
function onClickSelectedTrack()
    local project = getCurrentProject()
    local _, items = countAndLoopThroughSelectedItems(project)
    if items > 0 then
    processRegionsAccordingToUser()
    end
end
-----------------------------------------------------------------
function onClickFixIncrements()
    reaper.Undo_BeginBlock()

    fixRegionsIDs()
    fixRegionsNames()

    reaper.Undo_EndBlock("Fix Increments", -1)
    reaper.UpdateArrange()
end
-----------------------------------------------------------------
function onClickDeleteAllRegions()
    allRegions = getAllRegions()
    deleteAllRegions(allRegions)
end
-----------------------------------------------------------------
function onClickToNested()
    local sampleRate, out_str, channels = processRenderSettings()
    local projectExportPath, num_markers, num_regions, userKeywords, retval, exportPath = processDirectories()
    if not retval or exportPath == "" then return end
    local orderedKeywords = processKeywords(myTextbox:val())

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, startPos, endPos, name, markrgnindex = reaper.EnumProjectMarkers(i)
        if isRegion then
            local finalAction = (#orderedKeywords == 0) and 'include' or nil

            for _, entry in ipairs(orderedKeywords) do
                if name:find(entry.keyword) then
                    finalAction = entry.action
                end
            end

            if finalAction == 'include' then
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
                reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", enc('evaw'..out_str), true)
                reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 1, true)
                reaper.GetSetProjectInfo(0, "RENDER_STARTPOS", startPos, true)
                reaper.GetSetProjectInfo(0, "RENDER_ENDPOS", endPos, true)
                reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderPath, true)
                reaper.Main_OnCommand(41823, 0)
                reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), -1)
            end
        end
    end
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_ADD_ALLQUEUE"), 0)
    reaper.Main_OnCommand(41207, 0)
end
-----------------------------------------------------------------
function onClickToSimple()
    local sampleRate, out_str, channels = processRenderSettings()
    local retval, exportPath = reaper.JS_Dialog_BrowseForFolder("Select export directory", "")
    if not retval or exportPath == "" then return end
    local projectName = getProjectName()
    local projectExportPath = exportPath .. "/" .. projectName .. "_Export"
    createDirectory(projectExportPath)
    
    reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 8, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", sampleRate, true)
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", channels, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", enc('evaw'..out_str), true)   
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", projectExportPath, true)
    reaper.Main_OnCommand(41824, 0) 
end
-----------------------------------------------------------------
function editMatrix(setMatrix)
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local orderedKeywords = processKeywords(myTextbox:val())

    for i = 0, num_markers + num_regions - 1 do
        local _, isRegion, _, _, name, markrgnindex = reaper.EnumProjectMarkers(i)
        if isRegion then
            local finalAction = nil

            if #orderedKeywords == 0 then
                finalAction = setMatrix and 'include' or 'exclude'
            else
                for _, entry in ipairs(orderedKeywords) do
                    if name:find(entry.keyword) then
                        finalAction = entry.action
                    end
                end
            end

            if not setMatrix then
                reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), -1)
            end

            if finalAction == 'include' and setMatrix then
                reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), 1)
            elseif finalAction == 'exclude' then
                reaper.SetRegionRenderMatrix(0, markrgnindex, reaper.GetMasterTrack(0), -1)
            end
        end
    end
end
-----------------------------------------------------------------
function onClickToMatrix()
    editMatrix(true)
end
-----------------------------------------------------------------
function onClickResetMatrix()
    editMatrix()
end


-----------------------------------------------------------------
------------------------TAB 1 ELTS-------------------------------
-----------------------------------------------------------------


btnItemTrack = Button:new{
    name = "itemTrack",
    type = "Button",
    x = halfGuiWidth - 100,
    y = 320,
    w = 200,
    h = 45,
    caption = "Item's track",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickItemTrack
}
btnSelectedTrack = Button:new{
    name = "selectedTrack",
    type = "Button",
    x = halfGuiWidth - 100,
    y = 370,
    w = 200,
    h = 45,
    caption = "Selected track",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickSelectedTrack,
}
btnFixIncrements = Button:new{
    name = "Fix Increments",
    type = "Button",
    x = halfGuiWidth - 100,
    y = 420,
    w = 200,
    h = 45,
    caption = "Fix Increments",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickFixIncrements
}
btnToggleSelectAllItems = Button:new{
    name = "Toggle select all items",
    type = "Button",
    x = 30,
    y = 370,
    w = 55,
    h = 45,
    caption = "items",
    font = smallMonaco,
    textColor = uiBgColorLighter,
    fillColor = uiButtonColor,
    func = onClickSelectAllItems
}
btnDeleteAllRegions = Button:new{
    name = "Delete All Regions",
    type = "Button",
    x = guiWidth - 80,
    y = 370,
    w = 55,
    h = 45,
    caption = "regions",
    font = smallMonaco,
    textColor = uiBgColorLighter,
    fillColor = uiButtonColor,
    func = onClickDeleteAllRegions
}
-----------------------------------------------------------------
local descriptionType, description, descriptionToggle,descriptionDeleteRegions = GUI.createElements(
    {
        name = "Description Title",
        type = "Label",
        x = 28,
        y = guiHeight * (1/4),
        caption = "Select the items you want to render and choose\n         a method for renaming the regions.",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["bigTNR"]) },
        shadow = true,
        bg = uiBgColor
    },
    {
        name = "Description",
        type = "Label",
        x = 15,
        y = guiHeight * (1/2) - 30,
        caption = "The names of the regions are defined by the names of the\n          parent tracks in the Track Folder hierarchy.",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallTNRB"]) },
        shadow = true,
        bg = uiBgColor
    },
    {
        name = "Descriptiontoggle",
        type = "Label",
        x = 30,
        y = guiHeight - 80,
        caption = " Toggle",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        shadow = true,
        bg = uiBgColor
    },
    {
        name = "Descriptiondltreg",
        type = "Label",
        x = guiWidth - 73,
        y = guiHeight - 80,
        caption = "Delete",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        shadow = true,
        bg = uiBgColor
    }
)
layers[3]:addElements(btnItemTrack, btnSelectedTrack, btnFixIncrements, btnToggleSelectAllItems, btnDeleteAllRegions, descriptionType, description, descriptionToggle, descriptionDeleteRegions)


-----------------------------------------------------------------
--------------------TAB 2 OTHER ELTS-----------------------------
-----------------------------------------------------------------


btnRenderToNested = Button:new{
    name = "Render to folder nested",
    type = "Button",
    x = halfGuiWidth - 100,
    y = 420,
    w = 90,
    h = 45,
    caption = "Nested",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickToNested
}
btnRenderToSimple = Button:new{
    name = "Render to folder simple",
    type = "Button",
    x = halfGuiWidth + 10,
    y = 420,
    w = 90,
    h = 45,
    caption = "Simple",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickToSimple
}
btnToRegionMatrix = Button:new{
    name = "To Matrix",
    type = "Button",
    x = 35,
    y = 320,
    w = 150,
    h = 45,
    caption = "To Region Matrix",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickToMatrix
}
btnResetMatrix = Button:new{
    name = "Reset Matrix",
    type = "Button",
    x = guiWidth * 5/8,
    y = 320,
    w = 150,
    h = 45,
    caption = "Reset Matrix",
    fillColor = uiButtonColor,
    textColor = uiBgColorLighter,
    font = { table.unpack(fontPresets["smallImpact"]) },
    func = onClickResetMatrix
}

layers[4]:addElements( GUI.createElements(
    btnRenderToNested, btnToRegionMatrix, btnResetMatrix, btnRenderToSimple,
--[[     {
        name = "reaWwise",
        type = "Label",
        x = 5,
        y = 369,
        caption = "For ReaWwise & To Folder-Simple",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        shadow = true,
        bg = uiBgColor
    }, ]]
    {
        name = "renders",
        type = "Label",
        x = 215,
        y = 400,
        caption = "To Folder",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        shadow = true,
        bg = uiBgColor
    }
))


----------------------------------------------------------------- 
-------------------APPLY COLORS FUNCTION-------------------------
-----------------------------------------------------------------


function saveButtonColor()
    local buttonColorToSave = btnClrPicker:val()
    local buttonHexColor = Color.toHex(table.unpack(buttonColorToSave))
    reaper.SetExtState("The Intern", "buttonHexColor", buttonHexColor, true)
    uiButtonColor = buttonColorToSave

    local txtColorToSave = txtClrPicker:val()
    local txtHexColor = Color.toHex(table.unpack(txtColorToSave))
    reaper.SetExtState("The Intern", "txtHexColor", txtHexColor, true)
    uiTxtColor = txtColorToSave

    local bgColorToSave = bgClrPicker:val()
    local bgHexColor = Color.toHex(table.unpack(bgColorToSave))
    reaper.SetExtState("The Intern", "bgHexColor", bgHexColor, true)
    local uiBgColor = bgColorToSave

    window:close()
end
-----------------------------------------------------------------
function onClickWebsite()
    openURL("https://thomashugofritz.wixsite.com/website")
end
-----------------------------------------------------------------
function onClickMPL()
    openURL("http://forum.cockos.com/showthread.php?t=188335")
end


-----------------------------------------------------------------
-------------------------TAB 3 ELTS------------------------------
-----------------------------------------------------------------

  
layers[5]:addElements( GUI.createElements(
    {
        name = "Apply",
        type = "Button",
        x = guiWidth * 4/6,
        y = 125,
        w = 45,
        h = 25,
        caption = "Apply",
        fillColor = uiButtonColor,
        textColor = uiBgColorLighter,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        func = saveButtonColor
    },
    {
        name = "ApplyColors",
        type = "Label",
        x = guiWidth * 1/2 - 60,
        y = 180,
        caption = "Restart necessary",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["smallMonaco"]) },
        shadow = true,
        bg = uiBgColor
    },
    {
        name = "Divider2",
        type = "Frame",
        x = 0,
        y = 220,
        w = window.w,
        h = 1,
    },
    {
        name = "Description Title",
        type = "Label",
        x = 51,
        y = 390,
        caption = "Thanks to MPL for the Bit Depth system.",
        color = uiTxtColor,
        font = { table.unpack(fontPresets["bigTNR"]) },
        shadow = true,
        bg = uiBgColor
    },
    {
        name = "Divider3",
        type = "Frame",
        x = 0,
        y = 340,
        w = window.w,
        h = 1,
    },
    {
        name = "portfolio",
        type = "Button",
        x = halfGuiWidth - 100,
        y = 257,
        w = 200,
        h = 45,
        caption = "Website",
        fillColor = uiButtonColor,
        textColor = uiBgColorLighter,
        font = { table.unpack(fontPresets["smallImpact"]) },
        func = onClickWebsite
    },
    {
        name = "mpl",
        type = "Button",
        x = halfGuiWidth - 15,
        y = 420,
        w = 30,
        h = 30,
        caption = "",
        fillColor = uiButtonColor,
        textColor = uiBgColorLighter,
        font = { table.unpack(fontPresets["smallImpact"]) },
        func = onClickMPL
    }
))


-----------------------------------------------------------------
---------------------MAIN FUNCTIONS------------------------------
-----------------------------------------------------------------


local function Main()
    local userPreset = dpPresets:val()
    if presetSettings[userPreset] then
        dpSR:val(presetSettings[userPreset].dpSR)
        dpBD:val(presetSettings[userPreset].dpBD)
    end
    if window.state.resized then
        window:reopen({w = window.w, h = window.h})
    end
end

window:open()

GUI.func = Main

GUI.funcTime = 0

GUI.Main()