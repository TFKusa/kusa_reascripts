-- @description kusa_The Intern - Render 48-24 Stereo to folder (Prompt)
-- @version 1.0
-- @author Kusa
-- @website https://thomashugofritz.wixsite.com/website
-- @donation https://paypal.me/tfkusa?country.x=FR&locale.x=fr_FR

function main()
    retval, render_path = reaper.JS_Dialog_BrowseForFolder("Select render directory", "")
    if not retval or render_path == "" then return end
    reaper.GetSetProjectInfo(0, 'RENDER_SETTINGS', 8, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
    reaper.GetSetProjectInfo(0, "RENDER_SRATE", 48000, true)
    reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 2, true)
    local format_config = "e=WAVE"
    format_config = format_config .. " b=24"
    reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", format_config, true)
    reaper.GetSetProjectInfo_String(0, "RENDER_FILE", render_path, true)
    reaper.Main_OnCommand(42230, 0)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Set Render Settings", -1)
