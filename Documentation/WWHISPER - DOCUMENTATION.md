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




        What is Wwhisper

Wwhisper is a ReaScript that enables REAPER to send commands to Wwise using project markers. When the script is running, REAPER enters a custom playing state that detects markers and performs various actions depending on their names.




        What is a Wwise Game Object ?

Think of Game Objects as the actors in your scene. They can be a character, a weapon or a piece of music. They can emit sound and be spatialized (or not) around the listener. The "Game Object 3D Viewer" window in Wwise allows you to visualize how Game Objects are positioned.




        Notes on Triggering Commands with Markers:

To activate a command from a marker that is placed earlier in the timeline than the current play cursor position when the script is run, prepend an exclamation point to the beginning of the marker name. This is particularly useful for initiating musical cues or other events that need to start from markers positioned well before the working point in the timeline.




        BASIC GAME OBJECTS COMMANDS :

InitObj_gameObjectName          - Registers a Game Object

example : InitObj_Player


UnRegObj_gameObjectName         - Unregisters a Game Object

example : UnRegObj_Player


ResetAllObj                     - Unregisters all Game Objects




        Notes on Game Object Management:

By default, only one Game Object is created when running the script ("Listener," positioned at 0,0,0). Calling a new Game Object in a command without initializing it will automatically create it. When playback is stopped, the script will shut down and unregister all active Game Objects.




        POSTING AN EVENT :

Event_eventName_gameObjectName

example : Event_PlayFootsteps_Solaire




        SETTING AN RTPC :

RTPC_rtpcName_value_gameObjectName

example : RTPC_PlayerSpeed_100_TrustyPatches

OR

RTPCInterp_rtpcName_startingValue_targetValue_interpTimeInMs_gameObjectName

example : RTPCInterp_PlayerSpeed_0_100_SiegmeyerOfCatarina




        SETTING A SWITCH :

Switch_switchGroupName_switchGroupState_gameObjectName

example : Switch_GroundMaterials_Stone_MarvelousChester




        SETTING A STATE :

State_stateGroupName_stateName

example : State_MusicMenuState_CrestfallenWarrior




        SETTING THE POSITION OF A GAME OBJECT :

SetPos_PosX_PosY_PosZ_gameObjectName

example : SetPos_10_0_0_BigHatLogan

OR

SetPosInterp_startPosX_startPosY_startPosZ_targetPosX_targetPosY_targetPosZ_interpTimeInMs_gameObjectName

example : SetPosInterp_-20_0_0_20_0_0_1500_PetrusOfThorolund