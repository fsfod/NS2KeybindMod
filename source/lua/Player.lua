
Script.Load("lua/PhysicsGroups.lua")
Script.Load("lua/Mixins/ModelMixin.lua")
Script.Load("lua/mixins/ControllerMixin.lua")
Script.Load("lua/Mixins/BaseMoveMixin.lua")
Script.Load("lua/Mixins/GroundMoveMixin.lua")
Script.Load("lua/Mixins/CameraHolderMixin.lua")

class 'Player' (Entity)

Player.kMapName = "player"

local kModelName = PrecacheAsset("models/marine/male/male.model")
local kGravity = -24
local kMass = 90.7
local kAcceleration = 40
local kWalkMaxSpeed = 5
local kMaxWalkableNormal = math.cos(math.rad(45))
-- Stick to ground on down slopes up to 60 degrees
local kDownSlopeFactor = math.tan(math.rad(60))
local kXExtents = 0.5
local kYExtents = 1
local kZExtents = 0.5
local kViewOffsetHeight = kYExtents * 2 - 0.2
-- Total amount of time to interpolate up a step
local kStepTotalTime = 0.1
local kMaxStepAmount = 2
local kOnGroundDistance = 0.1
local kFov = 90
-- This is how far the player can turn with their feet standing on the same ground before
-- they start to rotate in the direction they are looking.
local kBodyYawTurnThreshold = Math.Radians(85)

-- The 3rd person model angle is lagged behind the first person view angle a bit.
-- This is how fast it turns to catch up. Radians per second.
local kTurnDelaySpeed = 8
local kTurnRunDelaySpeed = 2.5
-- Controls how fast the body_yaw pose parameter used for turning while standing
-- still blends back to default when the player starts moving.
local kTurnMoveYawBlendToMovingSpeed = 5

local networkVars =
{
    fullPrecisionOrigin = "private vector", 
    
    -- Controlling client index. -1 for not being controlled by a live player (ragdoll, fake player)
    clientIndex = "integer",
    
    bodyYaw = "compensated interpolated float (-3.14159265 to 3.14159265 by 0.003)",
    standingBodyYaw = "interpolated float (0 to 6.2831853 by 0.003)",
    
    bodyYawRun = "compensated interpolated float (-3.14159265 to 3.14159265 by 0.003)",
    runningBodyYaw = "interpolated float (0 to 6.2831853 by 0.003)",
    
    -- Used to smooth out the eye movement when going up steps.
    stepStartTime = "compensated time",
    -- limits must be just slightly bigger than kMaxStepAmount.
    stepAmount = "compensated float(-2.1 to 2.1 by 0.001)",
    
    onGround = "compensated boolean",
    onGroundNeedsUpdate = "private compensated boolean",
}

AddMixinNetworkVars(BaseModelMixin, networkVars)
AddMixinNetworkVars(ModelMixin, networkVars)
AddMixinNetworkVars(ControllerMixin, networkVars)
AddMixinNetworkVars(CameraHolderMixin, networkVars)
AddMixinNetworkVars(BaseMoveMixin, networkVars)
AddMixinNetworkVars(GroundMoveMixin, networkVars)

function Player:OnCreate()

    Entity.OnCreate(self)
    
    InitMixin(self, BaseModelMixin)
    InitMixin(self, ModelMixin)
    InitMixin(self, ControllerMixin)
    InitMixin(self, BaseMoveMixin, { kGravity = kGravity })
    InitMixin(self, GroundMoveMixin)
    InitMixin(self, CameraHolderMixin, { kFov = kFov })
    
    self:SetLagCompensated(true)
    
    self:SetUpdates(true)
    
    self.viewOffset = Vector(0, 0, 0)
    
    self.clientIndex = -1
    
    self.bodyYaw = 0
    self.standingBodyYaw = 0
    
    self.bodyYawRun = 0
    self.runningBodyYaw = 0
    
    self.stepStartTime = 0
    self.stepAmount = 0
    
    self.onGround = false
    self.onGroundNeedsUpdate = true
    self.timeLastOnGround = 0
    
    -- Create the controller for doing collision detection.
    -- Just use default values for the capsule size for now. Player will update to correct
    -- values when they are known.
    self:CreateController(PhysicsGroup.PlayerControllersGroup)
    
    -- Make the player kinematic so that bullets and other things collide with it.
    self:SetPhysicsGroup(PhysicsGroup.PlayerGroup)
    
