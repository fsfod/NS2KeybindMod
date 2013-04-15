//
//   Created by:   fsfod
//

--[[
	Public Api

	void SetKeyToConsoleCmd(string bindname, string ConsoleCommandString)
	
	--if the fuction name is not provided the name of the bindname is used as the function name
	void LinkBindToSelfFunction(bindname, selfobj, funcname [, string updown])
	

	void RegisterActionToBind(string bindname, table action)
	
	void ActivateKeybindGroup(string groupname)
	void DeactivateKeybindGroup(string groupname)
]]--

local IsReload = false

if(not KeybindMapper) then
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

	AltDown = false,
	OverrideGroups = {},
	OverrideGroupLookup = {},
	
-- change this to true if you want all keybinds tobe ignored when the console is open
-- this is disabled by default because there issues with dectecting when the console is open
	IgnoreConsoleState = true,
}
else
	IsReload = true
end

KeybindMapper.CommanderPassthroughKeys = {
  Escape = true,
  LeftControl = true,
  Control = true,
  LeftShift = 1,
  Shift = 1,
  Num1 = true,
  Num2 = true,
  Num3 = true,
  Num4 = true,
  Num5 = true,
  Num6 = true,
  Space = true,
}


--Script.Load("lua/BindingsShared.lua")

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
	MoveForward = {"z", 1, "MoveForward", false},
	MoveBackward = {"z", -1, "MoveBackward", false},
	MoveLeft = {"x", 1, "MoveLeft", false},
	MoveRight = {"x", -1, "MoveRight", false},
}

MovementKeybinds.MoveForward[4] = MovementKeybinds.MoveBackward
MovementKeybinds.MoveBackward[4] = MovementKeybinds.MoveForward
MovementKeybinds.MoveLeft[4] = MovementKeybinds.MoveRight
MovementKeybinds.MoveRight[4] = MovementKeybinds.MoveLeft


function KeybindMapper:Init()

	if(not self.Loaded) then
		self:SetupMoveVectorAndInputBitActions()	
		self:SetupHooks()
		
		KeyBindInfo:RegisterForKeyBindChanges(self, "OnKeybindsChanged")
		
		self.Loaded = true
	end
end

if(not IsReload) then
	Event.Hook("MapPostLoad", function() 
		KeybindMapper:Startup()
	end )

	Event.Hook("ClientDisconnected", function() 
		KeybindMapper:ShutDown()
	end )
end

function KeybindMapper:Startup()
	
	if(not self.IsShutDown) then
		return
	end
	
	self:Init()
	
	self.IsShutDown = false

	PlayerEvents:HookTeamChanged(self, "OnPlayerTeamChange")
end

function KeybindMapper:ShutDown()

	self.IsShutDown = true

	self:ResetInputStateData("ShutDown")

	self.ChatOpen = false
	self.InGameMenuOpen = false
	self.ConsoleOpen = false

	self.CurrentPlayerClass = nil
	self.IsCommander = false

	self.OverrideGroups = {}
	self.OverrideGroupLookup = {}

	self.ConsoleCmdKeys = {}
	self.Keybinds = {}
	
	self.TeamOverrides = nil
  self.CommanderOverrides = nil
	self.CommanderTeamOverrides = nil
	
	PlayerEvents.UnregisterAllCallbacks(self)
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
	
	self.PulseMoveBits = 0
	
	self.RunningActions = {}
	self.EatKeyUp = {}
	
	self.ActiveModifierKeys = {}
	
	for bindname,action in pairs(self.MovmentVectorActions) do
	  action.MovementVector.Down = false
	end

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
			self.ConsoleCmdKeys[key] = old
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
	
	self.CommanderHotKeys = KeyBindInfo:GetGroupBoundKeys("CommanderHotKeys")
end

local PulseBitTickAction = function(state)

  if(state.TickCount == 1 and state.WeaponSelect) then
    KeybindMapper:CheckWeaponSelectIntent(state.BitName)
  end
  
	if(state.TickCount == 2) then
			KeybindMapper:SetInputBit(Move[state.BitName], false)
		return true
	end
