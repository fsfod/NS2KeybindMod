--[[
	Public Api

	void SetKeyToConsoleCmd(string bindname, string ConsoleCommandString)
	
	--if the fuction name is not provided the name of the bindname is used as the function name
	void LinkBindToSelfFunction(bindname, selfobj, funcname [, string updown])
	

	void RegisterActionToBind(string bindname, table action)
	
	void ActivateKeybindGroup(string groupname)
	void DeactivateKeybindGroup(string groupname)
]]--

KeybindMapper = {
	Keybinds = {},
	ConsoleCmdKeys = {},
	FilteredKeys = {},

	InputBitActions = {},
	MovmentVectorActions = {},
	KeybindActions = {},

	MovementVector = Vector(0,0,0),
	MoveInputBitFlags = 0,
	RunningActions = {},
	EatKeyUp = {},

	IsShutDown = true,

	ChatOpen = false,
	InGameMenuOpen = false,
	ConsoleOpen = false,

	CtlDown = false,
	ShiftDown = false,
	AltDown = false,
	OverrideGroups = {},
	OverrideGroupLookup = {},
	
-- change this to true if you want all keybinds tobe ignored when the console is open
-- this is disabled by default because there issues with dectecting when the console is open
	IgnoreConsoleState = true,
}

--Script.Load("lua/BindingsShared.lua")
Script.Load("lua/Hooks.lua")

local HotkeyPassThrough = {
	Space = true,
	ESC = true,
	A = true,
	B = true,
	C = true,
	D = true,
	E = true,
	F = true,
	G = true,
	H = true,
	I = true,
	J = true,
	K = true,
	L = true,
	M = true,
	N = true,
	O = true,
	P = true,
	Q = true,
	R = true,
	S = true,
	T = true,
	U = true,
	V = true,
	W = true,
	X = true,
	Y = true,
	Z = true,
}


local MovementKeybinds = {
	MoveForward = {"z", 1, "MoveForward"},
	MoveBackward = {"z", -1, "MoveBackward"},
	MoveLeft = {"x", 1, "MoveLeft"},
	MoveRight = {"x", -1, "MoveRight"},
}


function KeybindMapper:Init()

	if(not self.Loaded) then
		self:SetupMoveVectorAndInputBitActions()	
		self:SetupHooks()
		self.Loaded = true
	end
end

Event.Hook("MapPostLoad", function() 
	KeybindMapper:Startup()
end )

Event.Hook("ClientDisconnected", function() 
	KeybindMapper:ShutDown()
end )

function KeybindMapper:Startup()
	
	if(not self.IsShutDown) then
		return
	end
	
	self:Init()
	
	self.IsShutDown = false
	self:RefreshInputKeybinds()
end

function KeybindMapper:ShutDown()

	self.IsShutDown = true

	self:ResetInputStateData("ShutDown")

	self.ChatOpen = false
	self.InGameMenuOpen = false
	self.BuyMenuOpen = false
	self.ConsoleOpen = false

	self.CurrentPlayerClass = nil
	self.IsCommander = false

	self.OverrideGroups = {}

	self.ConsoleCmdKeys = {}
	self.Keybinds = {}
end

function KeybindMapper:FullResetState()
	self:ShutDown()
	self:Startup()
	Shared.Message("Input State Reset")
end

function KeybindMapper:ResetInputStateData(caller)
	--Shared.Message("ResetInputStateData "..caller)
	self.MovementVector = Vector(0,0,0)
	self.MoveInputBitFlags = 0
	self.RunningActions = {}
	self.EatKeyUp = {}
	
	self.KeyStillDown = {}
	
	self.CtlDown = false
	self.ShiftDown = false
	self.AltDown = false
	self.HotKey = nil
end

function KeybindMapper:RefreshInputKeybinds()

	self:ResetInputStateData("RefreshInputKeybinds")

	self.Keybinds = {}

	self.ConsoleKey = KeyBindInfo:GetBoundKey("ToggleConsole") or "Grave"

	local oldConsoleCmds = self.ConsoleCmdKeys

	self.ConsoleCmdKeys = {}
	
	for key,cmd in pairs(KeyBindInfo:GetConsoleCmdBoundKeys()) do
		local old = oldConsoleCmds[key]
		
		--just reuse our old Command action if the command string hasn't changed
		if(old and old.ConsoleCommand == cmd) then
			self.ConsoleCmdKeys[key] = cmd
		else
			self:SetKeyToConsoleCommand(key, cmd)
		end
	end
	
	self:ReloadKeybindGroups()
