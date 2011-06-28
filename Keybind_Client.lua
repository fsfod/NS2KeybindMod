Script.Load("lua/ClassHooker.lua")

Script.Load("lua/InputKeyHelper.lua")
Script.Load("lua/KeyBindInfo.lua")
Script.Load("lua/KeybindMapper.lua")
Script.Load("lua/Hooks.lua")

KeyBindInfo:Init()
KeybindMapper:Init()

Script.Load("lua/KeybindSystemConsoleCommands.lua")
Script.Load("lua/KeybindImplementations.lua")
Script.Load("lua/Client.lua")
ClassHooker:OnLuaFullyLoaded()