end
		
function KeybindMapper:PulseInputBit(bitname, action)
  
	assert(Move[bitname], "no input bit named "..bitname)
	assert(action)

	self.PulseMoveBits = bit.bor(self.PulseMoveBits, Move[bitname])
end

function KeybindMapper:AddPulsedInputBitAction(bitname, weaponSelector)

	local Action = {
		InputBit = bitname,
		UpdatesMove = true,
		WeaponSelect = weaponSelector,
		
		OnDown = function()
			self:PulseInputBit(bitname, bitname)
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
	Weapon1 = true,
	Weapon2 = true,
	Weapon3 = true,
	Weapon4 = true,
	Weapon5 = true,
	Weapon6 = true,
}

local PulsedInputBits = {
	ToggleFlashlight = true,
	Drop = true,
	Taunt = true,
	Buy = true,
	NextWeapon = true,
	PrevWeapon = true,
	Weapon1 = true,
	Weapon2 = true,
	Weapon3 = true,
	Weapon4 = true,
	Weapon5 = true,
	Weapon6 = true,
	
	ToggleVoteMenu = true,
	ToggleSayings1 = true,
	ToggleSayings2 = true,
	
}

function KeybindMapper:SetupMoveVectorAndInputBitActions()
		
	for _,bitname in ipairs(MoveEnum) do
		if(not SkipMoveBits[bitname] and not PulsedInputBits[bitname]) then
		 local action = KeybindMapper.CreateActionHelper(true, true, self,  bitname)
		 	action.InputBit = bitname
			action.OnDown = self.SetInputBit
		 	action.OnUp = self.SetInputBit
		 	action.UpdatesMove = true
		 
		 	self.InputBitActions[Move[bitname]] = action
		 	self:RegisterActionToBind(bitname, action)
		end
	end

	for bitname,_ in pairs(PulsedInputBits) do
		self:AddPulsedInputBitAction(bitname)
	end
	
	//for i=1,6 do
	//	self:CreateWeaponNumberAction(i)
	//end

	for bindname,movdir in pairs(MovementKeybinds) do
		local action = KeybindMapper.CreateActionHelper(true, false, self,  movdir)
		 	action.MovementVector = movdir
		 	action.OnDown = self.HandleMovmentVector
		 	action.OnUp = self.HandleMovmentVector
		 	
		 	action.UpdatesMove = true
		 	
		 self.MovmentVectorActions[bindname] = action
		 self:RegisterActionToBind(bindname, action)
	end

	local action = KeybindMapper.CreateActionHelper(false, false, self)
	action.OnDown = self.EscPressed
	self.FilteredKeys["Escape"] = {action}
	/*
	for i=1,5 do
	  local action = KeybindMapper.CreateActionHelper(false, false, self, i)
	    action.OnDown = self.HandleMenuNumbers
	  
	  self.FilteredKeys[Num..tostring(i)]
	end
	*/
end

function KeybindMapper:HandleMenuNumbers()
  
  return false
end

function KeybindMapper:EscPressed()

  local player = Client.GetLocalPlayer()

  if(not self.IsCommander) then
    // Close buy menu if open, otherwise show in-game menu
    if not player or not player:CloseMenu(kClassFlashIndex) then
      MainMenu_Open()
     return true
    end
  end

  return false
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

function KeybindMapper:InternalSetKeyAction(key, action)
	self.Keybinds[key] = action
end

function KeybindMapper:InGameMenuOpened()
	
	if(self.IsShutDown) then
		return
	end
	
	self:ResetInputStateData("InGameMenuOpened")
	self.InGameMenuOpen = true
end

function KeybindMapper:InGameMenuClosed()

	ChangedKeybinds = false

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
	
	if(self.IsShutDown or self.IsCommander) then
		return
	end
	
	self.IsCommander = true
	
	self.CommanderOverrides = self:ActivateOverrideGroup("Commander")
	self.CommanderTeamOverrides = self:ActivateOverrideGroup((CommanderSelf:isa("MarineCommander") and "MarineCommander") or "AlienCommander")
	
	self:ResetInputStateData("OnCommander")
