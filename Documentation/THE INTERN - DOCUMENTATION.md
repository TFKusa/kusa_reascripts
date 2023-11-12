        THE INTERN - DOCUMENTATION

-- You will need to install Scythe library v3 for this script to work (available on ReaPack) --

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

Render to folder :
- Ignores Region Render Matrix settings, focusing solely on keywords. 
- Prompts for a directory and creates a nested folder hierarchy based on region names for rendering.