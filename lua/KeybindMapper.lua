--[[
	Public Api

	void KeybindMapper:LinkBindToConsoleCmd(string bindname, string ConsoleCommandString [, string updown])
	
	--if the fuction name is not provided the name of the bindname is used as the function name
	void KeybindMapper:LinkBindToSelfFunction(bindname, selfobj, funcname [, string updown])
	
	
	void KeybindMapper:RegisterActionToBind(string bindname, table action)
	
	void KeybindMapper:ActivateKeybindGroup(string groupname)
	void KeybindMapper:DeactivateKeybindGroup(string groupname)
]]--

Script.Load("lua/BindingsShared.lua")
Script.Load("lua/Hooks.lua")
KeyBindInfo:Init()

local InputKeybinds = {
	NextWeapon = true,
	PrevWeapon = true,
	Reload = true,
	Use = true,
	Jump = true,
	Crouch = true,
	MovementModifier = true,
	Minimap = true,
	Buy = true,
	ToggleFlashlight = true,
	Weapon1 = true,
	Weapon2 = true,
	Weapon3 = true,
	Weapon4 = true,
	Weapon5 = true,

	ScrollBackward = true,
	ScrollRight = true,
	ScrollLeft = true,
	ScrollForward = true,
	Exit = true,
	
	Drop = true,
	Taunt = true,
	Scoreboard = true,
	
	ToggleSayings1 = true,
	ToggleSayings2 = true,

	TeamChat = true,
	TextChat = true,
	PrimaryAttack = "PrimaryFire",
	SecondaryAttack = "SecondaryFire",
}

local MovementKeybinds = {
	MoveForward = {"z", 1, "MoveForward"},
	MoveBackward = {"z", -1, "MoveBackward"},
	MoveLeft = {"x", 1, "MoveLeft"},
	MoveRight = {"x", -1, "MoveRight"},
}

local InputBitToName = {}

for _,inputname in ipairs(InputEnum) do
	InputBitToName[Move[inputname]] = inputname
end

KeybindMapper = {
	Keybinds = {}, 
	MovementVector = Vector(0,0,0), 
	--InputMovementKeyMappings = {},
	--InputKeybindMappings = {},
	InputBitActions = {},
	MovmentVectorActions = {},
	KeybindActions = {},
	MoveInputBitFlags = 0,
	FilteredKeys = {},
	
	ChatOpen = false,
	InGameMenuOpen = false,
	ConsoleOpen = false,
	
	CtlDown = false,
	ShiftDown = false,
	AltDown = false,
	OverrideGroups = {},
	
-- change this to true if you want all keybinds tobe ignored when the console is open
-- this is disabled by default because there issues with dectecting when the console is open
	IgnoreConsoleState = true,
	
}

function KeybindMapper:Init()
	
	if(not self.Loaded) then
		self.fp = Client.CreateFlashPlayer()
		Client.AddFlashPlayerToDisplay(self.fp)

		self.fp:Load("ui/input.swf")
		self.fp:SetBackgroundOpacity(0)
		
		self:SetupMoveVectorAndInputBitActions()
		self:RefreshInputKeybinds()
		
		self.Loaded = true
	end
end

Event.Hook("MapPostLoad", function() 
	KeybindMapper:Init()
end )

function KeybindMapper:FullResetState()
	
	Shared.Message("Input State Reset")
	
	if(self.fp) then
		Client.DestroyFlashPlayer(self.fp)
	end
	
	self.fp = Client.CreateFlashPlayer()
	Client.AddFlashPlayerToDisplay(self.fp)

	self.fp:Load("ui/input.swf")
	self.fp:SetBackgroundOpacity(0)
	
	self.Keybinds = {}
	self.MovementVector = Vector(0,0,0)
	self.MoveInputBitFlags = 0

	self.ChatOpen = false
	self.InGameMenuOpen = false
	self.ConsoleOpen = false
	
	self.CtlDown = false
	self.ShiftDown = false
	self.AltDown = false
	self.OverrideGroups = {}
	
	self:RefreshInputKeybinds()
end

Event.Hook("Console_resetinput", function() KeybindMapper:FullResetState() end)

