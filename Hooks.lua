//
//   Created by:   fsfod
//

local hotreload = ClassHooker:Mixin("KeybindMapper")

if(not hotreload) then
  PlayerEvents:HookIsCommander(KeybindMapper, function(isCommander)
      
    if(isCommander) then 
      KeybindMapper:OnCommander()
    else
      KeybindMapper:OnUnCommander()
    end
  end)
  
  //PlayerEvents:HookClassChanged(KeybindMapper, "PlayerClassChanged")
end

function KeybindMapper:SetupHooks()
	self:HookClassFunction("Commander", "OnInitLocalClient", "OnCommander")
	
	self:HookFunction("MainMenu_Open", "InGameMenuOpened")
	self:HookFunction("ChatUI_SubmitChatMessageBody", "ChatClosed")
	
	self:HookFunction("MainMenu_ReturnToGame", "InGameMenuClosed")
	
	ClassHooker:SetClassCreatedIn("GUIManager", "lua/GUIManager.lua")
			
	self:ReplaceFunction("ExitPressed", function() end)
end


function New(hookHandle, entitySelf, input)


	KeybindMapper:InputTick()
	KeybindMapper:FillInMove(input, entitySelf:isa("Commander"))
		
	return input
end

/**
 * Called by the engine whenever a key is pressed or released. Return true if
 * the event should be stopped here.
 */
local function OnSendKeyEvent(key, down, amount, repeated)

    local stop = MouseTracker_SendKeyEvent(key, down, amount, keyEventBlocker ~= nil)
    
    if keyEventBlocker then
        return keyEventBlocker:SendKeyEvent(key, down, amount)
    end
    
    if not stop then
        stop = GetGUIManager():SendKeyEvent(key, down, amount)
    end
    
    if not stop then
    
        local winMan = GetWindowManager()
        if winMan then
            stop = winMan:SendKeyEvent(key, down, amount)
        end
        
    end
    
    if not stop then
    
        if not Client.GetMouseVisible() then
        
            if key == InputKey.MouseX then
                _cameraYaw = _cameraYaw - ApplyMouseAdjustments(amount)
            elseif key == InputKey.MouseY then
            
                local limit = math.pi / 2 + 0.0001
                _cameraPitch = Math.Clamp(_cameraPitch + ApplyMouseAdjustments(amount), -limit, limit)
                
            end
        end
        
        stop = KeybindMapper:SendKeyEvent(key, down, amount, repeated)
        
        // Filter out the OS key repeat for our general movement (but we'll use it for GUI).
        if not repeated then
            _keyState[key] = down
            if down and not moveInputBlocked then
                _keyPressed[key] = amount
            end
        end    
    
    end
    
    if not stop then
    
        local player = Client.GetLocalPlayer()
        if player then
            stop = player:SendKeyEvent(key, down)
        end
        
    end

    if not stop and down then
        ConsoleBindingsKeyPressed(key)
    end
    
    return stop
    
end


function KeybindMapper:SendKeyEvent(key, down, amount, IsRepeat)

  local handled = false

	if(key ~= InputKey.MouseX and key ~= InputKey.MouseY) then 
		local keystring = InputKeyHelper:ConvertToKeyName(key, down)

    if(self.IsCommander and self.CommanderPassthroughKeys[keystring]) then
      
      //for keys we pass through to the guisystem like shift for the commander map ping
      if(self.CommanderPassthroughKeys[keystring] ~= true) then
        return
      end
      
      local localPlayer = Client.GetLocalPlayer()

      localPlayer:SendKeyEvent(key, down)
      handled = true
      
    else
      
      if(down or key == InputKey.MouseZ) then
 			  handled = self:OnKeyDown(keystring)
		  else
			  handled = self:OnKeyUp(keystring)
		  end
      
    end
	end

	return handled
end

if(hotreload) then
 KeybindMapper:SetupHooks()
end