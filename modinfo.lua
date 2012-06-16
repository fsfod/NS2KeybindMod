author = "fsfod"
EngineBuild = 209
ModTableName = "KeybindMod"
MainScript = "KeybindMod.lua"
ValidVM = "main_client"

ScriptList = {
  "KeyBindInfo.lua",
  "KeybindMapper.lua",
  "Hooks.lua",
  "KeybindSystemConsoleCommands.lua",
  "KeybindImplementations.lua"
}

Dependencies = {
  "BaseUIControls"
}

SavedVaribles = {
  "Commander_Shift",
  "Commander_Ctl",
  "Keybinds",
  "ConsoleCmdBinds",
}

