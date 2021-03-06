//
//   Created by:   fsfod
//

--[[
Notes


Public functions:
  string:replacedBind SetKeybind(string keyName, string BindName [integer keyIndex])
  string:boundKey, [string:groupName, bool:IsOverride] GetBindinfo(string bindname)
  bool IsKeyBound(string keyName)
  string GetBoundKey(string bindName [,integer keyIndex])
  string GetBindSetToKey(string keyName)
  void UnbindKey(string KeyName)
  void ClearBind(string BindName [,integer keyIndex])
  
  table GetGlobalBoundKeys() table format  {key = bindname}
  
  void SetConsoleCmdBind(string keyName, string consoleCommand)
  table GetConsoleCmdBoundKeys() table format  {keyName = consoleCmdString}
  string,IsBind:bool GetKeyInfo(string keyName)
  
  bool IsBindOverrider(string bindName)
  
  bool KeybindGroupExists(stirng groupName)
  table GetGroupBoundKeys(string groupName)
  string GetBoundKeyGroup(string keyName, string groupName)
  string:groupname GetBindsGroup(stirng bindName)
  bool GetIsGroupForClass(string groupName, string className)
  
  table(array of group names) GetKeybindGroupsForOverrideGroup(string overrideGroup)
]]--

if(not KeyBindInfo) then

KeyBindInfo = {
  Loaded = false,
  KeybindEntrys = {},
  RegisteredKeybinds = {},
  KeybindNameToKey = {},
  KeybindToGroup = {},
  BoundConsoleCmds = {},
  BoundKeys = {}, --stores the maping of a key to a keybindname. Override bind keys never get put in this table
  
  KeyBindsChangedCallsbacks = {},

  GroupLookup = {},
  GroupList = {}, --we need this so we have an ordered list of keybind groups when deciding default keys
  LogLevel = 1,
}

end

KeyBindInfo.ModifierKeys = {
  LeftShift = true,
  RightShift = true,
  LeftControl = true,
  RightControl = true,
  LeftAlt = true,
  RightAlt = true,
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
      {"Crouch", "Crouch", "Control"},
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
      {"ToggleFlashlight", "Toggle Flashlight", "F"},
      {"Taunt", "Taunt", "Q"},
      {"ShowMap", "Show MiniMap", "C"},
      {"ToggleVoteMenu", "Vote menu" , "V"},
      {"VoiceChat", "Use microphone", "Alt"},
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
      {"LastWeapon", "Last used weapon", ""},
      {"RequestMenu", "X"},
      {"RequestHealth", "Q"},
      {"RequestAmmo", "Z"},
      {"RequestOrder", "H"},
      {"PingLocation", "MouseButton2"},
    }
}

KeyBindInfo.MiscKeybinds = {
    Name = "Misc",
    Keybinds = {
      //{"ToggleThirdPerson",  "Toggle Third Person View", ""},
      {"JoinMarines",    "Join Marines",         "F1"},
      {"JoinAliens",     "Join Aliens",          "F2"},
      {"JoinRandom",     "Join Random Team",     "F3"},
      {"ReadyRoom",      "Return to Ready Room", "F4"},
      {"ToggleConsole",  "Toggle Console",       "Grave"},
      {"Exit",           "Open Main Menu",       "Escape"},
    }
}

KeyBindInfo.CommanderShared = {
    Name = "CommanderShared",
    Class = "Commander",
    Label = "Commander Shared Overrides",
    
    Keybinds = {
      {"ExitCommandStructure", "Exit Hive/CC", ""},
      {"NextIdleWorker", "Select Next Idle Worker", "H"},
      {"ScrollForward",   "Scroll View Forward",  "Up"},
      {"ScrollBackward",   "Scroll View Backward",  "Down"},
      {"ScrollLeft",  "Scroll View Left", "Left"},
      {"ScrollRight", "Scroll View Right", "Right"},
    }
}


