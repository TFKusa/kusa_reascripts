WWHISPER - DOCUMENTATION


        Installation

- Install ReaPack : https://reapack.com
- In REAPER -> Extensions -> ReaPack -> Import repositories...
- Paste this link : https://github.com/TFKusa/kusa_reascripts/raw/master/index.xml
- Paste this other link : https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml
- In REAPER -> Extensions -> ReaPack -> Browse packages
- Type "kusa", highlight "kusa_Wwhisper", "kusa_Wwhisper Params" and "kusa_Wwhisper Assistant". Right click and install.
- Type "ReaWwise", right click on it and install it.
- You will also need the SWS Extension installed : https://www.sws-extension.org/


Note : "kusa_Wwhisper Params" is required for positioning Game Objects and setting RTPCs. "kusa_Wwhisper Assistant" is not mandatory, but will help you make things less tedious.




        What is Wwhisper

Wwhisper is a ReaScript that enables REAPER to send commands to Wwise using take markers. When the script is running, REAPER enters a custom playing state that detects markers and performs various actions depending on their names.

Wwhisper does not generate a Wwise project from REAPER (you can use ReaWwise, The Intern or any other tool to do that). Its purpose is solely to play back a sequence of events from an existing Wwise project through REAPER.




        Notes on Triggering Commands with Take Markers:

To activate a command from a take marker that is placed earlier in the timeline than the current play cursor position when the script is run, prepend an exclamation point to the beginning of the take marker name. This is particularly useful for initiating musical cues or other events that need to start from markers positioned well before the working point in the timeline.





        Notes on REAPER loops:

When looping over a sequence of events in REAPER, ensure that the loop duration is at least half a second. This helps to prevent double triggers due to markers having a cooldown period.





        Notes on Game Object Management:

By default, only one Game Object is created when running the script ("Listener," positioned at 0,0,0). Calling a new Game Object in a command without initializing it will automatically create it. When playback is stopped, the script will shut down and unregister all active Game Objects.




        What is a Wwise Game Object ?

Think of Game Objects as the actors in your scene. They can be a character, a weapon or a piece of music. They can emit sound and be spatialized (or not) around the listener. The "Game Object 3D Viewer" window in Wwise allows you to visualize how Game Objects are positioned.




        FEATURES :

- Sync with Wwise : In version 2 of the Assistant, a 'Sync with Wwise' button was added. It enables the retrieval of a list of all Wwise Objects and activates suggestions when entering an Object name and values.


<p align="center">
  <img src="https://i.postimg.cc/9FRp3kxF/syncwwisesmol.png" alt="Sync with Wwise" title="Sync with Wwise"/>
</p>


- Create a Game Object : Import your video into REAPER and select it. If you don't have a video available, create a time selection as an alternative.
Enter the name of your first Game Object in the Assistant's "Track / Game Object name" field, then click on "Create new track and item". Wwhisper will use the name of the take marker's parent track as the Game Object name.


<p align="center">
  <img src="https://i.postimg.cc/FRbWQvft/Screenshot-2024-03-25-at-12-14-26.png" alt="Wwhisper Assistant" title="Wwhisper Assistant"/>
</p>

When using "Wwhisper Assistant" to initiate a new track, it will automatically set the track in Latch mode, insert the Params plugin and enable automation for its panning parameters.



<p align="center">
  <img src="https://i.postimg.cc/tJf79Ym7/params-800.png" alt="New track" title="New track"/>
</p>


The Left/Right value is percentage based and relative to the Front/Back value. To track left and right movement, adjust the Params plugin window size to match the width of your video. You could then set the global REAPER playrate at 0.25, press play, and click on the "Left/Right" fader. Without releasing the button, track your actor's movement with your mouse. It should record the automation and, if configured correctly in Wwise, spatialize your audio assets.
Tip : To quickly toggle the visibility of automation envelopes for all tracks, use "Envelope: Toggle show all envelopes for all tracks" in the "Actions" menu.

        Limitation : The L/R system is great for 2D style layout, but is kind of restrictive for precise 3D positioning. I will expand on the Panner plugin to handle both cases, so keep an eye out for future updates :).


<p align="center">
  <img src="https://i.postimg.cc/gJ3q1bMC/params2-600.png" alt="Panner" title="Panner"/>
</p>

You can have several tracks sharing the same name for organisational purposes, and even make use of track folders. It will not affect the processing of markers.


<p align="center">
  <img src="https://i.postimg.cc/fLXpL1pk/REAPER-Timeline.png" alt="REAPER Timeline example" title="REAPER Timeline example"/>
</p>



        CREATION :

- Post an Event : Enter the name of one of your existing Wwise Events into the "Event name" text box in the Assistant, and create a take marker on your chosen Game Object.

- Set RTPC : Enter the name of one of your existing Wwise RTPCs into the "RTPC name" text box in the Assistant, along with its minimum and maximum values (which are automatically retrieved when the Assistant is synced with Wwise).
Select the target track (Game Object), then click on "Create RTPC automation lane" to create an automation item for that parameter, corresponding in length to the selected track's item.

The slider values in the Params plugin range from 0 to 100, where 0 represents the RTPC's minimum value and 100 its maximum value. Wwhisper will dynamically scale the slider output during playback.

- Set State : Enter the name of one of your existing Wwise State Groups/States into the appropriate text box in the Assistant, and create a take marker. States have a general scope and are not dependent on Game Objects.

- Set Switch : Enter the name of one of your existing Wwise Switch Groups/Switches into the appropriate text box in the Assistant, and create a take marker on your chosen Game Object.


        Chances are you won't need to use the following functions often. They can be useful at times, but Wwhisper will typically handle these automatically for you.

- Register Game Object : As mentioned previously, Wwhisper will automatically initialize a Game Object if a call is made on one that does not exist. However, you have the option to manually register a Game Object with this function.

- Unregister Game Object : Wwhisper will unregister all Game Objects when playback stops. You have the option to manually unregister a Game Object with this function.




        UTILITIES :

<p align="center">
  <img src="https://i.postimg.cc/LXCXWBQP/utilities-copy.png" alt="Utilities" title="Utilities"/>
</p>

- Generate project from Profiler txt : this feature allows you to import a Wwise capture log in TXT format and automatically generates a Reaper/Wwhisper setup to replicate the sequence of events logged in the TXT file.

        Known Limitation: This feature does not yet support Rooms and Portals, as these objects cannot be created through the standard ReaWwise interface. I have reached out to Audiokinetic to explore the possibility of distributing a modified version that would allow this functionality.

Wwise -> Project -> Profiler Settings: Ensure "API Calls" and "Game Syncs" are enabled.

<p align="center">
  <img src="https://i.postimg.cc/4ySd2MRD/profiler-settings-copy.png" alt="Profiler Settings" title="Profiler Settings"/>
</p>

Capture Log -> Right Click on Columns -> Configure Columns...: Ensure these elements are in the following order: Timestamp, Type, Description, Object Name, Game Object Name.

<p align="center">
  <img src="https://i.postimg.cc/t4HyRykr/capture-log-settings-copy.png" alt="Wwise Capture Log" title="Wwise Capture Log"/>
</p>

After the project has been generated, rename your listener's Game Object (depending on your engine/setup) to "Listener".

Example: If your profiler log is generated from Unreal Engine and your listener corresponds to the Player Camera, rename the track "PlayerCameraManager0.AkComponent_0" to "Listener."



Forum thread : https://forum.cockos.com/showthread.php?p=2745640#post2745640