

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

--todo find a way to get team member count and use it here
local function JoinRandomTeam()
	if(NetworkRandom() < .5) then
	  Shared.ConsoleCommand("j1")
	else
		Shared.ConsoleCommand("j2")
	end
end

KeybindMapper:LinkBindToFunction("JoinRandom", JoinRandomTeam)

local NumberToInputBit = {
	Move.Weapon1,
	Move.Weapon2,
	Move.Weapon3,
	Move.Weapon4,
	Move.Weapon5,
}

function CheckSelectedCommandStructure()
	--we still in the process of selecting the hotkey group
	if(KeybindMapper:IsTickActionActive("SelectHotkeyGroup")) then
		return 1
	end

	local player = Client.GetLocalPlayer()
	local selectedEnts = player:GetSelection()

	if(#selectedEnts ~= 1 or not Shared.GetEntity(selectedEnts[1]) or not Shared.GetEntity(selectedEnts[1]):isa("CommandStructure")) then

		for i = 1,Player.kMaxHotkeyGroups do
		 local group = player.hotkeyGroups[i]

  		if(#group == 1) then
				local entity = Shared.GetEntity(group[1])
				if(entity and entity:isa("CommandStructure")) then	
					local inputbit = NumberToInputBit[i]

					--Workaround for Commander:SelectHotkeyGroup not syncing changes to the server
					KeybindMapper:HandleInputBit(inputbit, true)
					
					KeybindMapper:AddTickAction(function(state) 
						if(state.TickCount == 2) then
							KeybindMapper:HandleInputBit(inputbit, false)
						 return true
						end
					end, nil, "SelectHotkeyGroup", "NoReplace")

					return 1
				end
  		end
  	end

		 Shared.Message("Failed to find CommandStructure to select")
		return 0
	end
	
	return 2
end
 
local function DropTargetedTech(techId)
	
	local player = Client.GetLocalPlayer()
	
	if(not player:isa("Commander")) then
		return
	end

	if((techId == kTechId.AmmoPack or techId == kTechId.MedPack)) then
		local selectProgress = CheckSelectedCommandStructure()
		
		if(selectProgress == 0)then
			Shared.Message("CC needs tobe selected to drop health/ammo")
		end
		
		--we selected the cc this key press we have to wait for the server to register our selection before we can send the action
		if(selectProgress < 2 ) then
			return
		end
	end

	local x,y = Client.GetCursorPos()
	x = x*Client.GetScreenWidth()
	y = y*Client.GetScreenHeight()
	
	local normalizedPickRay = CreatePickRay(player, x, y)
    
   player:SendTargetedAction(techId, normalizedPickRay)
end



KeybindMapper:LinkBindToFunction("DropAmmo", function() DropTargetedTech(kTechId.AmmoPack) end) 
KeybindMapper:LinkBindToFunction("DropHealth", function() DropTargetedTech(kTechId.MedPack) end)  