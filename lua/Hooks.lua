Script.Load("lua/ClassHooker.lua")


ClassHooker:Mixin("KeybindMapper")

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

local Hooked = false

Event.Hook("MapPostLoad", function()
	
	if(Hooked) then
		return
	end
	
	local oldRemoveFlashPlayer = RemoveFlashPlayer
	RemoveFlashPlayer = function(index)
		if(index == kClassFlashIndex and KeybindMapper.BuyMenuOpen) then
			KeybindMapper:BuyMenuClosed()
		end
		oldRemoveFlashPlayer(index)
	end
		
	
	local oldShowInGameMenu = ShowInGameMenu
	
	ShowInGameMenu = function()
    if not Client.GetIsRunningPrediction() then
      KeybindMapper:InGameMenuOpened()
    end
    oldShowInGameMenu()
	end

	oldReturnToGame = MainMenu_ReturnToGame

	MainMenu_ReturnToGame = function()
		KeybindMapper:InGameMenuClosed(ChangedKeybinds)
    ChangedKeybinds = false
    	
		oldReturnToGame()
	end
--[[
	local oldLeaveMenu = LeaveMenu
	LeaveMenu = function()
		if(Client.GetIsConnected()) then
			KeybindMapper:InGameMenuClosed()
		end
		oldLeaveMenu()
	end
]]--

	local oldSubmitChatMessageBody = ChatUI_SubmitChatMessageBody	
	ChatUI_SubmitChatMessageBody = function(chatMessage)
		KeybindMapper:ChatClosed()
		oldSubmitChatMessageBody(chatMessage)
	end
	
	local SendKeyEvent = GUIManager.SendKeyEvent 
	
	GUIManager.SendKeyEvent = function(self, key, down)
 		local handled
		
		if(key ~= InputKey.MouseX and key ~= InputKey.MouseY) then 
			local keystring  = InputKeyHelper:ConvertToKeyName(key)

			if(down) then
 				handled = KeybindMapper:OnKeyDown(keystring)
			else
				handled = KeybindMapper:OnKeyUp(keystring)
			end
		else
			return false
		end

		if(not handled and not SendKeyEvent(self, key, down)) then
			return not KeybindMapper:CanKeyFallThrough(key)
		end
	end

	Hooked = true
end)

