
--[[
Notes

		
Public functions:
	string:replacedBind SetKeybind(string keyName, string BindName)
	bool IsKeyBound(string keyName)
	string GetBoundKey(string bindName)
	string GetBindSetToKey(string keyName)
	void UnbindKey(string KeyName)
	void ClearBind(string BindName)
	
	table GetGlobalBoundKeys() table format  {key = bindname}
	
	void SetConsoleCmdBind(string keyName, string consoleCommand)
	table GetConsoleCmdBoundKeys() table format  {keyName = consoleCmdString}
	string,IsBind:bool GetKeyInfo(string keyName)
	
	bool IsBindOverrider(stirng bindName)
	
	bool KeybindGroupExists(stirng groupName)
	table GetGroupBoundKeys(string groupName)
	string GetBoundKeyGroup(string keyName, string groupName)
	string:groupname GetBindsGroup(stirng bindName)
]]--

Script.Load("lua/InputKeyHelper.lua")

KeyBindInfo = {
	Loaded = false,
	KeybindEntrys = {},
	RegisteredKeybinds = {},
	KeybindNameToKey = {},
	KeybindNameToOwnerGroup = {},
	BoundConsoleCmds = {},
	BoundKeys = {}, --stores the maping of a key to a keybindname. Override bind keys never get put in this table

	KeyBindsChangedCallsbacks = {},

	KeybindGroupLookup = {},
	KeybindGroups = {}, --we need this so we have an ordered list of keybind groups when deciding default keys
	KeybindOverrideGroups = {},
	LogLevel = 1,
}

KeyBindInfo.MovementKeybinds = {
		Name = "Movement",
		Keybinds = {
    	{"MoveForward", "Move forward", "W"},
    	{"MoveBackward", "Move Backward", "S"},
    	{"MoveLeft", "Move Left", "A"},
    	{"MoveRight", "Move Right", "D"},
    	{"Jump", "Jump", "Space"},
    	{"MovementModifier", "Movement special", "LeftShift"},
    	{"Crouch", "Crouch", "LeftControl"},
    }
}

KeyBindInfo.ActionKeybinds = {
		Name = "Action",  
		Keybinds = {
    	{"PrimaryAttack", "Primary attack", "MouseButton0"},
    	{"SecondaryAttack", "Secondary attack", "MouseButton1"},
    	{"Reload", "Reload", "R"},
    	{"Use", "Use", "E"},
    	{"Drop", "Drop weapon", "G"},
  		{"Buy",  "Buy/evolve menu", "B"},
    	{"Taunt", "Taunt", "Z"},
    	{"Minimap", "Show MiniMap", ""},
			{"ToggleSayings1","Sayings #1", "X"},
			{"ToggleSayings2","Sayings #2", "C"},
    	{"VoiceChat", "Use microphone", "LeftAlt"},
    	{"TextChat", "Public chat", "Y"},
    	{"TeamChat", "Team chat", "U"},
    	{"Scoreboard",  "Show Scoreboard", "Tab"},
    	{"NextWeapon", "Select Next Weapon", ""},
			{"PrevWeapon", "Select Previous Weapon", ""},
    	{"Weapon1", "Weapon #1", "Num1"},
    	{"Weapon2", "Weapon #2", "Num2"},
    	{"Weapon3", "Weapon #3", "Num3"},
    	{"Weapon4", "Weapon #4", "Num4"},
    	{"Weapon5", "Weapon #5", "Num5"},
    	{"ToggleFlashlight", "Toggle Flashlight", "F"},
    }
}

KeyBindInfo.MiscKeybinds = {
		Name = "Misc",
		Keybinds = {
			{"OpenFeedback", "Open Feedback Webpage", "F5"},
			--{"ToggleThirdPerson",	"Toggle Third Person View", ""},
			{"JoinMarines", 	"Join Marines", 				"F1"},
			{"JoinAliens", 		"Join Aliens",					"F2"},
			{"JoinRandom", 		"Join Random Team", 		"F3"},
			{"ReadyRoom",		"Return to Ready Room", "F4"},
			{"ToggleConsole", "Toggle Console", 				"Grave"},
			{"Exit", 					"Open Main Menu", 			"Escape"},
		}
}

