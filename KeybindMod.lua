
KeybindMod = KeybindMod or {
  Keybinds = {}
}

function KeybindMod:ResetKeybindTable()
  self.Keybinds = {}
  return self.Keybinds
end

function KeybindMod:OnLoad()
	
	KeyBindInfo.KeybindNameToKey = self.Keybinds
	
	KeyBindInfo:Init()
	
	if(not StartupLoader.IsMainVM) then
	  KeybindMapper:Init()
	end
end

function KeybindMod:SaveKeybinds()
  self.SavedVaribles:Save()
end

function KeybindMod:OnClientLoadComplete()
  
  KeyBindInfo:ReloadKeyBindInfo()
  KeybindMapper:RefreshInputKeybinds()
end

function KeybindMod:OnClientLuaFinished()

  BindingsUI_GetInputValue = function(controlId) 
    return KeyBindInfo:GetBoundKey(controlId)
  end
end