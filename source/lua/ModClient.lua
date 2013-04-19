
Script.Load("lua/Render.lua")
Script.Load("lua/InputHandler.lua")
Script.Load("lua/MapEntityLoader.lua")

Script.Load("lua/OptionsDialog.lua")

Script.Load("lua/ModShared.lua")

local gRenderCamera = nil

Client.propList = { }

--Event.Hook("LocalPlayerChanged", OnLocalPlayerChanged)
--Event.Hook("ClientDisconnected", OnClientDisconnected)
--Event.Hook("ClientConnected", OnClientConnected)

/**
 * Returns the horizontal field of view adjusted so that regardless of the resolution,
 * the vertical fov is a constant. standardAspect specifies the aspect ratio the game
 * is designed to be played at.
 */
local function GetScreenAdjustedFov(horizontalFov, standardAspect)

    local actualAspect = Client.GetScreenWidth() / Client.GetScreenHeight()
    
    local verticalFov = 2.0 * math.atan(math.tan(horizontalFov * 0.5) / standardAspect)
    horizontalFov = 2.0 * math.atan(math.tan(verticalFov * 0.5) * actualAspect)
    
    return horizontalFov
    
end

local function OnUpdateRender()

    local camera = Camera()
    local cullingMode = RenderCamera.CullingMode_Occlusion
    gRenderCamera:SetCullingMode(cullingMode)
    gRenderCamera:SetNearPlane(0.03)
    gRenderCamera:SetFov(GetScreenAdjustedFov(math.rad(90), 4 / 3))
    
    local player = Client.GetLocalPlayer()
    // If we have a player, use them to setup the camera. 
    if player ~= nil then
    
        local coords = player:GetCameraViewCoords()
        camera:SetCoords(coords)
		
        --local adjustValue = Clamp(Client.GetOptionFloat("graphics/display/fov-adjustment",0), 0, 1)
		--local adjustRadians = math.rad((1 - adjustValue) * kMinFOVAdjustmentDegrees + adjustValue * kMaxFOVAdjustmentDegrees)
		
        camera:SetFov(player:GetRenderFov())--+adjustRadians)
        
        gRenderCamera:SetCoords(camera:GetCoords())
        local horizontalFov = GetScreenAdjustedFov(camera:GetFov(), 4 / 3)
        gRenderCamera:SetFov(horizontalFov)
        gRenderCamera:SetCullingMode(cullingMode)
        
        --if player:GetShowAtmosphericLight() then
        --    EnableAtmosphericDensity()
        --else
        --    DisableAtmosphericDensity()
        --end
        
        Client.SetRenderCamera(gRenderCamera)
        
    else
        Client.SetRenderCamera(nil)
    end
    
end
Event.Hook("UpdateRender", OnUpdateRender)

function OnMapLoadEntity(className, groupName, values)

    // Create render objects.
    if className == "fog_controls" then
    
        --[[Client.globalFogControls = values
        Client.SetZoneFogDepthScale(RenderScene.Zone_ViewModel, 1.0 / values.view_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_ViewModel, values.view_zone_color)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_SkyBox, 1.0 / values.skybox_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_SkyBox, values.skybox_zone_color)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_Default, 1.0 / values.default_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_Default, values.default_zone_color)--]]
        
    elseif className == "fog_area_modifier" then
    
        --assert(values.start_blend_radius > values.end_blend_radius, "Error: fog_area_modifier must have a larger start blend radius than end blend radius")
        --table.insert(Client.fogAreaModifierList, values)
        
    // Only create the client side cinematic if it isn't waiting for a signal to start.
    // Otherwise the server will create the cinematic.
    elseif className == "skybox" or (className == "cinematic" and (values.startsOnMessage == "" or values.startsOnMessage == nil)) then
    
        --[[local coords = values.angles:GetCoords(values.origin)
        
        local zone = RenderScene.Zone_Default
        
        if className == "skybox" then
            zone = RenderScene.Zone_SkyBox
        end
        
        local cinematic = Client.CreateCinematic(zone)
        
        cinematic:SetCinematic(values.cinematicName)
        cinematic:SetCoords(coords)
        
        local repeatStyle = Cinematic.Repeat_None
        
        if values.repeatStyle == 0 then
            repeatStyle = Cinematic.Repeat_None
        elseif values.repeatStyle == 1 then
            repeatStyle = Cinematic.Repeat_Loop
        elseif values.repeatStyle == 2 then
            repeatStyle = Cinematic.Repeat_Endless
        end
        
        if className == "skybox" then
        
            table.insert(Client.skyBoxList, cinematic)
            
            // Becuase we're going to hold onto the skybox, make sure it
            // uses the endless repeat style so that it doesn't delete itself
            repeatStyle = Cinematic.Repeat_Endless
            
        end
        
        cinematic:SetRepeatStyle(repeatStyle)
        table.insert(Client.cinematics, cinematic)--]]
        
    elseif className == "ambient_sound" then
    
        --[[local entity = AmbientSound()
        LoadEntityFromValues(entity, values)
        Client.PrecacheLocalSound(entity.eventName)
        table.insert(Client.ambientSoundList, entity)--]]
        
   -- elseif className == Reverb.kMapName then
    
        --[[local entity = Reverb()
        LoadEntityFromValues(entity, values)
        entity:OnLoad()--]]
        
    elseif className == "pathing_settings" then
        --ParsePathingSettings(values)
    else
    
        // Allow the MapEntityLoader to load it if all else fails.
        LoadMapEntity(className, groupName, values)
        
    end
    
end
Event.Hook("MapLoadEntity", OnMapLoadEntity)

--Event.Hook("MapPreLoad", OnMapPreLoad)
--Event.Hook("MapPostLoad", OnMapPostLoad)
--Event.Hook("UpdateClient", OnUpdateClient)
--Event.Hook("NotifyGUIItemDestroyed", OnNotifyGUIItemDestroyed)

local function OnLoadComplete()

    gRenderCamera = Client.CreateRenderCamera()
    gRenderCamera:SetRenderSetup("renderer/Deferred.render_setup")
    
    Render_SyncRenderOptions()
    Input_SyncInputOptions()
    OptionsDialogUI_SyncSoundVolumes()
    
    -- Set default player name to one set in Steam, or one we've used and saved previously
    --local playerName = Client.GetOptionString(kNicknameOptionsKey, Client.GetUserName())
    --Client.SendNetworkMessage("SetName", { name = playerName }, true)
    
end
Event.Hook("LoadComplete", OnLoadComplete)