KeyBindInfo.CommanderShared = {
		OverrideGroup = true,
		Name = "CommanderShared",
		Label = "Commander Shared Overrides",
		
		Keybinds = {
			{"NextIdleWorker", "Select Next Idle Worker", "H"},
			{"ScrollForward", 	"Scroll View Forward",	"Up"},
			{"ScrollBackward", 	"Scroll View Backward",	"Down"},
			{"ScrollLeft",	"Scroll View Left", "Left"},
			{"ScrollRight", "Scroll View Right", "Right"},
		}
}

KeyBindInfo.MarineCommander = {
		OverrideGroup = true,
		Name = "MarineCommander",
		Label = "Marine Commander Overrides",  
		
		Keybinds = {
			{"DropAmmo",	"Drop Ammo Pack", "N"},
			{"DropHealth", "Drop Health Pack", "M"},
		}
}

KeyBindInfo.AlienCommander = {
		OverrideGroup = true,
		Name = "AlienCommander",
		Label = "Alien Commander Overrides",  
		
		Keybinds = {
			{"PlaceHolder",	"PlaceHolder", ""},
		}
}
--[[
KeyBindInfo.HiddenKeybinds = {
		Hidden = true,
		Name = "EngineInternal",
		Keybinds = {
			{"ActivateSteamworksOverlay"},
			{"LockViewFrustum"},
			{"LockViewPoint"},
			{"ToggleDebugging"},
		}
}

KeyBindInfo.MarineSayings = {
		OverrideGroup = true,
		Name = "MarineSayings",
		Label = "Marine Request Sayings",  

		Keybinds = {
			{"Saying_Acknowledge",	"Acknowledged", ""},
			{"Saying_NeedMedpack", "Need medpack", ""},
			{"Saying_NeedAmmo", "Need ammo", ""},
			{"Saying_NeedOrder", "Need orders", ""},
			 
			 
			{"Saying_FollowMe",	"Follow me", ""},
			{"Saying_LetsMove", "Let's move", ""},
			{"Saying_CoveringYou", "Covering you", ""},
			{"Saying_Hostiles", "Hostiles", ""},
			{"Saying_Hostiles", "Taunt", ""},
		}
}

KeyBindInfo.AlienSayings = {
		OverrideGroup = true,
		Name = "AlienSayings",
		Label = "Alien Sayings",  
		
		Keybinds = {
			{"Saying_Needhealing",	"Need healing", ""},
			{"Saying_Followme", "Follow me", ""},
			{"Saying_Chuckle", "Chuckle", ""},
		}
}
]]--
KeyBindInfo.EngineProcessed = {
	ToggleConsole = true,
	ActivateSteamworksOverlay = true,
  LockViewFrustum = true,
  LockViewPoint = true,
  ToggleDebugging = true,
  VoiceChat = true,
}

KeyBindInfo.CommanderUsableGlobalBinds = {
	VoiceChat = true,
	TextChat = true,
	TeamChat = true,
	ToggleConsole = true,
	OpenFeedback = true,
	ReadyRoom = true,
	Scoreboard = true,
	PrimaryAttack = true,
	SecondaryAttack= true,
	Weapon1 = true,
	Weapon2 = true,
	Weapon3 = true,
	Weapon4 = true,
	Weapon5 = true,
}

function KeyBindInfo:Init()
	if(not self.Loaded) then
		self:AddDefaultKeybindGroups()
		self:ReloadKeyBindInfo()
	end
end

function KeyBindInfo:RegisterForKeyBindChanges(selfTable, funcName)
	local Callback = {selfTable, selfTable[funcName]}
		table.insert(self.KeyBindsChangedCallsbacks, Callback)
	
	return Callback
end

function KeyBindInfo:UnRegisterForKeyBindChanges(callbackTable)
	table.removevalue(self.KeyBindsChangedCallsbacks, callbackTable)
end

function KeyBindInfo:OnBindingsUIEntered()
	self.KeyBindSnapshot = self:GetKeyBindSnapshot()
end

function KeyBindInfo:OnBindingsUIExited()

	if(self.KeyBindSnapshot) then
		local changes, changedCmds = self:GetChangedKeybinds(self.KeyBindSnapshot)

		if(next(changes) or next(changedCmd)) then
			self:OnBindingsChanged(changes, changedCmds)
		end

		self.KeyBindSnapshot = nil
	end
