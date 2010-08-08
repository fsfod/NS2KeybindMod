--=============================================================================
--
-- lua/BindingsDialog.lua
-- 
-- Populate and manage key bindings in options screen.
--
-- Created by Henry Kropf and Charlie Cleveland
-- Copyright 2010, Unknown Worlds Entertainment
--
--=============================================================================

Script.Load("lua/BindingsShared.lua")

--highjack Main.SetMenu so we called in a place after MainMenu_ReturnToGame is declared 
--so we can then highjack MainMenu_ReturnToGame to set ChangedKeybinds option when the ingame menu is closed
local SetMenu = Main.SetMenu
Main.SetMenu = function(menupath)
	SetMenu(menupath)
	
	if(not oldReturnToGame) then
		oldReturnToGame = MainMenu_ReturnToGame
		
		MainMenu_ReturnToGame = function()
			if(#ChangedKeybinds ~= 0) then
    		Main.SetOptionString("Keybinds/Changed", table.concat(ChangedKeybinds, "@"))
    		table.clear(ChangedKeybinds)
    	else
    		Main.SetOptionString("Keybinds/Changed", "MenuClosed")
			end

			oldReturnToGame()
		end
	end
end


local specialKeys = {
    [" "] = "SPACE"
}

local UnboundKeyLabel = ""
local LazyLoadMode = true
ChangedKeybinds = {}

if(Main.GetOptionString("Keybinds/Changed", "") ~= "") then
	Main.SetOptionString("Keybinds/Changed", "")
end
--
-- Get the value of the input control
--/
function BindingsUI_GetInputValue(controlId)
	  
	  if(LazyLoadMode) then
	  	KeyBindInfo:Init()
	  	LazyLoadMode = false
	  end
	  
    return KeyBindInfo:GetBoundKey(controlId) or UnboundKeyLabel
end

--
-- Set the value of the input control
--/
function BindingsUI_SetInputValue(controlId, controlValue)
		
	if(LazyLoadMode) then
	 	KeyBindInfo:Init()
	  LazyLoadMode = false
	end
	  
  if(controlId ~= nil) then
		KeyBindInfo:SetKeybind(controlValue, controlId)
		
		if(Client) then
   		ChangedKeybinds[#ChangedKeybinds+1]	= controlId
		end
  end  
end

--
-- Return data in linear array of config elements
-- controlId, "input", name, value
-- controlId, "title", name, instructions
-- controlId, "separator", unused, unused
--/
function BindingsUI_GetBindingsData()
   return KeyBindInfo:GetBindingDialogTable()   
end

--
-- Returns list of control ids and text to display for each.
--/
function BindingsUI_GetBindingsTranslationData()

    local bindingsTranslationData = {}

    for i = 0, 255 do
    
        local text = string.upper(string.char(i))
        
        -- Add special values (must match any values in 'defaults' above)
        for j = 1, table.count(specialKeys) do
        
            if(specialKeys[j][1] == text) then
            
                text = specialKeys[j][2]
                
            end
            
        end
        
        table.insert(bindingsTranslationData, {i, text})
        
    end
    
    local tableData = table.tostring(bindingsTranslationData)
    
    return bindingsTranslationData
    
end

--
-- Called when bindings is exited and something was changed.
--/
function BindingsUI_ExitDialog()
    
    Main.ReloadKeyOptions()
    
    if(not Client and #ChangedKeybinds ~= 0) then
    	table.clear(ChangedKeybinds)
    	Main.SetOptionString("Keybinds/Changed", "")
    end
end
