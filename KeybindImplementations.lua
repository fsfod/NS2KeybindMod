//
//   Created by:   fsfod
//

KeybindMapper:LinkBindToFunction("OpenFeedback",  ShowFeedbackPage)

local OpenChat = false
local TeamChat = false

KeybindMapper:LinkBindToFunction("TeamChat",  function()
	OpenChat = true
	TeamChat = true
end)

KeybindMapper:LinkBindToFunction("TextChat",  function()
	OpenChat = true
end)

--have to delay opening chat one frame otherwise the chat frame will recive the character event from hiting the openchat keybind
Event.Hook("UpdateClient", function()

	if(not OpenChat) then
		return
	else
		OpenChat = false
	end
	
	KeybindMapper:ChatOpened()
	
	ChatUI_EnterChatMessage(TeamChat)
	TeamChat = false
end)

KeybindMapper:LinkBindToConsoleCmd("JoinMarines", "j1")
KeybindMapper:LinkBindToConsoleCmd("JoinAliens", "j2")
KeybindMapper:LinkBindToConsoleCmd("ReadyRoom", "rr")

KeybindMapper:LinkBindToConsoleCmd("NextIdleWorker", "gotoidleworker")
KeybindMapper:LinkBindToConsoleCmd("ExitCommandStructure", "logout")

--todo find a way to get team member count and use it here
local function JoinRandomTeam()
	if(NetworkRandom() < .5) then
	  Shared.ConsoleCommand("j1")
	else
		Shared.ConsoleCommand("j2")
	end
end

KeybindMapper:LinkBindToFunction("JoinRandom", JoinRandomTeam)

local WeaponSlotToInputBit = {
	"Weapon1",
	"Weapon2",
	"Weapon3",
	"Weapon4",
	"Weapon5",
}

local function SelectTick(state) 

  if(state.TickCount == 2) then
	  KeybindMapper:SetInputBit(state.InputBit, false)
   
   return state.Callback == nil
	end
	
	if(state.TickCount == 3) then
	  state.Callback()
	 return true
	end
	
	return false
end