end

function KeyBindInfo:OnBindingsChanged(bindChanges, ConsoleCmdChanges)
	
	bindChanges = bindChanges or {}
	ConsoleCmdChanges = ConsoleCmdChanges or {}
	
	for _,hook in ipairs(self.KeyBindsChangedCallsbacks) do
		hook[2](hook[1], bindChanges, ConsoleCmdChanges)
	end
end

function KeyBindInfo:GetKeyBindSnapshot()

	local Snapshot = {}

	for bindname,key in pairs(self.KeybindNameToKey) do
		Snapshot[bindname] = key 
	end

	local ConsoleCmds = {}

	for consoleCmd,key in pairs(self.BoundConsoleCmds) do
		ConsoleCmds[consoleCmd] = key 
	end

	return {Snapshot, ConsoleCmds}
end

function KeyBindInfo:GetChangedKeybinds(old)
	
	local Keys = old[1]
	
		--mark unchanged keys so we can later nil them
		for bindname,key in pairs(Keys) do
			if(self.KeybindNameToKey[bindname] == key) then
				Keys[bindname] = false
			end
		end

		--find new keys added
		for bindname,key in pairs(self.KeybindNameToKey) do
			if(Keys[bindname] == nil) then
				Keys[bindname] = ""
			end
		end

		--remove marked keys now that we've found new keys
		for bindname,key in pairs(Keys) do
			if(key == false) then
				Keys[bindname] = nil
			end
		end

	local ConsoleCmds = old[2]

	for consoleCmd,key in pairs(ConsoleCmds) do
		if(self.BoundConsoleCmds[key]) then
			ConsoleCmds[key] = nil
		end
	end

	return Keys, ConsoleCmds
end

function KeyBindInfo:ReloadKeyBindInfo(returnChanges)	
	self.KeybindNameToKey = {}
	self.BoundKeys = {}
	self.BoundConsoleCmds = {}

	self:LoadAndValidateSavedKeyBinds()
	self.Loaded = true
	self.LazyLoad = nil
end

function KeyBindInfo:AddDefaultKeybindGroups()
	self:AddKeybindGroup(self.MovementKeybinds)
	self:AddKeybindGroup(self.ActionKeybinds)
	self:AddKeybindGroup(self.MiscKeybinds)
	--self:AddKeybindGroup(self.HiddenKeybinds)
	self:AddKeybindGroup(self.CommanderShared)
	self:AddKeybindGroup(self.MarineCommander)
	self:AddKeybindGroup(self.AlienCommander)
end