end

function Player:OnInitialized()

    Entity.OnInitialized(self)
    
    self:UpdateControllerFromEntity()
    
    self:SetViewOffsetHeight(self:GetMaxViewOffsetHeight())
    
end

function Player:OnDestroy()

    Entity.OnDestroy(self)
    
end

if Server then

    function Player:SetControllerClient(client)
    
        self.clientIndex = client:GetId()
        client:SetControllingPlayer(self)
        client:SetRelevancyMask(0xFFFFFFFF)
        
    end
    
end

local kMaxPitch = Math.Radians(89.9)
local function ClampInputPitch(input)
    input.pitch = Math.Clamp(input.pitch, -kMaxPitch, kMaxPitch)
end

function Player:OverrideInput(input)

    ClampInputPitch(input)
    
    return input
    
end

function Player:GetViewOffset()
    return self.viewOffset
end

-- Returns the view offset with the step smoothing factored in.
function Player:GetSmoothedViewOffset()

    local deltaTime = Shared.GetTime() - self.stepStartTime
    
    if deltaTime < kStepTotalTime then
        return self.viewOffset + Vector(0, -self.stepAmount * (1 - deltaTime / kStepTotalTime), 0)
    end
    
    return self.viewOffset
    
end

function Player:SetViewOffsetHeight(newViewOffsetHeight)
    self.viewOffset.y = newViewOffsetHeight
end

function Player:GetMaxViewOffsetHeight()
    return kViewOffsetHeight
end

function Player:GetController()
    return self.controller
end

function Player:GetMass()
    return kMass
end

function Player:ComputeForwardVelocity(input)

    local forwardVelocity = Vector(0, 0, 0)
    
    local move = GetNormalizedVector(input.move)
    local angles = self:ConvertToViewAngles(input.pitch, input.yaw, 0)
    local viewCoords = angles:GetCoords()
    
    local accel = self:GetAcceleration()
    
    local moveVelocity = viewCoords:TransformVector(move) * accel
    self:ConstrainMoveVelocity(moveVelocity)
    
    -- Make sure that moving forward while looking down doesn't slow 
    -- us down (get forward velocity, not view velocity)
    local moveVelocityLength = moveVelocity:GetLength()
    
    if moveVelocityLength > 0 then
    
        local moveDirection = self:GetMoveDirection(moveVelocity)
        
        -- Trying to move straight down
        if not ValidateValue(moveDirection) then
            moveDirection = Vector(0, -1, 0)
        end
        
        forwardVelocity = moveDirection * moveVelocityLength
        
    end
    
    return forwardVelocity
    
end

-- Children can add or remove velocity according to special abilities, modes, etc.
function Player:ModifyVelocity(input, velocity)

    if self:GetIsOnGround() then
        velocity.y = 0
    end
    
end

function Player:GetIsAffectedByAirFriction()
    return not self:GetIsOnGround()
end

function Player:GetGroundFrictionForce()
    return 8
end

function Player:GetAirFrictionForce()
    return 0.5
end

function Player:GetStopSpeed()
    return 2.4
end

function Player:PerformsVerticalMove()
    return false
end

function Player:GetFrictionForce(input, velocity)

    local stopSpeed = self:GetStopSpeed()
    local friction = GetNormalizedVector(-velocity)
    local velocityLength = 0
    
    if self:PerformsVerticalMove() then
        velocityLength = self:GetVelocity():GetLength()
    else
        velocityLength = self:GetVelocity():GetLengthXZ()
    end
    
    -- ground friction by default
    local frictionScalar = velocityLength * self:GetGroundFrictionForce()
    
    -- if the player is in air we apply a different friction to allow utilizing momentum
    if self:GetIsAffectedByAirFriction() then
    
        -- disable vertical friction when in air.
        if not self:PerformsVerticalMove() then
            friction.y = 0
        end
        
        frictionScalar = velocityLength * self:GetAirFrictionForce(input, velocity)
        
    end
    
    -- Calculate friction when going slower than stopSpeed
    if stopSpeed > velocityLength and 0 < velocityLength and input.move:GetLength() == 0 then

        local control = velocity:GetUnit()
        friction = -stopSpeed * control

    end
    return friction * frictionScalar
    