function SelectCommandStructure(selectCompleteCallback)
	--we stil in the process of selecting the hotkey group
	if(KeybindMapper:GetActiveTickAction("SelectHotkeyGroup")) then
		return 1
	end

	local player = Client.GetLocalPlayer()
	local selectedEnts = player:GetSelection()

  local firstEntity = #selectedEnts == 1 and not Shared.GetEntity(selectedEnts[1]) 

	if(not firstEntity or not firstEntity:isa("CommandStructure") or not firstEntity:GetIsBuilt()) then

		for i = 1,Player.kMaxHotkeyGroups do
		 local group = player.hotkeyGroups[i]

  		if(#group == 1) then
  		  
				local entity = Shared.GetEntity(group[1])
				if(entity and entity:isa("CommandStructure")) then	
					local inputbit = WeaponSlotToInputBit[i]

					--Workaround for Commander:SelectHotkeyGroup not syncing changes to the server
					KeybindMapper:SetInputBit(inputbit, true)
					
					KeybindMapper:AddTickAction(SelectTick, {InputBit = inputbit, Callback = selectCompleteCallback}, "SelectHotkeyGroup", "NoReplace")

					return
				end
				
  		end
  	end

	  Shared.Message("Failed to find CommandStructure to select")
	else
	  selectCompleteCallback()
	end
end
 
local function DropTargetedTech(techId)
	
	local player = Client.GetLocalPlayer()
	
	if(not player:isa("Commander")) then
		return
	end

	if((techId == kTechId.AmmoPack or techId == kTechId.MedPack)) then
	  //stupid Commander:ProcessTechTreeActionForEntity does a check for active buttons serverside
	  player.buttonsScript:ButtonPressed(3)
	  
	  //player:SetCurrentTech(16)
	  /*
		local selectProgress = CheckSelectedCommandStructure()
		
		if(selectProgress == 0)then
			Shared.Message("CC needs tobe selected to drop health/ammo")
		end
		
		--we selected the cc this key press we have to wait for the server to register our selection before we can send the action
		if(selectProgress < 2 ) then
			return
		end
		*/
	end

	local x,y = Client.GetCursorPos()
	x = x*Client.GetScreenWidth()
	y = y*Client.GetScreenHeight()
	
	local normalizedPickRay = CreatePickRay(player, x, y)
   
   //player:GetCommanderPickTarget()
   
   player:SendTargetedAction(techId, normalizedPickRay, 0)
end



local SayingsMenu = {
  {
    MenuIndex = 1,
    "Saying_Acknowledge",
    "Saying_NeedMedpack",
    "Saying_NeedAmmo",
    "Saying_NeedOrder"
  },

  {
    MenuIndex = 2,
    "Saying_FollowMe",
	  "Saying_LetsMove",
	  "Saying_CoveringYou",
	  "Saying_Hostiles",
	  "Saying_Taunt",
	},
  
  {
    MenuIndex = 1,
	  "Saying_Needhealing",
	  "Saying_Followme",
    "Saying_Chuckle",
  }
}

local LastSayTrigger = 1

local function TriggerSaying(sayingIndex, sayingsMenu)

  if(Client.GetTime()-LastSayTrigger < 1) then
    
  end
  
  LastSayTrigger = Client.GetTime() 
  
  local message = BuildExecuteSayingMessage(sayingIndex, sayingsMenu)

  Client.SendNetworkMessage("ExecuteSaying", message, true)
end


for _,list in ipairs(SayingsMenu) do

  local sayingsMenu = list.MenuIndex

  for sayingIndex, bindName in ipairs(list) do
    KeybindMapper:LinkBindToFunction(bindName, TriggerSaying, "down", sayingIndex, sayingsMenu)
  end
end

KeybindMapper:LinkBindToFunction("DropAmmo", function() DropTargetedTech(kTechId.AmmoPack) end) 
KeybindMapper:LinkBindToFunction("DropHealth", function() DropTargetedTech(kTechId.MedPack) end)

KeybindMapper:LinkBindToFunction("DropCyst", function() 
  
  SelectCommandStructure(function()
    local player = Client.GetLocalPlayer()
	
	  if(not player:isa("Commander")) then
		  return
	  end
	  
	  //FIXME need todo this some other way
	  //return to the root menu if we not at it already
	  //if(player.menuTechId ~= kTechId.RootMenu) then
	  // player.buttonsScript:ButtonPressed(1)
	  //end
	  
	  player.buttonsScript:ButtonPressed(1)
  end)
end)

KeybindMapper.PrevWeaponSlot = 1
KeybindMapper.CurrentWeaponSlot = 1


local currentWeapon = 1

Event.Hook("UpdateClient", function()
  
  local player = Client.GetLocalPlayer()
  
  if(not player or not player.GetActiveWeapon) then
    return
  end

  //if(Shared.GetIsRunningPrediction()) then
  //  RawPrint(Shared.GetIsRunningPrediction())
  //end

  local currentWeaponEntity = player:GetActiveWeapon()
  
  if(currentWeaponEntity) then
    
    local slot = currentWeaponEntity:GetHUDSlot()
    
    if(slot ~= currentWeapon) then
      //RawPrint("Weapon slot changed from %i to %i", currentWeapon, slot)
      
      currentWeapon = slot
      
      KeybindMapper:WeaponChanged(slot)
    end
  end
  
end)

local PrevWeaponSlot = 1
local CurrentWeaponSlot = 1

function KeybindMapper:WeaponChanged(weaponSlot, name)

  PrevWeaponSlot = CurrentWeaponSlot
  CurrentWeaponSlot = weaponSlot
  //player.showSayings
end

KeybindMapper:LinkBindToFunction("LastWeapon", function()
  KeybindMapper:PulseInputBit(WeaponSlotToInputBit[PrevWeaponSlot], "LastWeapon")
end)