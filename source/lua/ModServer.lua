
Script.Load("lua/ModShared.lua")

--Event.Hook("MapPreLoad", OnMapPreLoad)
--Event.Hook("MapPostLoad", OnMapPostLoad)
--Event.Hook("MapLoadEntity", OnMapLoadEntity)

local function OnCanPlayerHearPlayer(listener, speaker)
    return true
end
Event.Hook("CanPlayerHearPlayer", OnCanPlayerHearPlayer)

local function OnClientConnect(client)

    local player = Server.CreateEntity(Player.kMapName)
    
    local userId = tonumber(client:GetUserId())
    Shared.Message(string.format("Client Authed. Steam ID: %s", userId))
    
    player:SetControllerClient(client)
    
    return player
    
end
Event.Hook("ClientConnect", OnClientConnect)

local function OnClientDisconnect(client)

end
Event.Hook("ClientDisconnect", OnClientDisconnect)