end

function Player:GetGravityAllowed()
    return not self:GetIsOnGround()
end

function Player:GetMoveDirection(moveVelocity)

    local up = Vector(0, 1, 0)
    local right = GetNormalizedVector(moveVelocity):CrossProduct(up)
    local moveDirection = up:CrossProduct(right)
    moveDirection:Normalize()
    
    return moveDirection
    
end

-- Make sure we can't move faster than our max speed (esp. when holding
-- down multiple keys, going down ramps, etc.)
function Player:OnClampSpeed(input, velocity)

    -- Don't clamp speed when stunned, so we can go flying
    if HasMixin(self, "Stun") and self:GetIsStunned() then
        return velocity
    end
    
    if self:PerformsVerticalMove() then
        moveSpeed = velocity:GetLength()   
    else
        moveSpeed = velocity:GetLengthXZ()   
    end
    
    local maxSpeed = self:GetMaxSpeed()
    if moveSpeed > maxSpeed then
    
        local velocityY = velocity.y
        velocity:Scale(maxSpeed / moveSpeed)
        
        if not self:PerformsVerticalMove() then
            velocity.y = velocityY
        end
        
    end
    
end

-- Allow child classes to alter player's move at beginning of frame. Alter amount they
-- can move by scaling input.move, remove key presses, etc.
function Player:AdjustMove(input)
    return input
end

function Player:GetAngleSmoothingMode()
    return "euler"
end

function Player:GetDesiredAngles(deltaTime)

    desiredAngles = Angles()
    desiredAngles.pitch = 0
    desiredAngles.roll = self.viewRoll
    desiredAngles.yaw = self.viewYaw
    
    return desiredAngles
    
end

function Player:GetAngleSmoothRate()
    return 8
end

function Player:GetRollSmoothRate()
    return 6
end

function Player:GetPitchSmoothRate()
    return 6
end

function Player:GetSlerpSmoothRate()
    return 6
end

function Player:GetSmoothRoll()
    return true
end

function Player:GetSmoothPitch()
    return true
end

function Player:GetPredictSmoothing()
    return true
end

-- also predict smoothing on the local client, since no interpolation is happening here and some effects can depent on current players angle (like exo HUD)
function Player:AdjustAngles(deltaTime)

    local angles = self:GetAngles()
    local desiredAngles = self:GetDesiredAngles(deltaTime)
    local smoothMode = self:GetAngleSmoothingMode()
    
    if desiredAngles == nil then

        -- Just keep the old angles

    elseif smoothMode == "euler" then
        
        angles.yaw = SlerpRadians(angles.yaw, desiredAngles.yaw, self:GetAngleSmoothRate() * deltaTime )
        angles.roll = SlerpRadians(angles.roll, desiredAngles.roll, self:GetRollSmoothRate() * deltaTime )
        angles.pitch = SlerpRadians(angles.pitch, desiredAngles.pitch, self:GetPitchSmoothRate() * deltaTime )
        
    elseif smoothMode == "quatlerp" then

        --DebugDrawAngles( angles, self:GetOrigin(), 2.0, 0.5 )
        --Print("pre slerp = %s", ToString(angles)) 
        angles = Angles.Lerp( angles, desiredAngles, self:GetSlerpSmoothRate()*deltaTime )

    else
        
        angles.pitch = desiredAngles.pitch
        angles.roll = desiredAngles.roll
        angles.yaw = desiredAngles.yaw

    end

    AnglesTo2PiRange(angles)
    self:SetAngles(angles)
    
end

function Player:UpdateViewAngles(input)

    -- Update to the current view angles.    
    local viewAngles = Angles(input.pitch, input.yaw, 0)
    self:SetViewAngles(viewAngles)
        
    local viewY = self:GetMaxViewOffsetHeight()

    -- Don't set new view offset height unless needed (avoids Vector churn).
    local lastViewOffsetHeight = self:GetSmoothedViewOffset().y
    if math.abs(viewY - lastViewOffsetHeight) > kEpsilon then
        self:SetViewOffsetHeight(viewY)
    end
    
    self:AdjustAngles(input.time)
    
