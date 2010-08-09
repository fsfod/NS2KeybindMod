
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
}

function BindConsoleCommand(player, key, ...)
	
	if(not key or select('#', ...) == 0) then
		Shared.Message("bind: useage \"bind keyname consolecommand\"")
	 return
	end

	local upperkey = key:upper()
	local RealKeyName = false

	for i,keyname in ipairs(InputKeyNames) do
		if(upperkey == keyname:upper()) then
				RealKeyName = keyname
			break
		end
	end

	if(RealKeyName) then
		local command = table.concat({...}, " ")

		KeyBindInfo:SetConsoleCmdBind(RealKeyName, command)
		KeybindMapper:SetKeyToConsoleCommand(RealKeyName, command)

		Main.SetOptionString("Keybinds/InGameChanged", "1")
	else
		Shared.Message("bind: Unreconized key "..key)
	end
end

Event.Hook("Console_bind",  BindConsoleCommand)


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