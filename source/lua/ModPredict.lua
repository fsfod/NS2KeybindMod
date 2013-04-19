
Script.Load("lua/ModShared.lua")
Script.Load("lua/MapEntityLoader.lua")

local function OnMapLoadEntity(className, groupName, values)
    LoadMapEntity(className, groupName, values)
end
Event.Hook("MapLoadEntity", OnMapLoadEntity)