end

function Player:OnProcessIntermediate(input)
   
    self:UpdateViewAngles(input)
    
    -- This is necessary to update the child entity bones so that the view model
    -- animates smoothly and attached items will have the correct coords.
    local numChildren = self:GetNumChildren()
    for i = 1, numChildren do
    
        local child = self:GetChildAtIndex(i - 1)
        if child.OnProcessIntermediate then
            child:OnProcessIntermediate(input)
        end
        
    end
    
end

local kDoublePI = math.pi * 2
local kHalfPI = math.pi / 2

function Player:GetIsUsingBodyYaw()
    return true
end

local function UpdateBodyYaw(self, deltaTime, tempInput)

    if self:GetIsUsingBodyYaw() then
    
        local yaw = self:GetAngles().yaw
        
        -- Reset values when moving.
        if self:GetVelocityLength() > 0.1 then
        
            -- Take a bit of time to reset value so going into the move animation doesn't skip.
            self.standingBodyYaw = SlerpRadians(self.standingBodyYaw, yaw, deltaTime * kTurnMoveYawBlendToMovingSpeed)
            self.standingBodyYaw = Math.Wrap(self.standingBodyYaw, 0, kDoublePI)
            
            self.runningBodyYaw = SlerpRadians(self.runningBodyYaw, yaw, deltaTime * kTurnRunDelaySpeed)
            self.runningBodyYaw = Math.Wrap(self.runningBodyYaw, 0, kDoublePI)
            
        else
        
            self.runningBodyYaw = yaw
            
            local diff = RadianDiff(self.standingBodyYaw, yaw)
            if math.abs(diff) >= kBodyYawTurnThreshold then
            
                diff = Clamp(diff, -kBodyYawTurnThreshold, kBodyYawTurnThreshold)
                self.standingBodyYaw = Math.Wrap(diff + yaw, 0, kDoublePI)
                
            end
            
        end
        
        self.bodyYawRun = Clamp(RadianDiff(self.runningBodyYaw, yaw), -kHalfPI, kHalfPI)
        self.runningBodyYaw = Math.Wrap(self.bodyYawRun + yaw, 0, kDoublePI)
        
        local adjustedBodyYaw = RadianDiff(self.standingBodyYaw, yaw)
        if adjustedBodyYaw >= 0 then
            self.bodyYaw = adjustedBodyYaw % kHalfPI
        else
            self.bodyYaw = -(kHalfPI - adjustedBodyYaw % kHalfPI)
        end
        
    else
    
        -- Sometimes, probably due to prediction, these values can go out of range. Wrap them here
        self.standingBodyYaw = Math.Wrap(self.standingBodyYaw, 0, kDoublePI)
        self.runningBodyYaw = Math.Wrap(self.runningBodyYaw, 0, kDoublePI)
        self.bodyYaw = 0
        self.bodyYawRun = 0
        
    end
    
end

local function UpdateAnimationInputs(self, input)

    if self.ProcessMoveOnModel then
        self:ProcessMoveOnModel()
    end
    
end

-- done once per process move before handling player movement
local function UpdateOnGroundState(self)

    self.onGround = false
    self.onGround = self:GetIsCloseToGround(kOnGroundDistance)
    
    if self.onGround then
        self.timeLastOnGround = Shared.GetTime()
    end
    
end

-- You can't modify a compensated field for another (relevant) entity during OnProcessMove(). The
-- "local" player doesn't undergo lag compensation it's only all of the other players and entities.
-- For example, if health was compensated, you can't modify it when a player was shot -
-- it will just overwrite it with the old value after OnProcessMove() is done. This is because
-- compensated fields are rolled back in time, so it needs to restore them once the processing
-- is done. So it backs up, synchs to the old state, runs the OnProcessMove(), then restores them. 
function Player:OnProcessMove(input)

    local commands = input.commands
    
    -- Allow children to alter player's move before processing. To alter the move
    -- before it's sent to the server, use OverrideInput
    input = self:AdjustMove(input)
    
    -- Update player angles and view angles smoothly from desired angles if set. 
    -- But visual effects should only be calculated when not predicting.
    self:UpdateViewAngles(input)  
    
    Entity.OnProcessMove(self, input)
    
    UpdateAnimationInputs(self, input)
    
    -- Force an update to whether or not we're on the ground in case something
    -- has moved out from underneath us.
    self.onGroundNeedsUpdate = true
    local wasOnGround = self.onGround
    local previousVelocity = self:GetVelocity()
    
    UpdateOnGroundState(self)
    
    -- Update origin and velocity from input move (main physics behavior).
    self:UpdateMove(input)
    
    -- Restore the buttons so that things like the scoreboard, etc. work.
    input.commands = commands
    
    UpdateBodyYaw(self, input.time, input)
    
