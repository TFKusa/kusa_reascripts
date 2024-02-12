WWHISPER - DOCUMENTATION


        Installation

-- You will need to install ReaWwise for this script to work --

- Install ReaPack : https://reapack.com
- In Reaper -> Extensions -> ReaPack -> Import repositories...
- Paste this link : https://github.com/TFKusa/kusa_reascripts/raw/master/index.xml
- Paste this other link : https://github.com/Audiokinetic/Reaper-Tools/raw/main/index.xml
- In Reaper -> Extensions -> ReaPack -> Browse packages
- Type "kusa", right click on "kusa_Wwhisper" and install it.
- Type "ReaWwise", right click on it and install it.
        If you'd like to use Wwhisper - Take Marker Creator as well (higly recommended), please download and install ReaImGui on ReaPack.




        What is Wwhisper

Wwhisper is a ReaScript that enables REAPER to send commands to Wwise using take markers. When the script is running, REAPER enters a custom playing state that detects markers and performs various actions depending on their names.




        What is a Wwise Game Object ?

Think of Game Objects as the actors in your scene. They can be a character, a weapon or a piece of music. They can emit sound and be spatialized (or not) around the listener. The "Game Object 3D Viewer" window in Wwise allows you to visualize how Game Objects are positioned.




        Notes on Triggering Commands with Take Markers:

To activate a command from a take marker that is placed earlier in the timeline than the current play cursor position when the script is run, prepend an exclamation point to the beginning of the take marker name. This is particularly useful for initiating musical cues or other events that need to start from markers positioned well before the working point in the timeline.




        Notes on Game Object Management:

By default, only one Game Object is created when running the script ("Listener," positioned at 0,0,0). Calling a new Game Object in a command without initializing it will automatically create it. When playback is stopped, the script will shut down and unregister all active Game Objects.



        If you are not using Wwhisper - Take Marker Creator, here's how you can manually rename your markers :


        BASIC GAME OBJECTS COMMANDS :

InitObj;gameObjectName          - Registers a Game Object

example : InitObj;Player


UnRegObj;gameObjectName         - Unregisters a Game Object

example : UnRegObj;Player


ResetAllObj                     - Unregisters all Game Objects




        POSTING AN EVENT :

Event;eventName;gameObjectName

example : Event;PlayFootsteps;Solaire




        SETTING AN RTPC :

RTPC;rtpcName;value;gameObjectName

example : RTPC;PlayerSpeed;100;TrustyPatches

OR

RTPCInterp;rtpcName;startingValue;targetValue;interpTimeInMs;gameObjectName

example : RTPCInterp;PlayerSpeed;0;100;SiegmeyerOfCatarina




        SETTING A SWITCH :

Switch;switchGroupName;switchGroupState;gameObjectName

example : Switch;GroundMaterials;Stone;MarvelousChester




        SETTING A STATE :

State;stateGroupName;stateName

example : State;MusicMenuState;CrestfallenWarrior




        SETTING THE POSITION OF A GAME OBJECT :

SetPos;PosX;PosY;PosZ;gameObjectName

example : SetPos;10;0;0;BigHatLogan

OR

SetPosInterp;startPosX;startPosY;startPosZ;targetPosX;targetPosY;targetPosZ;interpTimeInMs;gameObjectName

example : SetPosInterp;-20;0;0;20;0;0;1500;PetrusOfThorolund