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
	self:RawHookClassFunction("Commander", "OverrideInput", "OverrideInput_Hook")
	self:HookClassFunction("Commander", "OnInitLocalClient", "OnCommander")

	self:RawHookClassFunction("Player", "OverrideInput", "OverrideInput_Hook")
	self:RawHookClassFunction("AlienSpectator", "OverrideInput", "OverrideInput_Hook")
	self:RawHookClassFunction("MarineSpectator", "OverrideInput", "OverrideInput_Hook")
	self:RawHookClassFunction("Embryo", "OverrideInput", "OverrideInput_Hook")
	self:ReplaceClassFunction("Embryo", "OverrideInput", "Embryo_OverrideInput")

	self:PostHookClassFunction("Marine", "CloseMenu",function(entitySelf)
    if(entitySelf == Client.GetLocalPlayer() and not entitySelf.showingBuyMenu and self.BuyMenuOpen) then
	    self:BuyMenuClosed()
    end
  end)

	self:PostHookClassFunction("Armory", "OnUse", function(objSelf, player)
    if(not Shared.GetIsRunningPrediction() and player == Client.GetLocalPlayer() and player:GetIsAlive() and player.showingBuyMenu) then
      self:BuyMenuOpened()
    end
  end)

	self:PostHookFunction("ArmoryUI_Close", function()
	  if(self.BuyMenuOpen) then
		  self:BuyMenuClosed()
		end
	end)
	
	self:PostHookClassFunction("Alien", "CloseMenu", "AlienBuy_Hook")
	self:PostHookClassFunction("Alien", "Buy", "AlienBuy_Hook")
	
	ClassHooker:SetClassCreatedIn("GUIFeedback", "lua/GUIFeedback.lua")
	self:PostHookClassFunction("GUIFeedback", "Initialize", "GUIFeedbackCreated")

	LoadTracker:HookFileLoadFinished("lua/GUIFeedback.lua", self, "FixUpGUIFeedback")

	self:HookFunction("ShowInGameMenu", "InGameMenuOpened")
	self:HookFunction("ChatUI_SubmitChatMessageBody", "ChatClosed")
	
	self:HookFunction("MainMenu_ReturnToGame", "InGameMenuClosed")
	
	ClassHooker:SetClassCreatedIn("GUIManager", "lua/GUIManager.lua")
	self:HookClassFunction("GUIManager", "SendKeyEvent", "Pre_SendKeyEvent"):SetPassHandle(true)
	self:PostHookClassFunction("GUIManager", "SendKeyEvent", "Post_SendKeyEvent"):SetPassHandle(true)
		
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

function KeybindMapper:OverrideInput_Hook(entitySelf, input)
		self:InputTick()
		self:FillInMove(input, entitySelf:isa("Commander"))
	return input
end

local ValidEmbryoBits = 0

local BlockedBits = {
  "PrimaryAttack",
	"SecondaryAttack",
	"NextWeapon",
	"PrevWeapon",
	"Reload",
	"Use",
	"Jump",
	"Crouch",
	"MovementModifier",
	"Buy",
}

for i,bitName in ipairs(BlockedBits) do
   ValidEmbryoBits = bit.bor(ValidEmbryoBits, Move[bitName])
end

ValidEmbryoBits = bit.bnot(ValidEmbryoBits)

// Allow players to rotate view, chat, scoreboard, etc. but not move
function KeybindMapper:Embryo_OverrideInput(entitySelf, input)

    // Completely override movement and commands
   input.move.x = 0
   input.move.y = 0
   input.move.z = 0

   // Only allow some actions like going to menu, chatting and Scoreboard (not jump, use, etc.)
   input.commands = bit.band(input.commands, ValidEmbryoBits)
    
  return input
end

function KeybindMapper:Pre_SendKeyEvent(HookHandle, _, key, down, IsRepeat)
 	local handled 
  
  --don't do anything if another hook has already handled it
	if(self.IsShutDown or HookHandle:GetReturn() or IsRepeat) then
		return
	end

	if((self.IsCommander or ScoreboardUI_GetVisible()) and (key == InputKey.MouseButton0 or key == InputKey.MouseButton1)) then
		return
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

function KeybindMapper:Post_SendKeyEvent(HookHandle, _, key, down)

	if(self.IsShutDown or key == InputKey.MouseX or key == InputKey.MouseY) then
		return false
	end

	local handled = HookHandle:GetReturn()

	if(not handled) then
		local keystring = InputKeyHelper:ConvertToKeyName(key)

		HookHandle:SetReturn(not self:CanKeyFallThrough(keystring))
	end
end

if(hotreload) then
 KeybindMapper:SetupHooks()
end