end

function Player:OnProcessSpectate(deltaTime)

    Entity.OnProcessSpectate(self, deltaTime)
    
    local numChildren = self:GetNumChildren()
    for i = 1, numChildren do
    
        local child = self:GetChildAtIndex(i - 1)
        if child.OnProcessIntermediate then
            child:OnProcessIntermediate()
        end
        
    end
    
    local viewModel = self:GetViewModelEntity()
    if viewModel then
        viewModel:ProcessMoveOnModel()
    end
    
end

function Player:OnUpdate(deltaTime)

    Entity.OnUpdate(self, deltaTime)
    
end

function Player:SendKeyEvent(key, down)
    return false
end

-- Required by ControllerMixin.
function Player:GetControllerSize()
    return GetTraceCapsuleFromExtents(Vector(kXExtents, kYExtents, kZExtents))
end

-- Required by ControllerMixin.
function Player:GetMovePhysicsMask()
    return PhysicsMask.Movement
end

function Player:GetCanStep()
    return self:GetIsOnGround()
end

function Player:UpdatePosition(velocity, time)

    if not self.controller then
        return velocity
    end

    -- We need to make a copy so that we aren't holding onto a reference
    -- which is updated when the origin changes.
    local start         = Vector(self:GetOrigin())
    local startVelocity = Vector(velocity)
   
    local maxSlideMoves = 3
    
    local offset = nil
    local stepHeight = self:GetStepHeight()
    local canStep = self:GetCanStep()
    local onGround = self:GetIsOnGround()
    
    local offset = velocity * time
    local horizontalOffset = Vector(offset)
    horizontalOffset.y = 0
    local hitEntities = nil
    local completedMove = false
    local averageSurfaceNormal = nil
    
    local stepUpOffset = 0

    if canStep then
        
        local horizontalOffsetLength = horizontalOffset:GetLength()
        local fractionOfOffset = 1
        
        if horizontalOffsetLength > 0 then
        
            -- check if we would collide with something, set fourth parameter to false
            completedMove, hitEntities, averageSurfaceNormal = self:PerformMovement(horizontalOffset, maxSlideMoves, velocity, false)   
            velocity = Vector(startVelocity)
            
            -- Horizontal move
            self:PerformMovement(horizontalOffset, maxSlideMoves, velocity)
            
            local movePerformed = self:GetOrigin() - (steppedStart or start)
            fractionOfOffset = movePerformed:DotProduct(horizontalOffset) / (horizontalOffsetLength*horizontalOffsetLength)
            
        end
        
        local downStepAmount = offset.y - stepUpOffset - horizontalOffsetLength * kDownSlopeFactor
        
        if fractionOfOffset < 0.5 then
        
            -- Didn't really move very far, try moving without step up
            local savedOrigin = Vector(self:GetOrigin())
            local savedVelocity = Vector(velocity)

            self:SetOrigin(start)
            velocity = Vector(startVelocity)
                 
            self:PerformMovement(offset, maxSlideMoves, velocity)
            
            local movePerformed = self:GetOrigin() - start
            local alternativeFractionOfOffset = movePerformed:DotProduct(offset) / offset:GetLengthSquared()
            
            if alternativeFractionOfOffset > fractionOfOffset then
                -- This move is better!
                downStepAmount = 0
            else
                -- Stepped move was better - go back to it!
                self:SetOrigin(savedOrigin)
                velocity = savedVelocity                    
            end            

        end
        
        -- Vertical move
        if downStepAmount ~= 0 then
            self:PerformMovement(Vector(0, downStepAmount, 0), 1)
        end
        
        -- Check to see if we moved up a step and need to smooth out
        -- the movement.
        local yDelta = self:GetOrigin().y - start.y
        
        if yDelta ~= 0 then
        
            -- If we're already interpolating up a step, we need to take that into account
            -- so that we continue that interpolation, plus our new step interpolation
            
            local deltaTime = Shared.GetTime() - self.stepStartTime
            local prevStepAmount = 0
            
            if deltaTime < kStepTotalTime then
                prevStepAmount = self.stepAmount * (1 - deltaTime / kStepTotalTime)
            end        
            
            self.stepStartTime = Shared.GetTime()
            self.stepAmount    = Clamp(yDelta + prevStepAmount, -kMaxStepAmount, kMaxStepAmount)
            
        end
        
    else
        
        -- Just do the move
        completedMove, hitEntities, averageSurfaceNormal = self:PerformMovement(offset, maxSlideMoves, velocity)        
        
    end
    
    return velocity, hitEntities, averageSurfaceNormal
    