end

function KeybindMapper:ReloadKeybindGroups()
	if(#self.OverrideGroups ~= 0) then
		local old = self.OverrideGroups
		self.OverrideGroups = {}
		self.OverrideGroupLookup = {}

		for _,group in ipairs(old) do
			self:ActivateKeybindGroup(group.GroupName)
		end
	end
end


function KeybindMapper:AddPulsedInputBitAction(bitname)
	
	local Action = {
		InputBit = bitname,
		OnDown = function()
			KeybindMapper:HandleInputBit(Move[bitname], true)
			
			self:AddTickAction(function(state)
		 			if(state.TickCount == 2) then
		 					KeybindMapper:HandleInputBit(Move[bitname], false)
						return true
					end
				end, nil, bitname, "NoReplace")
		end,
	}
	
	self.InputBitActions[bitname] = Action
	self:RegisterActionToBind(bitname, Action)
	
end

local SkipMoveBits = {
	ToggleFlashlight = true,
	TextChat = true,
	TeamChat = true,
	MoveForward = true,
	MoveBackward = true,
	MoveLeft = true,
	MoveRight = true,
}

local PulsedInputBits = {
	ToggleFlashlight = true,
	Buy = true,
}

function KeybindMapper:SetupMoveVectorAndInputBitActions()
		
	for _,bitname in ipairs(MoveEnum) do
		if(not SkipMoveBits[bitname] and not PulsedInputBits[bitname]) then
		 local action = KeybindMapper.CreateActionHelper(true, false, self,  Move[bitname])
		 	action.InputBit = bitname
			action.OnDown = self.HandleInputBit
		 	action.OnUp = self.HandleInputBit
		 
		 	self.InputBitActions[Move[bitname]] = action
		 	self:RegisterActionToBind(bitname, action)
		end
	end

	for bitname,_ in pairs(PulsedInputBits) do
		self:AddPulsedInputBitAction(bitname)
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


function KeybindMapper:OnKeybindsChanged(changes)
	
--	local notSingle = next(changes) and next(changes, next(changes))
	
	self:ReloadKeybindGroups()
	self:RefreshInputKeybinds()
end

KeyBindInfo:RegisterForKeyBindChanges(KeybindMapper, "OnKeybindsChanged")

function KeybindMapper:InternalSetKeyAction(key, action)
	self.Keybinds[key] = action
end

function KeybindMapper:BuyMenuOpened()
	self.BuyMenuOpen = true
end

function KeybindMapper:BuyMenuClosed()
	self.BuyMenuOpen = false
end

function KeybindMapper:InGameMenuOpened()
	
	if(self.IsShutDown) then
		return
	end
	
	self:ResetInputStateData("InGameMenuOpened")
	self.InGameMenuOpen = true
end

function KeybindMapper:InGameMenuClosed(keybindsChanged)

	if(self.IsShutDown) then
		return
	end

	self.InGameMenuOpen = false
end

function KeybindMapper:ChatOpened()
	self.ChatOpen = true

	--clear chat bits since we will miss the KeyUp event because we will have disabled our input tracking
	self:ResetInputStateData("ChatOpened")
end

function KeybindMapper:ChatClosed()
	self.ChatOpen = false
end

function KeybindMapper:OnCommander(CommanderSelf)
	
	if(self.IsShutDown) then
		return
	end
	
	self.IsCommander = true
	self:ActivateKeybindGroup("CommanderShared")
	
	if(CommanderSelf:isa("MarineCommander")) then
		self:ActivateKeybindGroup("MarineCommander")
	else
		self:ActivateKeybindGroup("AlienCommander")
	end
	
	self:ResetInputStateData("OnCommander")
end

function KeybindMapper:OnCommander2(CommanderSelf)
	Print("OnCommander2")
end

function KeybindMapper:OnUnCommander()
	
	if(self.IsShutDown) then
		return
	end
	
	self.IsCommander = false
	self:DeactivateKeybindGroup("CommanderShared")
	self:DeactivateKeybindGroup("MarineCommander")
	self:DeactivateKeybindGroup("AlienCommander")

	self:ResetInputStateData("OnUnCommander")
end

function KeybindMapper:PlayerClassChanged(newclass)
	
	local player = Client.GetLocalPlayer()
	
	local newclass = player and player:GetClassName()
	
	Print("PlayerClassChanged %s", newclass or "nil")
	
	
	if(self.IsCommander) then
		if(not player or not player:isa("Commander")) then
			self:OnUnCommander()
		end
	else
		
	end

	self.CurrentPlayerClass = newclass
end


function KeybindMapper:ActivateKeybindGroup(groupname)
	
	if(self.OverrideGroupLookup[groupname]) then
		error("KeybindMapper:ActivateKeybindGroup group \""..groupname.."\" is already active")
	end
	
	local boundkeys = KeyBindInfo:GetGroupBoundKeys(groupname)

	local group = {GroupName = groupname, Keys = boundkeys}

	self.OverrideGroupLookup[groupname] = group
	table.insert(self.OverrideGroups, group)
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

	table.remove(self.OverrideGroups, index)
	self.OverrideGroupLookup[groupname] = nil
end

local function IsValidHotkeyActive(key)
	local player = Client.GetLocalPlayer() 
	
	if(not player:isa("Commander")) then
		return false
	end
	
	local selected = player:GetSelection()

	if(#selected == 0) then
		return false
	end

	for index, techId in ipairs(player.menuTechButtons) do
   	if player.menuTechButtonsAllowed[index] then
     local hotkey = LookupTechData(techId, kTechDataHotkey)

      if hotkey ~= nil and key == hotkey then
        return index
      end
  	end
	end

	return false
end

-- favor simplicity 
function KeybindMapper:FindKeysAction(key)
	
	local i = #self.OverrideGroups
	
	while i ~= 0 do
		local bindname = self.OverrideGroups[i].Keys[key]
  	
		if(bindname and self.KeybindActions[bindname]) then
			return self.KeybindActions[bindname], self.OverrideGroups[i].GroupName
		end
		i = i-1
	end

	if(self.ConsoleCmdKeys[key]) then
		return self.ConsoleCmdKeys[key], false
	end

	if(self.Keybinds[key]) then
		return self.Keybinds[key], false
	end

	local BindOrCmd, IsBind = KeyBindInfo:GetKeyInfo(key)

	if(IsBind) then
		return self.KeybindActions[BindOrCmd], false 
	end
	
	return nil
end

function KeybindMapper:OnKeyDown(key)

	if(self.ChatOpen or self.InGameMenuOpen) then
		return false
	end

	--don't trigger any actions if the key being held down and were just getting key repeats for it
	if(self.KeyStillDown[key]) then
		return true
	end

	self.KeyStillDown[key] = true

	--The Engines Console input event handler should be filtering all key input events when the console is open
	--so they don't get sent to other input handlers but doesn't for some dumb reason
	if(key == self.ConsoleKey) then
			self.ConsoleOpen = not self.ConsoleOpen			
		return true
	end

	if(key == "LeftControl" or key == "RightControl") then
		self.CtlDown = true
	end
	
	if(key == "LeftShift" or key == "RightShift") then
		self.ShiftDown = true
	end
	
	if(key == "LeftAlt" or key == "RightAlt") then
		self.AltDown = true
	end

	if(self.FilteredKeys[key]) then
		for _,action in ipairs(self.FilteredKeys[key]) do
			--if a filter action returns true we don't let anything else process this key event and just return
			if(self:ActivateAction(action, key, true)) then
				return true
			end
		end
	end

	local action,overrideGroup = self:FindKeysAction(key)

	if(action) then
		if(not self.IsCommander) then
			 self:ActivateAction(action, key, true)
			return true
		else
	 		local commanderUseable = overrideGroup or action.UserConsoleCmdBind or KeyBindInfo.CommanderUsableGlobalBinds[action.BindName]
			
			
			if(HotkeyPassThrough[key] and IsValidHotkeyActive(Move[key]) and (self.ShiftDown or not commanderUseable)) then
					self.HotKey = key
					self.EatKeyUp[key] = true
				return true
			else
				if(commanderUseable) then
					 self:ActivateAction(action, key, true)
					return true
				end
			end
		end
	else
		if(HotkeyPassThrough[key]) then
			self.HotKey = key
		end
	end
end

function KeybindMapper:OnKeyUp(key)

	if(self.ChatOpen or self.InGameMenuOpen) then
		return false
	end

	self.KeyStillDown[key] = nil

	if(key == "LeftControl" or key == "RightControl") then
		self.CtlDown = false
	end
	
	if(key == "LeftShift" or key == "RightShift") then
		self.ShiftDown = false
	end
	
	if(key == "LeftAlt" or key == "RightAlt") then
		self.AltDown = false
	end

	local action, overrideGroup = self:FindKeysAction(key)

	if(action and not self.EatKeyUp[key]) then
		if(not self.IsCommander or overrideGroup or action.UserConsoleCmdBind or KeyBindInfo.CommanderUsableGlobalBinds[action.BindName]) then
				self:ActivateAction(action, key, false)
			return true
		end
	end

	if(self.EatKeyUp[key]) then
		self.EatKeyUp[key] = nil
	end

	if(self.HotKey == key) then
			self.HotKey = nil
		return true
	end
	
	return false
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
		--fix shooting when clicking close in buy menus
		if(self.BuyMenuOpen and (inputbit == Move.PrimaryAttack  or inputbit == Move.SecondaryAttack)) then
			return
		end
		
		self.MoveInputBitFlags = bit.bor(self.MoveInputBitFlags, inputbit)
	else
		self.MoveInputBitFlags = bit.band(self.MoveInputBitFlags, bit.bnot(inputbit))
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

function KeybindMapper:FillInMove(input, isCommander)
	if(not isCommander) then
		input.move = self.MovementVector
		input.commands = self.MoveInputBitFlags
	else
		local commandBits = self.MoveInputBitFlags

		--not everyone has Crouch and MovementModifier bound to Ctl and Shift so just hardwire these bits to Ctl and Shift
		if(self.CtlDown) then
			commandBits = bit.bor(commandBits, Move.Crouch)
		end

		if(self.ShiftDown) then
			commandBits = bit.bor(commandBits, Move.MovementModifier)
		end

		input.commands = commandBits
	end

	input.hotkey = (self.HotKey and Move[self.HotKey]) or 0
end


function KeybindMapper:CanKeyFallThrough(key)
	--Allow Keys to fall through if the ingame menu is open the so binding flash UI can recive them
	if(self.InGameMenuOpen) then
		return true
	end

	return false
end

function KeybindMapper:AddTickAction(TickFunc, statetbl, IdString, duplicateMode)
	
	if(not statetbl) then
		statetbl = {}
	end

	if(duplicateMode == "Replace" or duplicateMode == "NoReplace") then
		if(not IdString) then
			error("KeybindMapper:AddTickAction duplicateMode can only be used if IdString is set")
		end
		
		for i,action in ipairs(self.RunningActions) do
			if(action.ID == IdString) then
				if(duplicateMode == "Overwrite") then
					 table.remove(self.RunningActions, i)
					break
				else
					return false
				end
			end
		end
	end

	statetbl.TickCount = 0
	statetbl.Tick = TickFunc
	statetbl.ID = IdString

	table.insert(self.RunningActions, statetbl)
	
	return true
end

function KeybindMapper:InputTick()
	
	if(#self.RunningActions == 0) then
		return
	end

	local i, count = 1,#self.RunningActions

	while count ~= 0 and i <= count do
		local action = self.RunningActions[i]
		action.TickCount = action.TickCount+1
		
		if(action:Tick()) then
			table.remove(self.RunningActions, i)
			count = count-1
		else
			i = i+1
		end
	end
end

function KeybindMapper:IsTickActionActive(id)
	for i,action in ipairs(self.RunningActions) do
		if(action.ID == id) then
			return true
		end
	end
	
	return false
end

function KeybindMapper:LinkBindToFunction(bindname, func, updown, ...)
	
	local keybindEntry = {
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

	keybindaction.BindName = bindname
	self.KeybindActions[bindname] = keybindaction

	--map the key that the bindname is set to if were loaded already
	if(self.Loaded) then
		local key = KeyBindInfo:GetBoundKey(bindname)
	end
end

function KeybindMapper:GetDescriptionForBoundKey(key)

	local action = self:FindKeysAction(key)

	if(action.MovementVector) then
		return "Movement Keybind:"..action.MovementVector[3]
	end

	if(action.InputBit) then
		return "Move.input bit Keybind:"..action.InputBit
	end

	if(action.ConsoleCommand) then
		if(action.BindName) then
			return string.format("Console command \"%s\" Assocated with bind \"%s\"", action.ConsoleCommand, action.BindName)
		elseif(action.UserConsoleCmdBind) then
				
		end
	end
end

function KeybindMapper:SetKeyToConsoleCommand(key, commandstring)
	
	local keybindAction = {
		ConsoleCommand = commandstring,
		UserConsoleCmdBind = true,
		OnDown = function() Shared.ConsoleCommand(commandstring) end
	}

	self.ConsoleCmdKeys[key] = keybindAction
end

KeyBindInfo:Init()
KeybindMapper:Startup()