function KeybindMapper:RefreshInputKeybinds()

	self.MovementVector = Vector(0,0,0)
	self.MoveInputBitFlags = 0

	self.Keybinds = {}

	for key,bindname in pairs(KeyBindInfo:GetGlobalBoundKeys() ) do
		local action = self.KeybindActions[bindname]

		if(action) then
			self.Keybinds[key] = action
		end
	end

	self.ConsoleKey = KeyBindInfo:GetBoundKey("ToggleConsole") or "Grave"
	
	if(#self.OverrideGroups ~= 0) then
		local old = self.OverrideGroups
		self.OverrideGroups = {}
		
		for _,group in ipairs(old) do
			self:ActivateKeybindGroup(group.GroupName)
		end
	else
		self.OverrideGroups = {}
	end
end

function KeybindMapper:SetupMoveVectorAndInputBitActions()
		
	for bitname,bindname in pairs(InputKeybinds) do
		if(bindname == true) then
			bindname = bitname
		end

		local action = KeybindMapper.CreateActionHelper(true, false, self,  Move[bitname])
		 action.InputBit = bitname
		 action.OnDown = self.HandleInputBit
		 action.OnUp = self.HandleInputBit
		 
		 self.InputBitActions[Move[bitname]] = action
		 self:RegisterActionToBind(bindname, action)
	end

	for bindname,movdir in pairs(MovementKeybinds) do
		local action = KeybindMapper.CreateActionHelper(true, false, self,  movdir)
		 	action.MovementVector = movdir
		 	action.OnDown = self.HandleMovmentVector
		 	action.OnUp = self.HandleMovmentVector
		 self.MovmentVectorActions[bindname] = action
		 self:RegisterActionToBind(bindname, action)
	end
	
end

function KeybindMapper.CreateActionHelper(passKeyDown, passKey, ...)

	local action = {}
	 action.args = {...}
	local argIndex = #action.args+1

		if(passKeyDown) then
			action.KeyDownArgIndex = argIndex
			argIndex = argIndex+1
		end
		
		if(passKey) then
			action.KeyArgIndex = argIndex
			argIndex = argIndex+1
		end
	
	return action
end

function KeybindMapper:CheckKeybindChanges()
	local changedKeybindsString = Main.GetOptionString("Keybinds/Changed", "")

	if(changedKeybindsString ~= "") then
--		local changedKeybinds = Explode(changedKeybindsString, "@")

		KeyBindInfo:ReloadKeyBindInfo()
		self:RefreshInputKeybinds()

		Main.SetOptionString("Keybinds/Changed", "")
	end
end

function KeybindMapper:ResetMovment()
	self.MovementVector = Vector(0,0,0)
end

function KeybindMapper:InGameMenuOpened()
	self:ResetMovment()
	self.MoveInputBitFlags = 0
	self.InGameMenuOpen = true
	self.fp:SetGlobal("IsInputTrackingDisabled", 1)
end

function KeybindMapper:InGameMenuClosed()
	--PrintDebug("KeybindMapper:InGameMenuClosed ", Main.GetOptionString("Keybinds/Changed", ""))
	
	self.InGameMenuOpen = false
	self:CheckKeybindChanges()
end

function KeybindMapper:ChatOpened()
	self.ChatOpen = true

	--clear chat bits since we will miss the KeyUp event because we will have disabled our input tracking
	self.MoveInputBitFlags = bit.band(self.MoveInputBitFlags, bit.bnot(bit.bor(Move.TeamChat, Move.TextChat)))

	self.fp:SetGlobal("IsInputTrackingDisabled", 1)
end

function KeybindMapper:ChatClosed()
	self.ChatOpen = false
	self.fp:SetGlobal("IsInputTrackingDisabled", 0)
end

function KeybindMapper:OnCommander(CommanderSelf)
	self:ActivateKeybindGroup("CommanderShared")
	
	if(CommanderSelf:isa("MarineCommander")) then
		self:ActivateKeybindGroup("MarineCommander")
	else
		self:ActivateKeybindGroup("AlienCommander")
	end
end

function KeybindMapper:OnUnCommander()
	self:DeactivateKeybindGroup("CommanderShared")
	self:DeactivateKeybindGroup("MarineCommander")
	self:DeactivateKeybindGroup("AlienCommander")
end

function KeybindMapper:ActivateKeybindGroup(groupname)
	
	for i,group in ipairs(self.OverrideGroups) do
		if(group.GroupName == groupname) then
			error("KeybindMapper:ActivateKeybindGroup group \""..groupname.."\" is already active")
		end
	end
	
	local boundkeys = KeyBindInfo:GetGroupBoundKeys(groupname)

	table.insert(self.OverrideGroups, {GroupName = groupname, Keys = boundkeys})
	
	for key,bindname in pairs(boundkeys) do
		local action = self.KeybindActions[bindname]
		
		if(action) then
			self.Keybinds[key] = action
		end
	end
end

function KeybindMapper:DeactivateKeybindGroup(groupname)
	
	local index
	
	for i,group in ipairs(self.OverrideGroups) do
		if(group.GroupName == groupname) then
			 index = i
			break
		end
	end

	--just silently return if the group is not active
	if(not index) then
		return
	end
	
	local boundkeys = self.OverrideGroups[index]
	table.remove(self.OverrideGroups, index)

	for key,bindname in pairs(boundkeys.Keys) do
		local action = self.KeybindActions[bindname]
		
		--check to make sure there was a action for our bind and that another OverrideGroup hasn't replaced our key
		if(action and self.Keybinds[key] == action) then
			local lastFound

			--try to find the newest OverrideGroup with this key listed
			for _,group in ipairs(self.OverrideGroups) do
				local bind = group.Keys[key]
				if(bind and self.KeybindActions[bind]) then
					 lastFound = self.KeybindActions[bind]
				end
			end
			

			if(lastFound) then
				self.Keybinds[key] = lastFound
			else
				--non of OverrideGroups had the key so just reset to the global bind if one is set to this key	
				local bindname = KeyBindInfo:GetBindSetToKey(key)
				
				if(bindname ~= nil and self.KeybindActions[bindname]) then
					self.Keybinds[key] = self.KeybindActions[bindname]
				else
					self.Keybinds[key] = nil
				end
			end
		end
	end
end

function KeybindMapper:OnKeyDown(key)

	--The Engines Console input event handler should be filtering all key input events when the console is open
	--so they don't get sent to other input handlers but doesn't for some dumb reason
	if(not self.IgnoreConsoleState and key == self.ConsoleKey) then
			self.ConsoleOpen = not self.ConsoleOpen			
		return
	end
	
	if(not self.IgnoreConsoleState and self.ConsoleOpen) then
		return
	end

	if(key == "LeftControl" or key == "RightControl") then
		self.CtlDown = true
	end
	
	if(key == "LeftShift" or key == "RightShift") then
		self.ShiftDown = true
	end
	
	if(key == "LeftAlt" or key == "RightAlt") then
		self.AltDown = false
	end

	if(self.FilteredKeys[key]) then
		for _,action in ipairs(self.FilteredKeys[key]) do
			--if a filter action returns true we don't let anything else process this key event and just return
			if(self:ActivateAction(action, key, true)) then
				return
			end
		end
	end

	local action = self.Keybinds[key]

	if(action) then
		self:ActivateAction(action, key, true)
	end
end

function KeybindMapper:OnKeyUp(key)

	if(key == "LeftControl" or key == "RightControl") then
		self.CtlDown = true
	end
	
	if(key == "LeftShift" or key == "RightShift") then
		self.ShiftDown = true
	end
	
	if(key == "LeftAlt" or key == "RightAlt") then
		self.AltDown = false
	end

	local action = self.Keybinds[key]

	if(action) then
		self:ActivateAction(action, key, false)
	end
end

function KeybindMapper:ActivateAction(action, key, down)
	
	local func = action.OnDown
	local result = false

	if(not down) then
		func = action.OnUp
	end
	
	if(action.KeyDownArgIndex) then
		action.args[action.KeyDownArgIndex] = down
	end

	if(action.KeyArgIndex) then
		action.args[action.KeyArgIndex] = key
	end

	if(func) then
		if(action.args) then
			result = func(unpack(action.args))
		else
			result = func()
		end
	end

	return result
end

function KeybindMapper:HandleInputBit(inputbit, keydown)

	if(keydown) then
		self.MoveInputBitFlags = bit.bor(self.MoveInputBitFlags, inputbit)
	else
		if(bit.band(self.MoveInputBitFlags, inputbit) ~= 0) then
			self.MoveInputBitFlags = bit.bxor(self.MoveInputBitFlags, inputbit)
		end
	end
end

function KeybindMapper:HandleMovmentVector(movedir, keydown)

	if(keydown) then
		--don't do anything if the the opposite movment key is already being held down i.e. our movement vector field is non zero
		if(self.MovementVector[movedir[1]] == 0) then
			self.MovementVector[movedir[1]] = movedir[2] 
		end
	else
		--don't do anything if the the opposite movment key is already being held down i.e. our movement vector field is not equal to our direction number
		if(self.MovementVector[movedir[1]] == movedir[2]) then
			self.MovementVector[movedir[1]] = 0
		end
	end
end

function KeybindMapper:LinkBindToFunction(bindname, func, updown, ...)
	
	local keybindEntry = {
		BindName = bindname,
		Function = true,
		args = {...},
	}
	
	if(updown == nil or updown == "down") then
		keybindEntry.OnDown = func
	elseif(updown == "up") then
		keybindEntry.OnUp = func
	end
	
	self:RegisterActionToBind(bindname, keybindEntry)
end

--if the fuction name is not provided the name of the bindname is used as the function name
function KeybindMapper:LinkBindToSelfFunction(bindname, selfobj, funcname, updown)
	
	if(funcname == nil) then
		funcname = bindname
	end
	
	local keybindAction = {
		BindName = bindname, 
		SelfFunction = funcname,
		args = {selfobj},
	}
	
	if(updown == nil or updown == "down") then
		keybindAction.OnDown = selfobj[funcname]
	elseif(updown == "up") then
		keybindAction.OnUp = selfobj[funcname]
	end

	self:RegisterActionToBind(bindname, keybindAction)
end

function KeybindMapper:LinkBindToConsoleCmd(bindname, commandstring, updown)

	local keybindAction = {
		ConsoleCommand = commandstring,
		BindName = bindname,
	}

	local func = function() Shared.ConsoleCommand(commandstring) end

	if(updown == nil or updown == "down") then
		keybindAction.OnDown = func
	elseif(updown == "up") then
		keybindAction.OnUp = func
	end

	self:RegisterActionToBind(bindname, keybindAction)
end

function KeybindMapper:RegisterActionToBind(bindname, keybindaction)
	
	if(not keybindaction) then
		error("RegisterActionToBind: was passed a nil action")
	end

	self.KeybindActions[bindname] = keybindaction

	--map the key that the bindname is set to if were loaded already
	if(self.Loaded) then
		local key = KeyBindInfo:GetBoundKey(bindname)

		if(key and key ~= "") then
			self.Keybinds[key] = keybindaction
		end
	end
end

function KeybindMapper:GetDescriptionForBoundKey(key)

	local action = self.Keybinds[key]

	if(action.MovementVector) then
		return "Movement Keybind:"..action.MovementVector[3]
	end

	if(action.InputBit) then
		return "Move.input bit Keybind:"..action.InputBit
	end
	
	local action = self.Keybinds[key]
	
	if(action) then
		if(action.ConsoleCommand) then
			if(action.BindName) then
				return string.format("Console command \"%s\" Assocated with bind \"%s\"", action.ConsoleCommand, action.BindName)
			elseif(action.UserCreatedBind) then
				
			end
		end
	end
	
end

function KeybindMapper:ClearKey(key)	
	self.Keybinds[key] = nil
end

function KeybindMapper:BindKeyToConsoleCommand(key, commandstring)
	
	local keybindAction = {
		ConsoleCommand = commandstring,
		UserCreatedBind = true,
	}

	local func = function() Shared.ConsoleCommand(commandstring) end

	if(updown == nil or updown == "down") then
		keybindAction.OnDown = func
	elseif(updown == "up") then
		keybindAction.OnUp = func
	end
	
	self.Keybinds[key] = keybindAction
end

function BindConsoleCommand(player, key, ...)
	
	local upperkey = key:upper()
	local RealKeyName = false
	
	for i,keyname in ipairs(InputKeyNames) do
		if(upperkey == keyname:upper()) then
				RealKeyName = keyname
			break
		end
	end

	if(RealKeyName) then
		KeybindMapper:ClearKey(RealKeyName)
		
		local command = table.concat({...}, " ")
		
		KeybindMapper:BindKeyToConsoleCommand(RealKeyName, command)
	else
		Shared.Message("bind:Unreconized key "..key)
	end
end

Event.Hook("Console_bind",  BindConsoleCommand)


--called by flash
function IsInputTrackingDisabled()

	if(KeybindMapper.InGameMenuOpen) then
		if(Main.GetOptionString("Keybinds/Changed", "") ~= "") then
			KeybindMapper:InGameMenuClosed()
		end
	end
	
	if(KeybindMapper.ChatOpen and not ChatUI_EnteringChatMessage()) then
		KeybindMapper:ChatClosed()
	end
	
	return KeybindMapper.InGameMenuOpen or KeybindMapper.ChatOpen
end

--called by flash
function OnKeyDown(key, code)
	KeybindMapper:OnKeyDown(key)
end

--called by flash
function OnKeyUp(key, code)
	KeybindMapper:OnKeyUp(key)
end


if(not KeybindMapper.IgnoreConsoleState) then
	Event.Hook("Console_km_rcs", function() KeybindMapper.ConsoleOpen = true end )
	KeybindMapper.ConsoleOpen = Main.GetOptionBoolean("ConsoleOpen", false)
	Script.AddShutdownFunction(function() 
		Main.SetOptionBoolean("ConsoleOpen", KeybindMapper.ConsoleOpen) 
		
		if(Main.GetOptionString("Keybinds/Changed", "") ~= "") then
			Main.SetOptionString("Keybinds/Changed", "")
		end
	end )
else
	Script.AddShutdownFunction(function() 
		if(Main.GetOptionString("Keybinds/Changed", "") ~= "") then
			Main.SetOptionString("Keybinds/Changed", "")
		end
	end)
end

