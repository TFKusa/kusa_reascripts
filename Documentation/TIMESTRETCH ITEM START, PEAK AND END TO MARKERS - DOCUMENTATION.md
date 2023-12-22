TIMESTRETCH ITEM START, PEAK AND END TO MARKERS


This script is available in two versions : regular and no prompt.


        REGULAR VERSION :

Select an item and run the script.
Enter a marker ID. The script will locate the specified marker and the next two markers on the timeline.
The script will then :
- Set the start of the item at the position of the first marker.
- Stretch the peak amplitude to align with the second marker's position
- Stretch the end of the item to align with the third marker's position.


        NO PROMPT VERSION :

This version performs the same actions, but is designed for quicker execution by automatically fetching the nearest marker to the start of the selected item.
It searches for any marker within a 10-second radius of the item's start (5 seconds before and 5 seconds after).