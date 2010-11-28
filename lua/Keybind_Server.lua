Script.Load("lua/JetpackMod.lua")
Script.Load("lua/Server.lua")

Event.Hook("MapPostLoad", function()
Shared.ConsoleCommand("cheats 1")
end)