KeyBindInfo.CommanderHotKeys = {
    Name = "CommanderHotKeys",
    Class = "Commander",
    Label = "Commander Hot Keys",

    Keybinds = {
      {"CommHotKey1", "HotKey 1", "Q"},
      {"CommHotKey2", "HotKey 2", "W"},
      {"CommHotKey3", "HotKey 3", "E"},
      {"CommHotKey4", "HotKey 4", "R"},
      
      {"CommHotKey5", "HotKey 5",  "A"},
      {"CommHotKey6", "HotKey 6",  "S"},
      {"CommHotKey7",  "HotKey 7", "D"},
      {"CommHotKey8", "HotKey 8", "F"},

      {"CommHotKey9", "HotKey 9",  "Z"},
      {"CommHotKey10", "HotKey 10", "X"},
      {"CommHotKey11", "HotKey 11", "C"},
      {"CommHotKey12", "HotKey 12", "V"},
    }
}

KeyBindInfo.MarineCommander = {
    Name = "MarineCommander",
    Team = "Marine",
    Class = "Commander",
    Label = "Marine Commander Overrides",  
    
    Keybinds = {
      {"DropAmmo",  "Drop Ammo Pack", "N"},
      {"DropHealth", "Drop Health Pack", "M"},
      {"NanoShield", "Nano Shield", ""},
      {"NanoConstruct", "Nano Construct", ""},
      {"Scan", "Scan", ""},
    }
}

KeyBindInfo.AlienCommander = {
    Name = "AlienCommander",
    Team = "Alien",
    Class = "Commander",
    Label = "Alien Commander Overrides",  

    Keybinds = {
      {"DropCyst",  "Drop Cyst", ""},
      {"Catalyze",  "Nutrient Mist", ""},
    }
}

KeyBindInfo.MarineSayings = {
    Name = "MarineSayings",
    Team = "Marine",
    ExcludeClass = {Commander = true},
    Label = "Marine Request Sayings",  

    Keybinds = {
      {"Saying_Acknowledge",  "Acknowledged", ""},
      {"Saying_NeedMedpack", "Need medpack", ""},
      {"Saying_NeedAmmo", "Need ammo", ""},
      {"Saying_NeedOrder", "Need orders", ""},

      {"Saying_FollowMe",  "Follow me", ""},
      {"Saying_LetsMove", "Let's move", ""},
      {"Saying_CoveringYou", "Covering you", ""},
      {"Saying_Hostiles", "Hostiles", ""},
      {"Saying_Taunt", "Taunt", ""},
    }
}

KeyBindInfo.AlienSayings = {
    Name = "AlienSayings",
    Team = "Alien",
    ExcludeClass = {Commander = true},
    Label = "Alien Sayings",  
    
    Keybinds = {
      {"Saying_Needhealing",  "Need healing", ""},
      {"Saying_Followme", "Follow me", ""},
      {"Saying_Chuckle", "Chuckle", ""},
    }
}

KeyBindInfo.MarineBuy = {
    Name = "MarineBuy",
    Team = "Marine",
    ExcludeClass = {Commander = true},
    Label = "Marine Buy",  

    Keybinds = {
      {"Buy_Shotgun",            "Shotgun", ""},           
      {"Buy_Welder",             "Welder", ""},            
      {"Buy_LayMines",           "Mines",  ""},         
      {"Buy_GrenadeLauncher",    "GrenadeLauncher",  ""},  
      {"Buy_Flamethrower",       "Flamethrower", ""},     
      {"Buy_Jetpack",            "Jetpack", ""},          
      {"Buy_Exosuit",            "Exosuit", ""},        
      {"Buy_DualMinigunExosuit", "DualMinigunExosuit", ""},
      {"Buy_Axe",                "Axe",  ""},              
      {"Buy_Pistol",             "Pistol", ""},            
      {"Buy_Rifle",              "Rifle",  ""}, 
    }
}

