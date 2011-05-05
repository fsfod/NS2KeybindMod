
local hotreload = ClassHooker:Mixin("KeybindMapper")

if(not hotreload) then
	Event.Hook("UpdateClient", function()

	local player = Client.GetLocalPlayer()
	
	if(not player) then
		if(KeybindMapper.CurrentPlayerClass) then
			KeybindMapper:PlayerClassChanged(nil)
		end
	else
		if(KeybindMapper.CurrentPlayerClass ~= player:GetClassName()) then
			KeybindMapper:PlayerClassChanged(player)
		end
	end
 end)
end

function KeybindMapper:SetupHooks()
	self:RawHookClassFunction("Commander", "OverrideInput", "OverrideInput_Hook")
	self:HookClassFunction("Commander", "OnInitLocalClient", "OnCommander")
	self:HookClassFunction("Armory", "OnUse", "ArmoryBuy_Hook")

	self:RawHookClassFunction("Player", "OverrideInput", "OverrideInput_Hook")
	self:HookClassFunction("Player", "CloseMenu", "CloseMenu_Hook")
	
	self:RawHookClassFunction("Marine", "CloseMenu", "MarineCloseMenu_Hook")
	self:PostHookClassFunction("Alien", "Buy", "AlienBuy_Hook")
	
	ClassHooker:SetClassCreatedIn("GUIFeedback", "lua/GUIFeedback.lua")
	self:PostHookClassFunction("GUIFeedback", "Initialize", "GUIFeedbackCreated")

	LoadTracker:HookFileLoadFinished("lua/GUIFeedback.lua", self, "FixUpGUIFeedback")
	
	self:HookFunction("RemoveFlashPlayer", "CheckAlienBuyClose")
	self:HookFunction("ShowInGameMenu", "InGameMenuOpened")
	self:HookFunction("ChatUI_SubmitChatMessageBody", "ChatClosed")
	
	self:HookFunction("MainMenu_ReturnToGame", "InGameMenuClosed")
	
	ClassHooker:SetClassCreatedIn("GUIManager", "lua/GUIManager.lua")
	self:HookClassFunction("GUIManager", "SendKeyEvent", "Pre_SendKeyEvent"):SetPassHandle(true)
	self:PostHookClassFunction("GUIManager", "SendKeyEvent", "Post_SendKeyEvent"):SetPassHandle(true)
end


function KeybindMapper:CheckAlienBuyClose(index)
	if(index == kClassFlashIndex and self.BuyMenuOpen) then
		self:BuyMenuClosed()
	end
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
			selfArg.feedbackText:SetText(KeyBindInfo_FillInBindKeys("Press @OpenFeedback@ to give us feedback"))
			local key = KeyBindInfo:GetBoundKey("OpenFeedback")
			
			selfArg.OpenFeedbackKey = (key and InputKey[key]) or false
   	end
	end
end

function KeybindMapper:GUIFeedbackCreated(selfArg)
	
	local key = KeyBindInfo:GetBoundKey("OpenFeedback")
			
	selfArg.OpenFeedbackKey = (key and InputKey[key]) or false
	
	selfArg.feedbackText:SetText(KeyBindInfo_FillInBindKeys("Press @OpenFeedback@ to give us feedback"))
	
	KeyBindInfo:RegisterForKeyBindChanges(selfArg, "OnKeybindsChanged")
end

function KeybindMapper:ArmoryBuy_Hook(objSelf, player, elapsedTime, useAttachPoint)
  if (objSelf:GetIsBuilt() and objSelf:GetIsActive() and not Client.GetMouseVisible() and Client.GetLocalPlayer() == player) then
  	self:BuyMenuOpened()
  end
end
 
function KeybindMapper:AlienBuy_Hook(entitySelf)
	if(entitySelf.showingBuyMenu) then
		self:BuyMenuOpened()
	else
		self:BuyMenuClosed()
	end
end

function KeybindMapper:OverrideInput_Hook(entitySelf, input)
		self:InputTick()
		self:FillInMove(input, entitySelf:isa("Commander"))
	return input
end

function KeybindMapper:MarineCloseMenu_Hook(entitySelf, flashIndex)
	
	--add missing detault behavior
	if flashIndex == nil and gFlashPlayers ~= nil then
    -- Close top-level menu if not specified
    flashIndex = table.maxn(gFlashPlayers)
  end

	if(flashIndex == kClassFlashIndex) then
		if(self.BuyMenuOpen) then
			self:BuyMenuClosed()
		end
	end

	return flashIndex
end

function KeybindMapper:CloseMenu_Hook(entitySelf, menuIndex)

	if(menuIndex == kClassFlashIndex) then
		if(self.BuyMenuOpen) then
			self:BuyMenuClosed()
		end
	end

end

function KeybindMapper:Pre_SendKeyEvent(HookHandle, _, key, down)
 	local handled

	if(self.IsShutDown) then
		return false
	end

	if(self.IsCommander and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1)) then
		return false
	end

	if(key ~= InputKey.MouseX and key ~= InputKey.MouseY) then 
		local keystring  = InputKeyHelper:ConvertToKeyName(key)

		if(down) then
 			handled = self:OnKeyDown(keystring)
		else
			handled = self:OnKeyUp(keystring)
		end
	end

	if(handled) then
		HookHandle:SetReturn(true)
		HookHandle:BlockOrignalCall()
	end
end

function KeybindMapper:Post_SendKeyEvent(HookHandle, _, key)

	if(self.IsShutDown or key == InputKey.MouseX or key == InputKey.MouseY) then
		return false
	end

	local handled = HookHandle:GetReturn()

	if(not handled) then
		local keystring = InputKeyHelper:ConvertToKeyName(key)

		HookHandle:SetReturn(not self:CanKeyFallThrough(keystring))
	end
end

--bam hot reloading hooks ClassHooker:Mixin nukes all our old ones
if(hotreload) then
 KeybindMapper:SetupHooks()
end
 
Print("Hooks Loaded")