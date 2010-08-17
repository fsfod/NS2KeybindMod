
Event.Hook("MapPostLoad", function()
	KeybindMapper:LinkBindToFunction("OpenFeedback",  ShowFeedbackPage)
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

function CheckSelectedCommandStructure()
	local player = Client.GetLocalPlayer()
	
	local selectedEnts = player:GetSelection()
	
	for k,entInfo in pairs(selectedEnts) do
		local entity = Shared.GetEntity(entInfo[1])

		if(entity and entity:isa("CommandStructure")) then
			
		end
	end
	
	if(true) then
		return
	end
	
	if(#selectedents ~=  or not Shared.GetEntity(selectedents[1]) or not Shared.GetEntity(selectedents[1]):isa("CommandStructure")) then
    
    if player:SelectHotkeyGroup(1) then
			return true
		else
			Shared.Message("Failed to find CommandStructure to select")
		 return false
		end
	end
	
	return true
end
 
local function DropTargetedTech(techId)
	
	local player = Client.GetLocalPlayer()
	
	if(not player:isa("Commander")) then
		return
	end

	if((techId == kTechId.AmmoPack or techId == kTechId.MedPack) and not CheckSelectedCommandStructure()) then
			Shared.Message("CC needs tobe selected to drop health/ammo")
		return
	end

	local x,y = Client.GetCursorPos()
	x = x*Client.GetScreenWidth()
	y = y*Client.GetScreenHeight()
	
	local normalizedPickRay = CreatePickRay(player, x, y)
    
   player:SendTargetedAction(techId, normalizedPickRay)
end



KeybindMapper:LinkBindToFunction("DropAmmo", function() DropTargetedTech(kTechId.AmmoPack) end) 
KeybindMapper:LinkBindToFunction("DropHealth", function() DropTargetedTech(kTechId.MedPack) end)  