KeyBindInfo.AlienBuy = {
    Name = "AlienBuy",
    Team = "Alien",
    ExcludeClass = {Commander = true},
    Label = "Alien Buy",  

    Keybinds = {
      {"Buy_Skulk", "Skulk", ""},
      {"Buy_Gorge", "Gorge", ""},
      {"Buy_Lerk",  "Lerk",  ""},
      {"Buy_Fade",  "Fade",  ""},
      {"Buy_Onos",  "Onos", ""}, 
      

      {"Buy_Carapace", "Carapace", ""},
      {"Buy_Regeneration", "Regeneration", ""},
      {"Buy_Silence", "Silence", ""},
      {"Buy_Camouflage", "Camouflage", ""},
      {"Buy_Feint", "Feint", ""},
      {"Buy_Celerity", "Celerity", ""},
      {"Buy_Adrenaline", "Adrenaline", ""},
      {"Buy_HyperMutation", "HyperMutation", ""},
    }
}


KeyBindInfo.EngineProcessed = {
  ToggleConsole = true,
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
  ShowMap = true,
}

function KeyBindInfo:Init()
  
  if(not self.Loaded) then
    self.ConfigPath = "input/"
    
    self:AddDefaultKeybindGroups()
    
    if(StartupLoader.LoadCompleted) then
      self:ReloadKeyBindInfo()
    end
  end
end

function KeyBindInfo:ReloadKeyBindInfo(returnChanges)  
  //self.KeybindNameToKey = {}
  self.BoundKeys = {}
  self.BoundConsoleCmds = {}
  self.BindConflicts = {}
  self.OrphanedBinds = {}

  self:LoadAndValidateSavedKeyBinds()
  self.Loaded = true
  self.LazyLoad = nil
end

function KeyBindInfo:IsOverrideGroup(group)
  
  if(type(group) == "string") then
    group = self.GroupLookup[group]
  end
  
  return group.Class ~= nil or group.Team ~= nil
end
  
function KeyBindInfo:Load_NewConfig(keybindList)

  for bindName,keyEntry in pairs(keybindList) do
    
    local group = self.KeybindToGroup[bindName]
    
    if(group) then
      
      if(type(keyEntry) == "string") then
        //only keep a record of bound keys for keybinds that dont belong to an override group
        if(not group.OverrideGroup) then
          self.BoundKeys[keyEntry] = bindName
        end
      else
        
        assert(type(keyEntry) == "table")
        
        //only keep a record of bound keys for keybinds that dont belong to an override group
        if(not group.OverrideGroup) then
          for i,key in pairs(keyEntry) do
            if(i ~= "KeyCount") then
              self.BoundKeys[key] = bindName
            end
          end
        end
      end
      
    else
      self.OrphanedBinds[bindName] = key
    end
    
  end
end

function KeyBindInfo:ResetKeybinds()

  self.BoundKeys = {}
  self.KeybindNameToKey = {}

  for _,bindgroup in ipairs(self.GroupList) do
    local isInOverrideGroup = bindgroup.OverrideGroup
    
    for _,bind in ipairs(bindgroup.Keybinds) do
      local key = bind[3]
      
      if(key and key ~= "" and not bindList[key]) then
        self:SaveKeybind(bind[1], key, 1, isInOverrideGroup)
      end
    end
  end

  self:ReloadKeyBindInfo()
  self:OnBindingsChanged()
end

function KeyBindInfo:FillInFreeDefaults()
  
  for _,bindgroup in ipairs(self.GroupList) do
    local IsOverrideGroup = bindgroup.OverrideGroup
    
    for _,bind in ipairs(bindgroup.Keybinds) do
      local bindname = bind[1]
      local defaultKey = bind[3] or ""

      if(defaultKey ~= "" and (IsOverrideGroup or (not self:GetBoundKey(bindname) and not self:IsKeyBound(defaultKey)) )) then
        self:SaveKeybind(bindname, defaultKey, nil, IsOverrideGroup)
      end
    end
  end
end

function KeyBindInfo:AddDefaultKeybindGroups()
  
  self:AddKeybindGroup(self.MovementKeybinds)
  
  self:AddKeybindGroup(self.ActionKeybinds)

  self:AddKeybindGroup(self.MiscKeybinds)
  
  self:AddKeybindGroup(self.AlienSayings)
  self:AddKeybindGroup(self.MarineSayings) 
  self:AddKeybindGroup(self.MarineBuy)
  self:AddKeybindGroup(self.AlienBuy)    
  
  self:AddKeybindGroup(self.CommanderShared)
  self:AddKeybindGroup(self.MarineCommander)
  self:AddKeybindGroup(self.AlienCommander)
  self:AddKeybindGroup(self.CommanderHotKeys)  
