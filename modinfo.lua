author = "fsfod"
EngineBuild = 162
ModTableName = "KeybindMapper"

ScriptList = {
  "lua/InputKeyHelper.lua",
  "lua/KeyBindInfo.lua",
  "lua/KeybindMapper.lua",
  "lua/Hooks.lua",
  "lua/KeybindSystemConsoleCommands.lua",
  "lua/KeybindImplementations.lua"
}

ScriptOverrides= {
	["lua/BindingsDialog.lua"] = true 
}

ValidVM = "client"