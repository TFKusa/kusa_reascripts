WWHISPER - DOCUMENTATION


        Installation

- Install ReaPack : https://reapack.com
- In REAPER -> Extensions -> ReaPack -> Import repositories...
- Paste this link : https://github.com/TFKusa/kusa_reascripts/raw/master/index.xml
- Paste this other link : https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml
- In REAPER -> Extensions -> ReaPack -> Browse packages
- Type "kusa", highlight "kusa_Wwhisper", "kusa_Wwhisper Panner" and "kusa_Wwhisper Assistant". Right click and install.
- Type "ReaWwise", right click on it and install it.
- You will also need the SWS Extension installed : https://www.sws-extension.org/


Note : "kusa_Wwhisper Panner" is required for positioning Game Objects. "kusa_Wwhisper Assistant" is not mandatory, but will help you make things less tedious.




        What is Wwhisper

Wwhisper is a ReaScript that enables REAPER to send commands to Wwise using take markers. When the script is running, REAPER enters a custom playing state that detects markers and performs various actions depending on their names.




        What is a Wwise Game Object ?

Think of Game Objects as the actors in your scene. They can be a character, a weapon or a piece of music. They can emit sound and be spatialized (or not) around the listener. The "Game Object 3D Viewer" window in Wwise allows you to visualize how Game Objects are positioned.




        Notes on Triggering Commands with Take Markers:

To activate a command from a take marker that is placed earlier in the timeline than the current play cursor position when the script is run, prepend an exclamation point to the beginning of the take marker name. This is particularly useful for initiating musical cues or other events that need to start from markers positioned well before the working point in the timeline.




        Notes on Game Object Management:

By default, only one Game Object is created when running the script ("Listener," positioned at 0,0,0). Calling a new Game Object in a command without initializing it will automatically create it. When playback is stopped, the script will shut down and unregister all active Game Objects.




        QUICK START :

- Import your video into REAPER and select it. If you don't have a video available, create a time selection as an alternative.
- Enter the name of your first Game Object in the Assistant's "Track / Game Object name" field, then click on "Create new track and item". Note that take markers will use the name of the parent track as the Game Object name.


<p align="center">
  <img src="https://i.postimg.cc/7PmfhYdT/Wwhisper-Assistant.png" alt="Wwhisper Assistant" title="Wwhisper Assistant"/>
</p>


- When using "Wwhisper Assistant" to initiate a new track, it will automatically set the track in Latch mode, insert the Panner plugin and enable automation for its parameters.


<p align="center">
  <img src="https://i.postimg.cc/prjCsk05/Panner.png" alt="New track" title="New track"/>
</p>


- The Left/Right value is percentage based and relative to the Front/Back value. To track left and right movement, adjust the Panner plugin window size to match the width of your video. You could then set the global REAPER playrate at 0.25, press play, and click on the "Left/Right" fader. Without releasing the button, track your actor's movement with your mouse. It should record the automation and, if configured correctly in Wwise, spatialize your audio assets.
Tip : To quickly toggle the visibility of automation envelopes for all tracks, use "Envelope: Toggle show all envelopes for all tracks" in the "Actions" menu.


<p align="center">
  <img src="https://i.postimg.cc/5yW8pz6s/L-R.png" alt="Panner" title="Panner"/>
</p>


- You can have several tracks sharing the same name for organisational purposes, and even make use of track folders. It will not affect the processing of markers.


<p align="center">
  <img src="https://i.postimg.cc/fLXpL1pk/REAPER-Timeline.png" alt="REAPER Timeline example" title="REAPER Timeline example"/>
</p>


Limitations : The L/R system is great for 2D style layout, but is kind of restrictive for precise 3D positioning. I will expand on the Panner plugin to handle both cases, so keep an eye out for future updates :).



Forum thread : https://forum.cockos.com/showthread.php?p=2745640#post2745640