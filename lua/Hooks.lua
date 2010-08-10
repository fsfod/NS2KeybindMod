local LinkClassToMap = Shared.LinkClassToMap

Shared.LinkClassToMap = function(classname, entityname, networkvars)

	if(classname == "Player") then
		local original = Player.OverrideInput
		Player.OverrideInput = function(self, input)
			KeybindMapper:InputTick()
			input.move = KeybindMapper.MovementVector
			input.commands = KeybindMapper.MoveInputBitFlags
			original(self, input)
		end
		
	elseif(classname == "Commander") then
		local original = Commander.OverrideInput
		Commander.OverrideInput = function(self, input)
			input.commands = KeybindMapper.MoveInputBitFlags
			original(self, input)
		end
		
		local OnInitLocalClient = Commander.OnInitLocalClient
		Commander.OnInitLocalClient = function(selfArg)
			--PrintDebug("Commander.OnInitLocalClient")
			OnInitLocalClient(selfArg)
			KeybindMapper:OnCommander(selfArg)
		end

		local OnDestroy = Commander.OnDestroy
		Commander.OnDestroy = function(selfArg)
			//PrintDebug("Commander.OnDestroy")
			KeybindMapper:OnUnCommander()
			OnDestroy(selfArg)
		end

	end
	
	if(networkvars) then
		LinkClassToMap(classname, entityname, networkvars)
	else
		LinkClassToMap(classname, entityname)
	end
end


Event.Hook("MapPostLoad", function()
	ShowInGameMenu = function()
    if not Client.GetIsRunningPrediction() then
      Client.SetMouseVisible(true)
      Client.SetMouseCaptured(false)

      KeybindMapper:InGameMenuOpened()
      Shared.SetMenu(kMainMenuFlash)
    end 
	end

--Chat Hooks
	local oldEnterChatMessage = ChatUI_EnterChatMessage
	ChatUI_EnterChatMessage = function(teamchat)
		KeybindMapper:ChatOpened()
		oldEnterChatMessage(teamchat)
	end

	local oldSubmitChatMessageBody = ChatUI_SubmitChatMessageBody	
	ChatUI_SubmitChatMessageBody = function(chatMessage)
		KeybindMapper:ChatClosed()
		oldSubmitChatMessageBody(chatMessage)
	end
end)