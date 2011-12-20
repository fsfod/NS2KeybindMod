//
//   Created by:   fsfod
//

function Bind_ConsoleCommand(key, ...)
	
	local argCount = select('#', ...)

	if(not key or argCount == 0) then
		Shared.Message("bind: useage \"bind keyname bindname/consolecommand\"")
	 return
	end

	local RealKeyName = InputKeyHelper:FindAndCorrectKeyName(key)
	
	if(not RealKeyName) then
			Shared.Message("bind: Unreconized key "..key)
		return 
	end
	
	local BindName = select(1, ...)
	local ForcedConsoleCmd = BindName[1] == '@'
	local RealBindName = not ForcedConsoleCmd and argCount == 1 and KeyBindInfo:FindBind(BindName)
	
	local BindOrCmd, IsBind =  KeyBindInfo:GetKeyInfo(RealKeyName)

	if(not RealBindName) then
			local command = table.concat({...}, " ")
		
			if(BindOrCmd) then
				if(IsBind) then
					Shared.Message(string.format("bind: Conflicting bind \"%s\" was unbound", BindOrCmd))
				else
					Shared.Message(string.format("bind: Conflicting ConsoleCmd bind \"%s\" was unbound", BindOrCmd))
				end
			end

			KeyBindInfo:SetConsoleCmdBind(RealKeyName, command)

			if(not BindOrCmd) then
			  KeybindMapper:SetKeyToConsoleCommand(RealKeyName, command)
			end
			
			Shared.Message(string.format("bind: Key \"%s\" was bound to console command \"%s\"", RealKeyName, command))
	else	
		if(KeyBindInfo:IsBindOverrider(RealBindName)) then
			local bindgroup = KeyBindInfo:GetBindsGroup(RealBindName)
			local conflict = KeyBindInfo:GetBoundKeyGroup(RealKeyName, bindgroup)
  	
			if(conflict) then
				Shared.Message(string.format("bind: Conflicting bind \"%s\" was unbound in override group %s", conflict, bindgroup))
			end
		elseif(BindOrCmd) then
			if(IsBind) then
				Shared.Message(string.format("bind: Conflicting bind \"%s\" was unbound", BindOrCmd))
			else
				Shared.Message(string.format("bind: Conflicting ConsoleCmd bind \"%s\" was unbound", BindOrCmd))
			end
		end
  	
		KeyBindInfo:SetKeybind(RealKeyName, RealBindName)
		Shared.Message(string.format("bind: Key \"%s\" was bound to bind \"%s\"", RealKeyName, RealBindName))   
	end
end

Event.Hook("Console_bind",  Bind_ConsoleCommand)


Event.Hook("Console_resetinput", function() KeybindMapper:FullResetState() end)

Event.Hook("Console_resetbinds", function() 
	KeyBindInfo:ResetKeybinds()
	Shared.Message("Keybinds reset")
end)

local StateVars = {
	ChatOpen = true,
	InGameMenuOpen = true,
	BuyMenuOpen = true,
	ConsoleOpen = true,
}

Event.Hook("Console_inputstate", function() 
	
	Shared.Message("Input State Dump:")
	
	Shared.Message("ActiveKeybindGroups")
	
	if(#KeybindMapper.OverrideGroups == 0) then
		Shared.Message("None")
	else
		for i,group in ipairs(KeybindMapper.OverrideGroups) do
			Shared.Message(group.GroupName)
		end
	end
	
	Shared.Message("\nState Varibles")
	
	for varname,_ in pairs(StateVars) do
		if(KeybindMapper[varname]) then
			Shared.Message(varname.." = true")
		else
			Shared.Message(varname.." = false")
		end
	end
	
	Shared.Message("Input Bits Set")
	
	local itemFound = false
	
	for _,bitname in ipairs(MoveEnum) do
		if(bit.band(KeybindMapper.MoveInputBitFlags, Move[bitname]) ~= 0) then
			Shared.Message(bitname)
			itemFound = true
		end
	end
	
	if(not itemFound) then
		Shared.Message("None")
	end
	
	Shared.Message("\nRunning Actions")
	if(#KeybindMapper.RunningActions ~= 0) then
		for i,action in ipairs(KeybindMapper.RunningActions) do
			Shared.Message(action.ID)
		end
	else
		Shared.Message("None")
	end
	
	local vector = KeybindMapper.MovementVector
	
	Shared.Message(string.format("\nMove Vector\n	%i,%i,%i", vector.x, vector.y, vector.z))
end)


function DumpBinds()
	for key,bind in pairs(KeyBindInfo:GetGlobalBoundKeys()) do
		Shared.Message(key.." = "..bind)
	end
end

Event.Hook("Console_dumpbinds", DumpBinds)
