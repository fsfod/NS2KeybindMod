// ======= Copyright © 2003-2010, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\PlayerSpawn.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Custom_Shared.lua")

if(Client) then
	Script.Load("lua/Custom_Client.lua")
else
	Script.Load("lua/Custom_Server.lua")
end

Script.Load("lua/BaseSpawn.lua")

class 'PlayerSpawn' (BaseSpawn)

PlayerSpawn.kMapName = "player_start"

Shared.LinkClassToMap("PlayerSpawn", PlayerSpawn.kMapName, {} )
