
JetpackMod = {}

local kJPMaxForwardVelocity = 17
local kJPMaxUpVelocity = 11
local kJPMinUpVelocity = 3

Script.Load("lua/ClassHooker.lua")
ClassHooker:Mixin("JetpackMod")

function JetpackMod:Init()
	self:PostHookClassFunction("Player", "ModifyVelocity")
	self.MaxSpeedHandle = self:PostHookClassFunction("Marine", "GetMaxSpeed")
	self:HookClassFunction("Marine", "UpdateJetpack"):BlockOrignalCall(true)
end

function JetpackMod:GetMaxSpeed(entitySelf)
	if(entitySelf.hasJetpack and not entitySelf:GetIsOnGround()) then
		self.MaxSpeedHandle:SetReturn(kJPMaxForwardVelocity+1)
	end
end

function JetpackMod:UpdateJetpack(entitySelf, input)

	local self = entitySelf

    if self.hasJetpack then
        local jumpPressed = (bit.band(input.commands, Move.Jump) ~= 0)
 
        // Give jetpack energy over time
        self.jetpackFuel = Clamp(self.jetpackFuel + input.time * kJetpackReplenishFuelRate, 0, 1)
    
        // Update jetpack energy
        if self.jetpacking then
            self.jetpackFuel = Clamp(self.jetpackFuel - input.time * kJetpackUseFuelRate, 0, 1)
            
            if self.jetpackFuel == -1 or not jumpPressed then
                Shared.StopSound(self, Marine.kJetpackStart)
                Shared.StopSound(self, Marine.kJetpackLoop)
                
                if Client then
                    Shared.PlaySound(self, Marine.kJetpackEnd)
                end
                
                self.jetpacking = false
                
                self.timeStartedJetpack = 0
                
            end
            
            // TODO: Set fuel parameter to give feedback to player about current state
            
        end
        
        if jumpPressed and self.timeStartedJetpack == 0 and not self.jetpacking then
            // Start jetpacking
            if Client then
                Shared.PlaySound(self, Marine.kJetpackStart)
                
                // Start loop sound if we're not playing it already
                Shared.PlaySound(self, Marine.kJetpackLoop)
            end
            
            self.jetpacking = true
            self.timeStartedJetpack = Shared.GetTime()                   
        end
        
    else
    	self.jetpackFuel = 0
    end
end

local halfpie = math.pi/2

function JetpackMod:ModifyVelocity(entitySelf, input, velocity)
	
	if(entitySelf:isa("Marine")) then
		if entitySelf.jetpacking then
    	local viewangles = entitySelf:GetViewAngles()
      local ThrustModifer
      local lookingdown = false
      
      local direction = Angles(0, input.yaw, 0):GetCoords().zAxis
			local ForwardThrust = 1
      
      if(viewangles.pitch > halfpie) then
    		ThrustModifer = (viewangles.pitch-(math.pi*1.5))/halfpie
    		ForwardThrust = ThrustModifer
    	else
    		lookingdown = true
      	ThrustModifer = 1-(viewangles.pitch/halfpie)
      	if(ThrustModifer > 0.8) then
      		ForwardThrust = 1
      	else
      		ForwardThrust = math.max(ThrustModifer, 0.1)
      	end
      end

			local newVelocity = direction*(ForwardThrust*kJPMaxForwardVelocity)
			velocity.x = newVelocity.x
			velocity.z = newVelocity.z
      
      if(lookingdown) then
				velocity.y = kJPMinUpVelocity
      else
				velocity.y = math.max(kJPMinUpVelocity, (1-ThrustModifer)*kJPMaxUpVelocity)
      end

      if(Shared.GetTime()-entitySelf.timeStartedJetpack < 0.2) then
				velocity.y = kJPMaxUpVelocity*0.8
      end
    end
	end	
end

JetpackMod:Init()