end

-- Return the height that this player can step over automatically
function Player:GetStepHeight()
    return 0.5
end

-- Returns true if the player is currently standing on top of something solid. Recalculates
-- onGround if we've updated our position since we've last called this.
function Player:GetIsOnGround()
    return self.onGround
end

-- Recalculate self.onGround next time
function Player:SetOrigin(origin)

    Entity.SetOrigin(self, origin)
    
    self:UpdateControllerFromEntity()
    
    self.onGroundNeedsUpdate = true
    
end

-- Returns boolean indicating if we're at least the passed in distance from the ground.
function Player:GetIsCloseToGround(distanceToGround)

    -- If we are moving away from the ground, don't treat us as standing on it.
    if self:GetVelocity().y > 0 and self.timeOfLastJump ~= nil and (Shared.GetTime() - self.timeOfLastJump < 0.2) then
        return false
    end
    
    -- Try to move the controller downward a small amount to determine if we're on the ground.
    local offset = Vector(0, -distanceToGround, 0)
    local trace = self.controller:Trace(offset, CollisionRep.Move, CollisionRep.Move, self:GetMovePhysicsMask())
    
    local result = false
    
    if trace.fraction < 1 then
    
        -- Trace ray down to get normal of ground
        local rayTrace = Shared.TraceRay(self:GetOrigin() + Vector(0, 0.1, 0),
                                         self:GetOrigin() - Vector(0, 1, 0),
                                         CollisionRep.Move, EntityFilterOne(self))
        
        if rayTrace.fraction == 1 or math.abs(rayTrace.normal.y) >= kMaxWalkableNormal then
            result = true
        end
        
    end
    
    return result
    
end

-- Pass true as param to find out how fast the player can ever go
function Player:GetMaxSpeed(possible)

    if possible then
        return kWalkMaxSpeed
    end
    
    return kWalkMaxSpeed
    
end

function Player:GetAcceleration()
    return kAcceleration
end

function Player:GetAirMoveScalar()
    return 0.7
end

-- Don't allow full air control but allow players to especially their movement in the opposite way they are moving (airmove).
function Player:ConstrainMoveVelocity(wishVelocity)

    if not self:GetIsOnGround() and wishVelocity:GetLengthXZ() > 0 and self:GetVelocity():GetLengthXZ() > 0 then
    
        local normWishVelocity = GetNormalizedVectorXZ(wishVelocity)
        local normVelocity = GetNormalizedVectorXZ(self:GetVelocity())
        local scalar = Clamp((1 - normWishVelocity:DotProduct(normVelocity)) * self:GetAirMoveScalar(), 0, 1)
        wishVelocity:Scale(scalar)
        
    end
    
end

function Player:OnUpdateCamera(deltaTime)

    -- Update view offset from crouching
    --local offset = -self:GetCrouchShrinkAmount() * self:GetCrouchAmount()
    --self:SetCameraYOffset(offset)
    
end

-- This causes problems when doing a trace ray against CollisionRep.Move.
function Player:OnCreateCollisionModel()
    
    -- Remove any "move" collision representation from the player's model, since
    -- all of the movement collision will be handled by the controller.
    local collisionModel = self:GetCollisionModel()
    collisionModel:RemoveCollisionRep(CollisionRep.Move)
    
end

Shared.LinkClassToMap("Player", Player.kMapName, networkVars, true)