--
function KeyBindInfo:AddKeybindGroup(keybindGroup)
	
	table.insert(self.KeybindGroups, keybindGroup)

	self.KeybindGroupLookup[keybindGroup.Name] = keybindGroup

	for _,keybind in ipairs(keybindGroup.Keybinds) do
		self.KeybindNameToOwnerGroup[keybind[1]] = keybindGroup
		self.RegisteredKeybinds[keybind[1]] = keybind

		self.KeybindEntrys[#self.KeybindEntrys+1] = keybind
	end
end

function KeyBindInfo:LoadAndValidateSavedKeyBinds()
	
	local FirstLoad = Client.GetOptionString("Keybinds/Version", "") == ""
	
	if(FirstLoad) then
		self:ImportKeys()
		Client.SetOptionString("Keybinds/Version", "1")
	end

	for _,bindgroup in ipairs(self.KeybindGroups) do
		if(bindgroup.OverrideGroup) then
			self:LoadOverrideGroup(bindgroup)
		else
			self:LoadGroup(bindgroup)
		end
	end

	if(FirstLoad) then
		self:FillInFreeDefaults()
	end
	
	self:LoadConsoleCmdBinds()
end

function KeyBindInfo:LoadGroup(bindgroup)
	
	for _,bindinfo in ipairs(bindgroup.Keybinds) do
		local key = Client.GetOptionString("Keybinds/Binds/"..bindinfo[1], "")

		if(key ~= "") then
			if(self:IsKeyBound(key)) then
				error(string.format("ignoreing \"%s\" bind because \"%s\" is alreay bound to the same key which is \"%s\"", bindinfo[1], self.BoundKeys[key], key))
				--self:Logerror(1, , 2 )
			else
				self:InternalBindKey(key, bindinfo[1])
			end
		end
	end
end

function KeyBindInfo:LoadOverrideGroup(bindgroup)
	local unboundcount = 0

	for _,bindinfo in ipairs(bindgroup.Keybinds) do
		local key = Client.GetOptionString("Keybinds/Binds/"..bindinfo[1], "")
			if(key ~= "") then
				self:InternalBindKey(key, bindinfo[1], true)
			end
	end
end

local KeyNameFixups = {
	["0"] = "Num0",
	["1"] = "Num1",
	["2"] = "Num2",
	["3"] = "Num3",
	["4"] = "Num4",
	["5"] = "Num5",
	["6"] = "Num6",
	["7"] = "Num7",
	["8"] = "Num8",
	["9"] = "Num9",
}

local ImportList = {
	"PrimaryAttack",
	"SecondaryAttack",
	"MoveForward",
  "MoveBackward",
  "MoveLeft",
  "MoveRight",
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

function KeyBindInfo:ImportKeys()
	
	local keys = {}
	
	local importCount = 0
	
	for _,bindname in ipairs(ImportList) do
		local key = Client.GetOptionString("input/"..bindname, "")

		if(key ~= "") then
			--fix the number key names
			key = KeyNameFixups[key] or key
			
			--ignore this bind if something else was bound to the same key
			if(not keys[key]) then
				keys[key] = bindname
				Client.SetOptionString("Keybinds/Binds/"..bindname, key)
				importCount = importCount+1
			else
				Shared.Message("KeyBindInfo:ImportKeys Skipped importing " ..bindname.." because another bind was set to the same key")
			end
		end
	end
	
	Shared.Message("Sucessfuly imported "..importCount.." keybinds.")
end

function KeyBindInfo:FillInFreeDefaults()
	
	for _,bindgroup in ipairs(self.KeybindGroups) do
		local IsOverrideGroup = bindgroup.OverrideGroup
		
			for _,bind in ipairs(bindgroup.Keybinds) do
				local bindname = bind[1]
				local defaultKey = bind[3]

				if(defaultKey ~= "" and (IsOverrideGroup or (not self:GetBoundKey(bindname) and not self:IsKeyBound(defaultKey)) )) then
					Client.SetOptionString("Keybinds/Binds/"..bindname, defaultKey)
					self:InternalBindKey(defaultKey, bindname, IsOverrideGroup)
				end
			end
	end
end

function KeyBindInfo:FindBind(name)
	
	local uppername = name:upper()

	for bindname,_ in pairs(self.RegisteredKeybinds) do
		if(uppername == bindname:upper()) then
			return bindname
		end
	end
	
	return nil
end


function KeyBindInfo:LoadConsoleCmdBinds()
	self.BoundConsoleCmds = {}

	local consolekeys = Client.GetOptionString("Keybinds/ConsoleKeys", "")

	if(consolekeys ~= "") then
		for key in consolekeys:gmatch("[^,]+") do
			local cmdstring = Client.GetOptionString("Keybinds/ConsoleCmds/"..key, "")

			if(cmdstring ~= "") then
				self.BoundConsoleCmds[key] = cmdstring
			end
		end
	end
end

function KeyBindInfo:SetConsoleCmdBind(key, cmdstring)

	local OldBindorCmd, IsBind = self:GetKeyInfo(key)

	if(OldBindorCmd) then
		self:UnbindKey(key)
	end

	self.BoundConsoleCmds[key] = cmdstring

	Client.SetOptionString("Keybinds/ConsoleCmds/"..key, cmdstring)

	self:SaveConsoleCmdKeyList()

	local tbl = {}

	if(OldBindorCmd) then
		if(IsBind) then
			tbl[OldBindorCmd] = true 
			self:OnBindingsChanged(tbl, nil)
		else
			tbl[key] = true
			self:OnBindingsChanged(nil, tbl)
		end
	end

end

function KeyBindInfo:GetKeyInfo(key)
	if(self.BoundKeys[key]) then
		return self.BoundKeys[key], true
	elseif(self.BoundConsoleCmds[key]) then
		return self.BoundConsoleCmds[key], false
	end
	
	return nil, false
end

function KeyBindInfo:ClearConsoleCmdBind(key)

	self.BoundConsoleCmds[key] = nil
	Client.SetOptionString("Keybinds/ConsoleCmds/"..key, "")

	self:SaveConsoleCmdKeyList()
end

function KeyBindInfo:SaveConsoleCmdKeyList()


	if(next(self.BoundConsoleCmds)) then
		local keylist = {}

		for key,consoleCmd in pairs(self.BoundConsoleCmds) do
			keylist[#keylist+1] = key
		end

		Client.SetOptionString("Keybinds/ConsoleKeys", table.concat(keylist, ",")..",")
	else
		Client.SetOptionString("Keybinds/ConsoleKeys", "")
	end
end

function KeyBindInfo:GetBindingDialogTable()
	if(not self.Loaded) then
		self:Init()
	end

	if(not self.BindingDialogTable) then
		local bindTable = {}
		local index = 1

		for _,bindgroup in ipairs(self.KeybindGroups) do
			if(not bindgroup.Hidden) then
				bindTable[index] = bindgroup.Label or bindgroup.Name 
				bindTable[index+1] = "title"
				bindTable[index+2] = bindgroup.Label or bindgroup.Name
				bindTable[index+3] = ""
			 
			 	index = index+4
					
				for _,bind in ipairs(bindgroup.Keybinds) do
					bindTable[index] = bind[1] 
					bindTable[index+1] = "input"
					bindTable[index+2] =  bind[2]
					bindTable[index+3] =  bind[3]
				 
				 	index = index+4
				end
			end
		end
		
		self.BindingDialogTable = bindTable
	end

	return self.BindingDialogTable
end

function KeyBindInfo:GetBoundKey(keybindname)

	if(self.RegisteredKeybinds[keybindname] == nil) then
		error("GetBoundKey: keybind called \""..(keybindname or "nil").."\" does not exist")
	end

	return self.KeybindNameToKey[keybindname]
end

function KeyBindInfo:GetGlobalBoundKeys()
	return self.BoundKeys
end

function KeyBindInfo:GetConsoleCmdBoundKeys()
	return self.BoundConsoleCmds
end

function KeyBindInfo:IsBindOverrider(keybindname)
	
	local group = self.KeybindNameToOwnerGroup[keybindname]
	
	if(group == nil) then
		error("IsBindOverrider: keybind called \""..(keybindname or "nil").."\" does not exist")
	end
	
	return group.OverrideGroup ~= nil
end

--
function KeyBindInfo:IsKeyBound(key)
	return self.BoundKeys[key] ~= nil or self.BoundConsoleCmds[key] ~= nil
end

function KeyBindInfo:IsKeyBoundToConsoleCmd(key)
	return self.BoundConsoleCmds[key] ~= nil
end

function KeyBindInfo:GetBindSetToKey(key)
	return self.BoundKeys[key]
end

function KeyBindInfo:GetBoundKeyGroup(key, groupName)
	local group = self.KeybindGroupLookup[groupName]
		
	for _,bindinfo in ipairs(group.Keybinds) do
		if(self:GetBoundKey(bindinfo[1]) == key) then
			return bindinfo[1]
		end
	end

	return nil
end

function KeyBindInfo:GetBindsGroup(bindname)
	return self.KeybindNameToOwnerGroup[bindname].Name
end

function KeyBindInfo:SetKeybind(key, bindname, isMultiEdit)

	local clearedBind

	if(self.RegisteredKeybinds[bindname] == nil) then
		error("SetKeyBind: keybind called \""..bindname.."\" does not exist")
	end
	
	local changes, CmdChanges
	local IsOverride = self:IsBindOverrider(bindname)

	if(not isMultiEdit) then
		changes = {}
		CmdChanges = {}
		changes[bindname] = true
	end

	if(not IsOverride) then
		--if the keybind had a key already set to it clear the record of it in our BoundKeys table
		if(self.KeybindNameToKey[bindname]) then
			self.BoundKeys[self.KeybindNameToKey[bindname]] = nil
		end
		
		local clearedBindOrCmd, IsBind = self:GetKeyInfo(key)
		--if something else was already bound to this key clear it
		if(clearedBindOrCmd) then
			if(not isMultiEdit) then
				if(IsBind) then
					changes[clearedBindOrCmd] = true
				else
					CmdChanges[key] = true
				end
			end

			self:UnbindKey(key)
		end
	else
		--check to see this key is not bound to something else in this override group
		local group = self.KeybindNameToOwnerGroup[bindname]
		local groupbind = self:GetBoundKeyGroup(key, group.Name)
		
		if(groupbind) then
			if(not isMultiEdit) then
				changes[groupbind] = true
			end
			
			self:ClearBind(groupbind)
		end
	end

	self:InternalBindKey(key, bindname, IsOverride)

	Client.SetOptionString("Keybinds/Binds/"..bindname, key)

	if(not isMultiEdit) then
		self:OnBindingsChanged(changes, CmdChanges)
	end
end

function KeyBindInfo:UnbindKey(key)
	
	local bindName, IsBind = self:GetKeyInfo(key)
	
	if(not bindName) then
			self:Log(1, "\""..key.."\" is already unbound")
		return
	end

	if(IsBind) then		
		self:ClearBind(bindName)
	else
		self:ClearConsoleCmdBind(key)
	end
end

function KeyBindInfo:ClearBind(bindName)

	local IsOverride = self:IsBindOverrider(bindName)

	Client.SetOptionString("Keybinds/Binds/"..bindName, "")

	if(self.KeybindNameToKey[bindName] == nil) then
		self:Log(1, "\""..bindName.."\" is already unbound")
	else
		if(not IsOverride) then
			self.BoundKeys[self.KeybindNameToKey[bindName]] = nil
		end
		
		self.KeybindNameToKey[bindName] = nil
	end
end

function KeyBindInfo:CheckKeyBindsLoaded()
	--check if we populated the table already
	if(next(self.BoundKeys) ~= nil) then
		return
	else
		self:LoadAndValidateSavedKeyBinds()
	end
end

function KeyBindInfo:InternalBindKey(key, bindname, isOverrideKey)
	
	if(not isOverrideKey) then
		self.BoundKeys[key] = bindname
	end
	self.KeybindNameToKey[bindname] = key
end

function KeyBindInfo:KeybindGroupExists(groupname)
	return self.KeybindGroupLookup[groupname] ~= nil
end

function KeyBindInfo:GetGroupBoundKeys(groupname)

	if(not self:KeybindGroupExists(groupname)) then
		error("KeyBindInfo:GetGroupBoundKeys group \""..groupname.."\" does not exist")		
	end

	local keybinds = {}

		for _,bindinfo in ipairs(self.KeybindGroupLookup[groupname].Keybinds) do
			local key = self:GetBoundKey(bindinfo[1])

			if(key) then
				keybinds[key] = bindinfo[1]
			end
		end

	return keybinds
end

function KeyBindInfo:ResetKeybinds()

	Client.SetOptionString("Keybinds/ConsoleKeys", "")
	Client.SetOptionString("Keybinds/ConsoleCmds", "")
	
	--just wipe out all the binds by setting the inner text of Keybinds/Binds to an empty string
	Client.SetOptionString("Keybinds/Binds", "")

	for _,bindgroup in ipairs(self.KeybindGroups) do
		for _,bind in ipairs(bindgroup.Keybinds) do
			if(bind[3]) then
				Client.SetOptionString("Keybinds/Binds/"..bind[1], bind[3])
			end
		end
	end

	self:ReloadKeyBindInfo()
	
	local Changes = {}
	
	for bindname,v in pairs(self.KeybindNameToKey) do
		Changes[bindname] = true
	end
	
	self:OnBindingsChanged(Changes)
end

function KeyBindInfo:Log(level, msg)
	
	if(level > self.LogLevel) then
		return
	end
	
	if(Shared) then
		Shared.Message(msg)
	else
		print(msg)
	end
end

local FriendlyNames = {
	MouseButton0 = "Left Click",
	MouseButton1 = "Right Click",
}

local function BindReplacer(bindstring)
	
	--strip the @ symbolds from both ends of the stirng
	local CleanBindName = string.sub(bindstring, 2, -2)
	
	local key = KeyBindInfo:GetBoundKey(CleanBindName)
	
	key = FriendlyNames[key] or key
	
	if(key) then
		return key
	else
		return "Not Bound"
	end
end

function KeyBindInfo_FillInBindKeys(s)
	--can't just return the result directly cause gsub returns a number as well
	local s = string.gsub(s, "(@[^@]+@)", BindReplacer)
	return s
end