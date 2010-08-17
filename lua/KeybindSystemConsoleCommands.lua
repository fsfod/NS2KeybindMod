
InputKeyNames = {
	"Escape",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"0",
	"Minus",
	"Equals",
	"Back",
	"Tab",
	"Q",
	"W",
	"E",
	"R",
	"T",
	"Y",
	"U",
	"I",
	"O",
	"P",
	"LeftBracket",
	"RightBracket",
	"Return",
	"LeftControl",
	"A",
	"S",
	"D",
	"F",
	"G",
	"H",
	"J",
	"K",
	"L",
	"Semicolon",
	"Apostrophe",
	"Grave",
	"LeftShift",
	"Backslash",
	"Z",
	"X",
	"C",
	"V",
	"B",
	"N",
	"M",
	"Comma",
	"Period",
	"Slash",
	"RightShift",
	"Multiply",
	"LeftAlt",
	"Space",
	"Capital",
	"F1",
	"F2",
	"F3",
	"F4",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"F10",
	"NumLock",
	"Scroll",
	"NumPad7",
	"NumPad8",
	"NumPad9",
	"Subtract",
	"NumPad4",
	"NumPad5",
	"NumPad6",
	"Add",
	"NumPad1",
	"NumPad2",
	"NumPad3",
	"NumPad0",
	"Decimal",
	"F11",
	"F12",
	"F13",
	"F14",
	"F15",
	"NumPadEquals",
	"NumPadEnter",
	"RightControl",
	"Divide",
	"PrintScreen",
	"RightAlt",
	"Pause",
	"Home",
	"Up",
	"PageUp",
	"Left",
	"Right",
	"End",
	"Down",
	"PageDown",
	"Insert",
	"Delete",
	"LeftWindows",
	"RightWindows",
	"AppMenu",
	"MouseX",
	"MouseY",
	"MouseZ", --Scroll Wheel
	"MouseButton0", 
	"MouseButton1",
	"MouseButton2",
	"MouseButton3",
	"MouseButton4",
	"MouseButton5",
	"MouseButton6",
	"MouseButton7",
}

local function FindRealKeyName(key)
	local upperkey = key:upper()
	local RealKeyName = false

	for i,keyname in ipairs(InputKeyNames) do
		if(upperkey == keyname:upper()) then
				RealKeyName = keyname
			break
		end
	end
	
	return RealKeyName
end

function Bind_ConsoleCommand(player, key, bindname)
	
	if(not key or not bindname) then
		Shared.Message("bind: useage \"bind keyname bindname\"")
	 return
	end

	local realKeyName = FindRealKeyName(key)
	
	if(not realKeyName) then
			Shared.Message("bind: Unreconized key "..key)
		return 
	end
	
	local realBindName = KeyBindInfo:FindBind(bindname)
	
	if(not realBindName) then
			Shared.Message("bind: Unreconized bindname "..bindname)
		return 
	end
	
	if(KeyBindInfo:IsBindOverrider(realBindName)) then
		local bindgroup = KeyBindInfo:GetBindsGroup(realBindName)
		local conflict = KeyBindInfo:GetBoundKeyGroup(RealKeyName, bindgroup)

		if(conflict) then
			Shared.Message(string.format("bind: Conflicting bind \"%s\" was unbound in override group %s", conflict, bindgroup))
		end
	elseif(KeyBindInfo:IsKeyBound(RealKeyName)) then
		if(KeyBindInfo:IsKeyBoundToConsoleCmd(RealKeyName)) then
			Shared.Message(string.format("bind: Conflicting ConsoleCmd bind \"%s\" was unbound", KeyBindInfo:GetBoundConsoleCmd(RealKeyName)))
		else
			Shared.Message(string.format("bind: Conflicting bind \"%s\" was unbound", KeyBindInfo:GetBindSetToKey(RealKeyName)))
		end
	end

	KeybindMapper:ChangeKeybind(realBindName, realKeyName)
	Main.SetOptionString("Keybinds/InGameChanged", "1")
end

Event.Hook("Console_bind",  Bind_ConsoleCommand)

function BindC_ConsoleCommand(player, key, ...)
	
	if(not key or select('#', ...) == 0) then
		Shared.Message("bindc: useage \"bindc keyname consolecommand\"")
	 return
	end

	local RealKeyName = FindRealKeyName(key)

	if(not RealKeyName) then
			Shared.Message("bindc: Unreconized key "..key)
		return 
	end

	local command = table.concat({...}, " ")
	local oldbind

	if(KeyBindInfo:IsKeyBound(RealKeyName)) then
		if(not KeyBindInfo:IsKeyBoundToConsoleCmd(RealKeyName)) then
			oldbind = KeyBindInfo:GetBindSetToKey(RealKeyName)
			Shared.Message(string.format("bindc: Conflicting bind \"%s\" was unbound", oldbind))
		else
			Shared.Message(string.format("bindc: Conflicting ConsoleCmd bind \"%s\" was unbound", KeyBindInfo:GetBoundConsoleCmd(RealKeyName)))
		end
	end

	KeybindMapper:BindConsoleCommand(RealKeyName, command)

	Main.SetOptionString("Keybinds/InGameChanged", "1")
end

Event.Hook("Console_bindc",  BindC_ConsoleCommand)


Event.Hook("Console_resetinput", function() KeybindMapper:FullResetState() end)

Event.Hook("Console_resetbinds", function() 
	KeyBindInfo:ResetKeybinds()
	Main.SetOptionString("Keybinds/InGameChanged", "1")
	Shared.Message("Keybinds reset")
end)



function DumpBinds()
	for key,bind in pairs(KeyBindInfo:GetGlobalBoundKeys()) do
		Shared.Message(key.." = "..bind)
	end
end

Event.Hook("Console_dumpbinds", DumpBinds)
