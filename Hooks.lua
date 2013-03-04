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
	
	ClassHooker:SetClassCreatedIn("GUIFeedback", "lua/GUIFeedback.lua")
	self:PostHookClassFunction("GUIFeedback", "Initialize", "GUIFeedbackCreated")

	LoadTracker:HookFileLoadFinished("lua/GUIFeedback.lua", self, "FixUpGUIFeedback")

	self:HookFunction("MainMenu_Open", "InGameMenuOpened")
	self:HookFunction("ChatUI_SubmitChatMessageBody", "ChatClosed")
	
	self:HookFunction("MainMenu_ReturnToGame", "InGameMenuClosed")
	
	ClassHooker:SetClassCreatedIn("GUIManager", "lua/GUIManager.lua")
	self:HookFunction("MouseTracker_SendKeyEvent", "Pre_SendKeyEvent"):SetPassHandle(true)
	self:PostHookFunction("MouseTracker_SendKeyEvent", "Post_SendKeyEvent"):SetPassHandle(true)
		
	self:ReplaceFunction("ExitPressed", function() end)
end

function KeybindMapper:FixUpGUIFeedback()
	GUIFeedback.SendKeyEvent = function(selfArg, key, down)
    if down and key == selfArg.OpenFeedbackKey then
			ShowFeedbackPage()
     return true
    end
    return false
	end
	
	GUIFeedback.OnKeybindsChanged = function(selfArg,keyChanges)
   	if(keyChanges["OpenFeedback"]) then
			//selfArg.feedbackText:SetText(KeyBindInfo_FillInBindKeys("Press @OpenFeedback@ to give us feedback"))
			local key = KeyBindInfo:GetBoundKey("OpenFeedback")
			
			selfArg.OpenFeedbackKey = (key and InputKey[key]) or false
   	end
	end
end

function KeybindMapper:GUIFeedbackCreated(selfArg)
	
	local key = KeyBindInfo:GetBoundKey("OpenFeedback")
			
	selfArg.OpenFeedbackKey = (key and InputKey[key]) or false
	
	//selfArg.feedbackText:SetText(KeyBindInfo_FillInBindKeys("Press @OpenFeedback@ to give us feedback"))
	
	KeyBindInfo:RegisterForKeyBindChanges(selfArg, "OnKeybindsChanged")
end
 
function KeybindMapper:AlienBuy_Hook(entitySelf)
  if(entitySelf ~= Client.GetLocalPlayer()) then
    return
  end
  
	if(entitySelf.buyMenu) then
		self:BuyMenuOpened()
	else
	  if(self.BuyMenuOpen) then
		  self:BuyMenuClosed()
		end
	end
end

function KeybindMapper:OverrideInput_Hook(hookHandle, entitySelf, input)


	self:InputTick()
	self:FillInMove(input, entitySelf:isa("Commander"))
		
	return input
end


function KeybindMapper:Pre_SendKeyEvent(HookHandle, key, down, amount, IsRepeat)
 	local handled 
  
  --don't do anything if another hook has already handled it
	if(self.IsShutDown or HookHandle:GetReturn() or IsRepeat) then
		return
	end

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

	if(handled) then
		HookHandle:SetReturn(true)
		HookHandle:BlockOrignalCall()
	end
end

if(hotreload) then
 KeybindMapper:SetupHooks()
end