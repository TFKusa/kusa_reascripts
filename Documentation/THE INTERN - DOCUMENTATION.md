        THE INTERN - DOCUMENTATION

-- You will need to install Scythe library v3 for this script to work (available on ReaPack) --

The first tab of his script generates regions based on selected items, and uses Track Folder hierarchy to name them.
The second tab allows you to filter regions and render them to a folder, or just set them in the Render Region Matrix for ReaWwise (I am working on including WAAPI support)


        Tab 1 - Create Regions

items :
- Toggles selecting/deselecting all items in the (sub)project.

regions :
- Deletes all regions in the (sub)project.

Item's track :
- Creates an individual region for each selected item based on item length. If regions overlap (if the asset is multitrack for example), it will merge the overlapping regions into one.
- Renames the regions based on Track Folder names in the hierarchy (ends with name of the track that holds the item). If a track in the hierarchy has no name, it is not used.

Selected Track :
- Creates an individual region for each selected item based on item length. If regions overlap (if the asset is multitrack for example), it will merge the overlapping regions into one.
- Renames the regions based on Track Folder names in the hierarchy (ends with name of the currently selected track). If a track in the hierarchy has no name, it is skipped in the naming process.

Fix Increments :
- Fix Region IDs and increments in naming if they are not in sequential order. It is not moving the regions around, just re-creating and renaming them.



        Tab 2 - Render

Presets :
- The most common configurations for Sample Rate and Bit Depth. Note that it locks the settings if a preset is selected. To manually set different values, you would need to set Presets to "--".

Filter regions :
- If left blank, clicking on "To Region Matrix" or "Render to folder' will process every single region in the project.
- You can add keywords to specify which regions you want to export or set in the Region Render Matrix.
- You can add "&" or "/" operators between keywords to add or remove regions. (example : "footsteps&weapons/shotgun" will process any region that has footsteps and weapons in their name, minus the shotgun)

To Region Matrix :
- Sets "Master Mix" in the Matrix. Takes keywords into account.

Render to folder :
- Does not take Region Render Matrix into account, only keywords.
- Prompts the user for a directory. It will create a nested folder hierarchy based on the segments that build the region name.