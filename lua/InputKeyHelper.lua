
InputKeyHelper = {
	ReverseLookup = {},
	LowerCaseKeyList = {},
}

InputKeyHelper.KeyList = {
	"Escape",
	"Num1",
	"Num2",
	"Num3",
	"Num4",
	"Num5",
	"Num6",
	"Num7",
	"Num8",
	"Num9",
	"Num0",
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
	"NumPadSubtract",
	"NumPad4",
	"NumPad5",
	"NumPad6",
	"NumPadAdd",
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
	"NumPadPeriod",
	"NumPadDivide",
	"NumPadMultiply",
	"RightControl",
	"PrintScreen",
	"RightAlt",
	"Pause",
	"Break",
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
	"Clear",
	"Less",
	"Help",
	"MouseX",
	"MouseY",
	"MouseZ",
	"MouseButton0",
	"MouseButton1",
	"MouseButton2",
	"MouseButton3",
	"MouseButton4",
	"MouseButton5",
	"MouseButton6",
	"MouseButton7",
	"JoystickX",
	"JoystickY",
	"JoystickZ",
	"JoystickRotationX",
	"JoystickRotationY",
	"JoystickRotationZ",
	"JoystickSlider0",
	"JoystickSlider1",
	"JoystickButton0",
	"JoystickButton1",
	"JoystickButton2",
	"JoystickButton3",
	"JoystickButton4",
	"JoystickButton5",
	"JoystickButton6",
	"JoystickButton7",
	"JoystickButton8",
	"JoystickButton9",
	"JoystickButton10",
	"JoystickPovN",
	"JoystickPovS",
	"JoystickPovE",
	"JoystickPovW"
}

function InputKeyHelper:KeyNameExists(keyName)
	--will handle more than InputKey later on
	return InputKey[keyName] ~= nil
end

function InputKeyHelper:BuildLowerNames()
	
	local lowerList = self.LowerCaseKeyList
	
	for i,keyname in ipairs(self.KeyList) do
		lowerList[keyname:lower()] = keyname
	end
end

function InputKeyHelper:FindAndCorrectKeyName(key)
	
	if(not next(self.LowerCaseKeyList)) then
		self:BuildLowerNames()
	end
	
	return (key and self.LowerCaseKeyList[key:lower()]) or false
end

function InputKeyHelper:ConvertToKeyName(inputkeyNumber)
	
	if(not self.KeyList[inputkeyNumber]) then
		error("InputKeyHelper:ConvertToKeyName no matching key with the number ".. (inputkeyNumber and tostring(inputkeyNumber)) or "nil")
	end

	return self.KeyList[inputkeyNumber]
end

MoveEnum = {
	"PrimaryAttack",
	"SecondaryAttack",
	"NextWeapon",
	"PrevWeapon",
	"Reload",
	"Use",
	"Jump",
	"Crouch",
	"MovementModifier",
	"Minimap",
	"Buy",
	"ToggleFlashlight",
	"Weapon1",
	"Weapon2",
	"Weapon3",
	"Weapon4",
	"Weapon5",
  
	"ScrollBackward",
	"ScrollRight",
	"ScrollLeft",
	"ScrollForward",
	"Exit",
	
	"Drop",
	"Taunt",
	"Scoreboard",
	
	"ToggleSayings1",
	"ToggleSayings2",

	"TeamChat",
	"TextChat",
}

InputBitToName = {}

for _,inputname in ipairs(MoveEnum) do
	InputBitToName[Move[inputname]] = inputname
end