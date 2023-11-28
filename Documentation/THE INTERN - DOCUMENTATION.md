THE INTERN - DOCUMENTATION


        Installation

-- You will need to install Scythe library v3 and SWS Extension for this script to work --

- Install ReaPack : https://reapack.com
- Install SWS : https://www.sws-extension.org
- In Reaper -> Extensions -> ReaPack -> Import repositories...
- Paste this link : https://github.com/TFKusa/kusa_reascripts/raw/master/index.xml
- In Reaper -> Extensions -> ReaPack -> Browse packages
- Type "kusa", right click on "kusa_The Intern" and install it.
- Type "Scythe", right click on "Scythe library v3" and install it
- Type "JS_ReaScript", right click on "js_ReaScriptAPI: API functions for ReaScripts" and install it
- In Reaper -> Actions -> Show actions list -> type "Scythe" and run "Scythe_Set v3 library path"
- You should be able to find "kusa_The Intern" in the Action list and use it !




        What is The Intern

The Intern is a ReaScript that enhances region and rendering management. It utilizes Track Folder hierarchy for naming regions and supports filtering for rendering processes.



        Tab 1 - Create Regions

items :
- Quickly select or deselect all items in the project.

regions :
- Removes all existing regions in the project.

Item's track :
- Creates an individual region for each selected item based on item length. If regions overlap (if the asset is made of multiple items on different tracks for example), it will merge the overlapping regions into one.
- Names regions based on the Track Folder hierarchy, ending with the track holding the item. If a track in the hierarchy has no name, it is not used.

Selected Track :
- Creates an individual region for each selected item based on item length. If regions overlap (if the asset is made of multiple items on different tracks for example), it will merge the overlapping regions into one.
- Similar to 'Item's track', but uses the currently selected track for naming.

Fix Increments :
- Adjusts region IDs and renames them to ensure sequential order without altering their positions.



        Tab 2 - Render

Presets :
- The most common configurations for Sample Rate and Bit Depth. Note that it locks the settings if a preset is selected. To manually set different values, you would need to set Presets to "-".

Filter regions :
- Leave blank to process all regions.
- Add keywords to specify target regions for export or matrix setup.
- Use "&" or "/" to include or exclude regions based on keywords. (examples :
"footsteps/01&weapons" will process any region that has "footsteps" in their name excluding the first iteration, and any region that has "weapons" in their name.
"footsteps&weapons/01" will process any region that has "footsteps" and/or "weapons", excluding the first iteration of each).

To Region Matrix :
- Configures regions to "Master Mix" in the Matrix, considering the specified keywords.

Master folder :
- Whether the script needs to create a "MyProjectName_Export" folder within the directory selected by the user

Nested :
- Prompts for a directory and creates a nested folder hierarchy based on region names for rendering.

Simple :
- Prompts for a directory and creates a new folder for rendering.

Render to Wwise :
- Set up in the Matrix the regions you want to export
- Choose a container type (or no container at all)
- Go !

        !! MAKE SURE THAT REAPER HAS FOCUS WHEN RENDERING. If it doesn't have focus, the items will be offline and it will create blank files (this behaviour can be changed in the Reaper preferences) !!

Precisions : It will create a nested folder hierarchy with the assets in pathToYourWwiseProjectFolder/Originals/SFX.
It will also group regions that have the same base name (name without the incrementing number) in the same container, if a container is selected in the dropdown menu.