end

//team can optionally be nil
//if a group does not both specify a team and a class 
function KeyBindInfo:GetMatchingOverrideGroups(class, team)

  assert(team or class, "either a team or class or both must be passed in")
  assert(not team or type(team) == "string")
  assert(type(class) == "string")
  
  local groupNames = {}

  for i,group in ipairs(self.GroupList) do
        
    //We skip non override groups that are also in the list
    if(self:IsOverrideGroup(group)) then
      
      local matchsTeam = team and team == group.Team      
      local matchsClass = class == group.Class and (not group.ExcludeClass or not group.ExcludeClass[class])
      
      //we match 1. groups that 
      if((matchsTeam and (matchsClass or not group.Class)) or
         (matchsClass and (not team or not group.Team)) then
          
        groupNames[#groupNames+1] = {matchsClass, matchsTeam, i, group.Name}
      end
    end
  end
  
  //group sorting order Groups that specifed a Class and Team first, groups that just specifed Class next, then groups that just specifed a Team
  //those 3 sub groups are then sorted based on the order they were registed with keybinfo which is the same order they are displayed in the binding option page
  table.sort(groupNames, function(group1, group2)
    return (group1[1] and not group2[1]) or (group1[2] and not group2[2]) or group1[3] > group2[3]
  end)
  
  //convert back to group
  for i,v in ipairs(groupNames) do
    groupNames[i] = v[4]
  end
  
  return groupNames
end

function KeyBindInfo:OnBindingsUIEntered()
  self.KeyBindSnapshot = self:GetKeyBindSnapshot()
end

function KeyBindInfo:OnBindingsUIExited()

  if(self.KeyBindSnapshot) then
    local changes, changedCmds = self:GetChangedKeybinds(self.KeyBindSnapshot)

    if(next(changes) or (changedCmd and next(changedCmd))) then
      self:OnBindingsChanged()
    end

    self.KeyBindSnapshot = nil
  end
end

--
function KeyBindInfo:AddKeybindGroup(keybindGroup)
  
  table.insert(self.GroupList, keybindGroup)

  self.GroupLookup[keybindGroup.Name] = keybindGroup

  for _,keybind in ipairs(keybindGroup.Keybinds) do
    self.KeybindToGroup[keybind[1]] = keybindGroup
    self.RegisteredKeybinds[keybind[1]] = keybind

    self.KeybindEntrys[#self.KeybindEntrys+1] = keybind
  end
end

function KeyBindInfo:LoadAndValidateSavedKeyBinds()
  
  local config = LoadConfigFile("keybinds.json")
  
  if(not config) then
    self:FillInFreeDefaults()
    self:SaveChanges()
  else
    self.KeybindNameToKey = config.keybinds
  end
  
  
  self:Load_NewConfig(self.KeybindNameToKey)

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
  "ShowMap",
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
  "VoiceChat",
  "ToggleVoteMenu",
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
        self:SaveKeybind(bindname, key, 1)
        importCount = importCount+1
      else
        Print("KeyBindInfo: ImportKeys skipped importing %s because another bind was set to the same key", bindname)
      end
    end
  end
  
  Shared.Message("Sucessfuly imported "..importCount.." keybinds.")
end

function KeyBindInfo:SaveKeybind(bindName, key, keyIndex, isOverrideKey)

  assert(type(key) == "string" or key == false)

  key = key or nil  

  local keyEntry = self.KeybindNameToKey[bindName]

  keyIndex = keyIndex or 1

  if(keyEntry == nil or type(keyEntry) == "string") then
    
    if(keyIndex == 1 or keyIndex == -1) then
      self.KeybindNameToKey[bindName] = key
    else
 
      local newEntry = {
        keyEntry, 
        KeyCount = (keyEntry ~= nil and 2) or 1
      }
      newEntry[keyIndex] = key
      
      self.KeybindNameToKey[bindName] = newEntry
    end
  else

    local keyCount = keyEntry.KeyCount

    if(keyIndex == -1) then 
      table.insert(keyEntry, key)
    else
 
      if(not keyEntry[keyIndex] and key) then
        keyEntry.KeyCount = keyCount+1
      elseif(keyEntry[keyIndex] and not key) then
        keyEntry.KeyCount = keyCount-1
        
        //don't keep around empty tables
        if(keyCount-1 < 1) then
          self.KeybindNameToKey[bindName] = nil
        end
      end
      
      keyEntry[keyIndex] = key
    end
  end

  if(key and not isOverrideKey) then
    self.BoundKeys[key] = (key and bindName) or nil
  end
  
  if(self.BindConflicts[bindName]) then
    self.BindConflicts[bindName] = nil
  end
end

local bindingsFileName = "ConsoleBindings.json"

function KeyBindInfo:LoadConsoleCmdBinds()
  
  // Load the bindings from file if the file exists.
  self.BoundConsoleCmds = LoadConfigFile(bindingsFileName) or { }
end

function KeyBindInfo:SetConsoleCmdBind(key, cmdstring)

  local OldBindorCmd, IsBind = self:GetKeyInfo(key)

  if(OldBindorCmd) then
    self:UnbindKey(key)
  end

  self.BoundConsoleCmds[key] = cmdstring

  self:SaveConsoleCmdKeyList()
  self:OnBindingsChanged(true)
end

local function GetKeyIndex(keyValue, key)

  if(type(keyValue) ~= "table") then
    return (keyValue == key and 1) or nil
  else

    for i,keyEntry in pairs(keyValue) do
      if(keyEntry == key) then
        return i
      end
    end
  end
  
  return nil
end

function KeyBindInfo:GetKeyInfo(key)
  
  local bindName = self.BoundKeys[key]
  
  if(bindName) then
    return bindName, true, GetKeyIndex(self.KeybindNameToKey[bindName], key)
  elseif(self.BoundConsoleCmds[key]) then
    return self.BoundConsoleCmds[key], false
  end
  
  return nil, false
end

function KeyBindInfo:ClearConsoleCmdBind(key)

  self.BoundConsoleCmds[key] = nil
  Client.SetOptionString("Keybinds/ConsoleCmds/"..key, "")

  self:SaveConsoleCmdKeyList()
  
  self:OnBindingsChanged(true)
end

function KeyBindInfo:SaveConsoleCmdKeyList()

  for key,consoleCmd in pairs(self.BoundConsoleCmds) do
    keylist[#keylist+1] = key
  end
end

function KeyBindInfo:GetBindingDialogTable()
  if(not self.Loaded) then
    self:Init()
  end

  if(not self.BindingDialogTable) then
    local bindTable = {}
    local index = 1

    for _,bindgroup in ipairs(self.GroupList) do
      if(not bindgroup.Hidden) then
        bindTable[index] = bindgroup
        index = index+1
        
        for _,bind in ipairs(bindgroup.Keybinds) do
          bindTable[index] = bind          
           index = index+1
        end
      end
    end
    
    self.BindingDialogTable = bindTable
  end

  return self.BindingDialogTable
end

function KeyBindInfo:GetBoundKey(keybindname, keyIndex)

  if(self.RegisteredKeybinds[keybindname] == nil) then
    error("GetBoundKey: keybind called \""..(keybindname or "nil").."\" does not exist")
  end

  local keyValue = self.KeybindNameToKey[keybindname]

  keyIndex = keyIndex or 1

  if(not keyValue or type(keyValue) == "string") then
    return (keyIndex == 1 and keyValue) or nil
  else
    return keyValue[keyIndex]
  end
end

function KeyBindInfo:GetGlobalBoundKeys()
  return self.BoundKeys
end

function KeyBindInfo:GetConsoleCmdBoundKeys()
  return self.BoundConsoleCmds
end

function KeyBindInfo:IsBindOverrider(keybindname)
  
  local group = self.KeybindToGroup[keybindname]
  
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
  assert(key)
  
  local group = self.GroupLookup[groupName]
  assert(group)

  for _,bindinfo in ipairs(group.Keybinds) do
    local keyIndex = GetKeyIndex(self.KeybindNameToKey[bindinfo[1]], key)

    if(keyIndex) then
      return bindinfo[1], keyIndex
    end
  end

  return nil
end


function KeyBindInfo:GetBindinfo(bindname)
  
  local group = self.KeybindToGroup[bindname]
  
  if(group == nil) then
    error("GetBindinfo: keybind called \""..(bindname or "nil").."\" does not exist")
  end
  
  return self.KeybindNameToKey[bindname], group.Name, group.OverrideGroup
end

function KeyBindInfo:GetBindsGroup(bindname)
  return self.KeybindToGroup[bindname].Name
end

function KeyBindInfo:GetIsGroupForClass(groupName, className)
  
  assert(type(groupName) == "string")
  
  local group = self.GroupLookup[groupName]
  
  if(group == nil) then
    error("keybind group"..groupName.." does not exist")
  end
  
  return group.Class == className
end

function KeyBindInfo:CheckIsConflicSolved(changedKey)
  
  local found = false
  
  for bindname,key in pairs(self.BindConflicts) do
    if(key == changedKey) then
      --we found 2 binds with the same key so theres stil a conflict
      if(found) then
        return false
      end
      
      found = true
    end
  end
  
  return true
end


function KeyBindInfo:SetKeybindWithModifier(key, modifierKey, bindname, keyIndex)
  assert(modifierKey and self.ModifierKeys[modifierKey], "invalid modifer keyname")
  
  local compiledKey = modifierKey.."-"..key
  
  return self:SetKeybind(compiledKey, bindname, keyIndex)
end

function KeyBindInfo:SetKeybind(key, bindname, keyIndex)

  local clearedBind

  if(self.RegisteredKeybinds[bindname] == nil) then
    error("SetKeyBind: keybind called \""..bindname.."\" does not exist")
  end
  
  local changes, CmdChanges
  local IsOverride = self:IsBindOverrider(bindname)


  if(not IsOverride) then
    local oldBindKey = self:GetBoundKey(bindname, keyIndex)
    
    if(oldBindKey == key) then
       --just do nothing since were just binding the same key to the bind
      return
    end
    
    --if the keybind had a key already set to it clear the record of it in our BoundKeys table
    if(oldBindKey) then
      self.BoundKeys[oldBindKey] = nil
    end
    
    local clearedBindOrCmd, IsBind, clearedKeyIndex = self:GetKeyInfo(key)
    
    --if something else was already bound to this key clear it
    if(clearedBindOrCmd) then
      //if(IsBind and #self.BindConflicts ~= 0) then
      //  self:CheckIsConflicSolved()
      //end
      
      if(IsBind) then
        clearedBind = clearedBindOrCmd
      else
        CmdChanges = true
      end

      self:UnbindKey(key)
    end
  else
    --check to see this key is not bound to something else in this override group
    local group = self.KeybindToGroup[bindname]
    local groupbind, bindKeyIndex  = self:GetBoundKeyGroup(key, group.Name)
    
    if(groupbind) then
      self:ClearBind(groupbind, bindKeyIndex)
    end
    
    clearedBind = groupbind
  end

  self:SaveKeybind(bindname, key, keyIndex, IsOverride)

  self:OnBindingsChanged()
  
  return clearedBind
end

function KeyBindInfo:SaveChanges()
  SaveConfigFile("keybinds.json", {
    keybinds = self.KeybindNameToKey
  })
end

function KeyBindInfo:UnbindKey(key)

  local bindName, IsBind, keyIndex = self:GetKeyInfo(key)

  if(not bindName) then
      self:Log(1, "\""..key.."\" is already unbound")
    return
  end

  if(IsBind) then    
    self:ClearBind(bindName, keyIndex)
  else
    self:ClearConsoleCmdBind(key)
  end
end

function KeyBindInfo:ClearBind(bindName, keyIndex)

  local IsOverride = self:IsBindOverrider(bindName)

  local key = self.KeybindNameToKey[bindName]

  if(key == nil) then
    self:Log(1, "\""..bindName.."\" is already unbound")
  else
    if(not IsOverride) then
      self.BoundKeys[key] = nil
    end

    self:SaveKeybind(bindName, false, keyIndex, IsOverride)

    self:OnBindingsChanged()
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


function KeyBindInfo:KeybindGroupExists(groupname)
  return self.GroupLookup[groupname] ~= nil
end

function KeyBindInfo:GetGroupBoundKeys(groupname)

  if(not self:KeybindGroupExists(groupname)) then
    error("KeyBindInfo:GetGroupBoundKeys group \""..groupname.."\" does not exist")    
  end

  local keybinds = {}

    for _,bindinfo in ipairs(self.GroupLookup[groupname].Keybinds) do
      local keyEntry = self.KeybindNameToKey[bindinfo[1]]

      if(keyEntry) then
        if(type(keyEntry) == "string") then
          keybinds[keyEntry] = bindinfo[1]
        else
          //more than one key is set to this bind 
          for i,key in pairs(keyEntry) do
            if(i ~= "KeyCount") then
              keybinds[key] = bindinfo[1]
            end
          end
        end
        
      end
    end

  return keybinds
end

function KeyBindInfo:ResetOverrideGroup(overrideGroup)
  
  local Group = self.GroupLookup[overrideGroup]
  
  if(not Group) then
    error("ResetOverrideGroup no group named "..overrideGroup.." exists.")
  end
  
  for _,bind in ipairs(Group.Keybinds) do
    local key = bind[3]
    
    //if this keybind has a default key specifed thats the third array value set it
    if(key and key ~= "") then
      self:SaveKeybind(bind[1], key or "", 1, true)
    end
  end
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

function KeyBindInfo:OnBindingsChanged(ConsoleCmdChanges)
  
  self:SaveChanges()
  
  ConsoleCmdChanges = ConsoleCmdChanges or {}
  
  for _,hook in ipairs(self.KeyBindsChangedCallsbacks) do
    hook[2](hook[1], ConsoleCmdChanges)
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

function KeyBindInfo:FindBind(name)
  
  local uppername = name:upper()

  for bindname,_ in pairs(self.RegisteredKeybinds) do
    if(uppername == bindname:upper()) then
      return bindname
    end
  end
  
  return nil
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



function KeyBindInfo:LogBindConflic(bindname, key, boundbind)
  self.BindConflicts[bindname] = key
  
  Print(string.format("ignoreing \"%s\" bind because \"%s\" is already bound to the same key which is \"%s\"", bindname, boundbind, key))
end

---------------------Old Config System----------------------------------------

function KeyBindInfo:Load_OldConfig()
  
  for _,bindgroup in ipairs(self.GroupList) do
    if(bindgroup.OverrideGroup) then
      self:LoadOverrideGroup(bindgroup)
    else
      self:LoadGroup(bindgroup)
    end
  end
  
end

function KeyBindInfo:InternalBindKey(key, bindname, isOverrideKey)
  
  if(not isOverrideKey) then
    self.BoundKeys[key] = bindname
  end

  self.KeybindNameToKey[bindname] = key
end

function KeyBindInfo:LoadGroup(bindgroup)
  
  for _,bindinfo in ipairs(bindgroup.Keybinds) do
    local key = Client.GetOptionString(self.ConfigPath..bindinfo[1], "")
    --key JoystickButton10 is our tombstone value
    if(key ~= "" and key ~= "JoystickButton10") then
      if(self:IsKeyBound(key)) then
        self:LogBindConflic(bindinfo[1], key, self.BoundKeys[key])
      else
        self:InternalBindKey(key, bindinfo[1])
        //self.KeybindNameToKey[key] = bindinfo[1]
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


function KeyBindInfo_FillInBindKeys(s)
  --can't just return the result directly cause gsub returns a number as well
  local s = string.gsub(s, "(@[^@]+@)", BindReplacer)
  return s
end