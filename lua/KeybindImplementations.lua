
Event.Hook("MapPostLoad", function()
	KeybindMapper:LinkBindToFunction("OpenFeedback",  ShowFeedbackPage)
end)


KeybindMapper:LinkBindToConsoleCmd("JoinMarines", "j1")
KeybindMapper:LinkBindToConsoleCmd("JoinAliens", "j2")
KeybindMapper:LinkBindToConsoleCmd("ReadyRoom", "rr")

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
	
	local selectedents = player:GetSelection()
	
	if(not selectedents[1] or not Shared.GetEntity(selectedents[1]) or not Shared.GetEntity(selectedents[1]):isa("CommandStructure")) then
		local entId = FindNearestEntityId("CommandStructure", player:GetOrigin())
    local commandStructure = Shared.GetEntity(entId)
    
    if commandStructure ~= nil then
    	--only trace ray click selection is syned to the server it seems atm :(
			--player:ClearSelection()
			--player:SetSelection(entId)
			return false
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