end

function KeybindMapper:OnPlayerTeamChange(newTeam, oldTeam)

  if(self.TeamOverrides) then
    for i,name in ipairs(self.TeamOverrides) do
      self:DeactivateKeybindGroup(name)
    end
    
    self.TeamOverrides = nil
  end

  local teamName

  if(newTeam == kMarineTeamType) then
    teamName = "Marine"
  elseif(newTeam == kAlienTeamType) then
    teamName = "Alien"
  else
    return
  end
  
  self.TeamOverrides = self:ActivateOverrideGroup(teamName)
end

function KeybindMapper:OnUnCommander()

	if(self.IsShutDown) then
		return
	end

	self.IsCommander = false
	
	self:DeactivateOverrideGroup(self.CommanderTeamOverrides)
	self.CommanderTeamOverrides = nil
	
  self:DeactivateOverrideGroup(self.CommanderOverrides)
  self.CommanderOverrides = nil

	self:ResetInputStateData("OnUnCommander")
end

function KeybindMapper:ActivateOverrideGroup(groupName)
  
  local groupNames = KeyBindInfo:GetKeybindGroupsForOverrideGroup(groupName)

  if(#groupNames == 0) then
    return nil
  end
  
  for i,name in ipairs(groupNames) do
    self:ActivateKeybindGroup(name)
  end
  
  return groupNames
end

function KeybindMapper:DeactivateOverrideGroup(groupNames)

  if(not groupNames) then
    return
  end
  
  for i,name in ipairs(groupNames) do
    self:DeactivateKeybindGroup(name)
  end
end

function KeybindMapper:ActivateKeybindGroup(groupname)
	
	if(self.OverrideGroupLookup[groupname]) then
		Print("KeybindMapper:ActivateKeybindGroup group \""..groupname.."\" is already active")
	 return
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

//TODO figure out how to handle upkey event also handle causing an key up event if the modifer key is released with the normal still held down
function KeybindMapper:FindKeysActionWithModifers(key)
	
  if(not KeyBindInfo.ModifierKeys[key]) then
  
    for modifer,v in pairs(KeyBindInfo.ModifierKeys) do
      
      if(InputKeyHelper:IsModiferDown(modifer)) then
        local action, overrideGroup = self:FindKeysAction(modifer.."-"..key)
        
        if(action) then
          return action, overrideGroup, modifer
        end
      end
    end
  end
  
  return self:FindKeysAction(key)
end

-- favor simplicity over merging lots of tables key to bindname's
function KeybindMapper:FindKeysAction(key)
	

	local i = #self.OverrideGroups
	
	//search backwards from the end of the override list so 
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

local MenuPassThrough = {
  MouseButton0 = true,
  MouseButton1 = true,
  Escape = false,
}



function KeybindMapper:OnKeyDown(key)

	if(MouseStateTracker:IsStateActive("chat") or self.InGameMenuOpen or (MouseStateTracker:IsStateActive("buymenu") and MenuPassThrough[key])) then
		return false
	end

	--The Engines Console input event handler should be filtering all key input events when the console is open
	--so they don't get sent to other input handlers but doesn't for some dumb reason
	if(key == self.ConsoleKey) then
			self.ConsoleOpen = not self.ConsoleOpen			
		return true
	end

	if(self.FilteredKeys[key]) then
		for _,action in ipairs(self.FilteredKeys[key]) do
		  
			--if a filter action returns true we don't let anything else process this key event and just return
			if(self:ActivateAction(action, key, true)) then
				return true
			end
		end
	end

  local action,overrideGroup,modifier

	if(self.IsCommander) then
	  action,overrideGroup,modifier = self:CommaderOnKey(key, true)
	  
	  //CommaderOnKey excuted the bind directly nothing else todo
	  if(action == true) then
      return true
    end
	else
	  action, overrideGroup,modifier = self:FindKeysActionWithModifers(key)
	end
  
	if(not action) then
	  return false
	end
  
	if(key == "MouseWheelUp" or key == "MouseWheelDown") then
	  //we don't need to worry about a modifer key being released with mouseWheel events since mousewheel direction up event is triggered internaly
    self:HandleMouseWheel(key, action)
  else
    self:ActivateAction(action, key, true, modifier)
	end

	return true
end

local function MouseWheelTick(state)
      
  if(state.TickCount == state.EndTick) then
    KeybindMapper:ActivateAction(state.Action, state.Key, false)
    
   return true
  end
  
  //RawPrint(state.Key, " prediction=", Shared.GetIsRunningPrediction()) 
  //state.ExtraTickSet = false

  return false
end

local lastClick = Shared.GetTime()

function KeybindMapper:HandleMouseWheel(key, action)
  
  local state = self:GetActiveTickAction(key)
  
  if(state) then
    return
    
    /*
    //we've already extended this action one tick already
    if(true or state.ExtraTickSet) then
      return
    end
    
    state.ExtraTickSet = true
    state.EndTick = state.EndTick+2
    */
   
  end
  
  self:ActivateAction(action, key, true)
  
  local TickState = {
    Key = key,
    EndTick = 2,
    Action = action
  }

  //RawPrint("HandleMouseWheel",key, "prediction=", Shared.GetIsRunningPrediction()) 

  self:AddTickAction(MouseWheelTick, TickState, key, "NoReplace")
end


local HotkeyToButton = { 
  CommHotKey1 = 1,
  CommHotKey2 = 2,
  CommHotKey3 = 3,
  CommHotKey4 = 4,

  CommHotKey5 = 5,
  CommHotKey6 = 6,
  CommHotKey7 = 7,
  CommHotKey8 = 8,

  CommHotKey9 = 9,
  CommHotKey10 = 10,
  CommHotKey11 = 11,
  CommHotKey12 = 12,
}

function KeybindMapper:GetHotKeyButtonIndex(key)
	local player = Client.GetLocalPlayer() 
	
	if(not player:isa("Commander")) then
		return false
	end

  local Hotkey = self.CommanderHotKeys[key]
	local index = Hotkey and HotkeyToButton[Hotkey]

	if(index and player.menuTechButtonsAllowed[index]) then
		return index
	else
		return nil
	end

  //self:SetHotkeyHit(index)
  //self.lastHotkeyIndex = index
end

local CommaderOverrideGroups = {
	CommanderShared = true,
	MarineCommander = true,
	AlienCommander = true,
}

function KeybindMapper:CommaderOnKey(key, down)
	local action, overrideGroup, modifier = self:FindKeysActionWithModifers(key)

	local commanderUseable = action and ((overrideGroup and CommaderOverrideGroups[overrideGroup]) or 
													 action.UserConsoleCmdBind or KeyBindInfo.CommanderUsableGlobalBinds[action.BindName])
	
	local HotKeyButton = self:GetHotKeyButtonIndex(key)
	
	local UseHotKey = HotKeyButton and (not commanderUseable or 
	                                     (self.HotKeyShiftOverride and not InputKeyHelper:IsShiftDown()) or (not self.HotKeyShiftOverride and InputKeyHelper:IsShiftDown()))

	if(UseHotKey) then
		if(down) then			
			local player = Client.GetLocalPlayer() 
			 player:SetHotkeyHit(HotKeyButton)
			 //self.lastHotkeyIndex = index

			/*
			self:AddTickAction(function(state)
				if(state.TickCount == 2) then
					self.HotKey = nil
				 return true
				end
			end, nil, "HotKeyUp", "NoReplace")
						
			self.HotKey = key
						
			self.EatKeyUp[key] = true
		*/
	 	 return true
	 	else
	 		
	 	end
	end

	if(commanderUseable and action) then
	  return action,overrideGroup, modifier
	end
	
	return false
end

function KeybindMapper:OnKeyUp(key)

	//if(MouseStateTracker:IsStateActive("chat") or self.InGameMenuOpen or (MouseStateTracker:IsStateActive("buymenu") and MenuPassThrough[key])) then
	//	return false
	//end


  if(self.ActiveModifierKeys[key]) then
    
    for singleKey, activeAction in pairs(self.ActiveModifierKeys[key]) do 
      self:ActivateAction(activeAction, singleKey, false)
      self.ActiveModifierKeys[key][singleKey] = nil
    end
  else
    
    //trigger the up event for combination of this key with modifiers that has an active action    
    for modifier,activeActions in pairs(self.ActiveModifierKeys) do   
      if(activeActions[key]) then
        self:ActivateAction(activeActions[key], key, false)
        activeActions[key] = nil
      end
    end
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
	
	return false
end

function KeybindMapper:ActivateAction(action, key, down, modifier)
	
	local func = action.OnDown
	local result = false

	if(not down) then
		func = action.OnUp
	else
	  
	  if(modifier) then
	    
	    if(not self.ActiveModifierKeys[modifier]) then
	      self.ActiveModifierKeys[modifier] = {}
	    end
	    
	    self.ActiveModifierKeys[modifier][key] = action
	  end
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

function KeybindMapper:SetInputBit(bitName, keydown, keyName)

  assert(Move[bitName], "Uknowned input bit "..(bitName or "nil")) 

	if(keydown) then
		--fix shooting when clicking close in buy menus
		if(MouseStateTracker:IsStateActive("buymenu") and (bitName == "PrimaryAttack"  or bitName == "SecondaryAttack")) then
			return
		end
		
		self.MoveInputBitFlags = bit.bor(self.MoveInputBitFlags, Move[bitName])
	else
		self.MoveInputBitFlags = bit.band(self.MoveInputBitFlags, bit.bnot(Move[bitName]))
	end
end

function KeybindMapper:HandleMovmentVector(movedir, keydown)
  
  local VectorField = movedir[1]

	if(keydown) then
		--just overwrite movement vector field even if the other direction set it
	  self.MovementVector[VectorField] = movedir[2] 
		movedir.Down = true
	else
		--don't do anything if the the opposite movment key is already being held down i.e. our movement vector field is not equal to our direction number
		if(self.MovementVector[VectorField] == movedir[2]) then
			--if the the opposite movment key is already being held down switch to that direction
			if(movedir[4].Down) then
			  self.MovementVector[VectorField] = movedir[4][2]
			else
			  self.MovementVector[VectorField] = 0
			end
		end
		
		movedir.Down = false
	end
end

local bor = bit.bor

//this is called from our OverrideInput hook
function KeybindMapper:FillInMove(input, isCommander)
	
	local commandBits = bit.bor(self.MoveInputBitFlags, self.PulseMoveBits)
	
	self.PulseMoveBits = 0
	
	if(not isCommander) then
		input.move = self.MovementVector
		input.commands = commandBits
	else

		--not everyone has Crouch and MovementModifier bound to Ctl and Shift so just hardwire these bits to Ctl and Shift
		if(InputKeyHelper:IsCtlDown()) then
			commandBits = bit.bor(commandBits, Move.Crouch)
		else
			commandBits = bit.band(commandBits, bit.bnot(Move.Crouch))
		end

		if(InputKeyHelper:IsShiftDown()) then
			commandBits = bit.bor(commandBits, Move.MovementModifier)
		else
			commandBits = bit.band(commandBits, bit.bnot(Move.MovementModifier))
		end

		input.commands = commandBits
	end

	input.hotkey = (self.HotKey and Move[self.HotKey]) or 0
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
				if(duplicateMode == "Replace") then
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

function KeybindMapper:GetActiveTickAction(id)
	
	for i,action in ipairs(self.RunningActions) do
		if(action.ID == id) then
			return action
		end
	end
	
	return nil
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