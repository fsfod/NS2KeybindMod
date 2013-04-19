
Script.Load("lua/Utility.lua")
Script.Load("lua/GUIUtility.lua")
Script.Load("lua/Table.lua")
Script.Load("lua/BindingsDialog.lua")
Script.Load("lua/NS2Utility.lua")

local kModeText =
{
    ["starting local server"]   = { text = "STARTING LOCAL SERVER" },
    ["attempting connection"]   = { text = "ATTEMPTING CONNECTION" },
    ["authenticating"]          = { text = "AUTHENTICATING" },
    ["connection"]              = { text = "CONNECTING" },
    ["loading"]                 = { text = "LOADING" },
    ["waiting"]                 = { text = "WAITING FOR SERVER" },
    ["precaching"]              = { text = "PRECACHING", display = "count" },
    ["initializing_game"]       = { text = "INITIALIZING GAME" },
    ["loading_map"]             = { text = "LOADING MAP" },
    ["loading_assets"]          = { text = "LOADING ASSETS" },
    ["downloading_mods"]        = { text = "DOWNLOADING MODS" },
    ["checking_consistency"]    = { text = "CHECKING CONSISTENCY" },
    ["compiling_shaders"]       = { text = "COMPILING UPDATED SHADERS", display = "count" }
}

local spinner = nil
local statusText = nil
local statusTextShadow = nil
local dotsText = nil
local dotsTextShadow = nil

-- Background slideshow.
local backgrounds = nil
local transition = nil
local currentBgId
local currentBackground = nil
local lastFadeEndTime = 0.0
local currentMapName = ''
local bgSize = nil
local bgPos = nil

local kBgFadeTime = 2.0
local kBgStayTime = 3.0

local function GetMapName()

    local mapName = Shared.GetMapName()
    if mapName == '' then
        mapName = Client.GetOptionString("lastServerMapName", "")
    end
    return mapName
    
end

local function OnUpdateRender()

    local spinnerSpeed = 2
    local dotsSpeed = 0.5
    local maxDots = 4
    
    local time = Shared.GetTime()
    
    if spinner ~= nil then
    
        local angle = -time * spinnerSpeed
        spinner:SetRotation(Vector(0, 0, angle))
        
    end
    
    if statusText ~= nil then
    
        local mode = Client.GetModeDescription()
        local count, total = Client.GetModeProgress()
        local text = nil
        local suffix = nil
        
        if kModeText[mode] then
        
            text = kModeText[mode].text
            if kModeText[mode].display == "count" and total ~= 0 then
                text = text .. string.format(" (%d%%)", math.ceil((count / total) * 100))
            end
            
        else
            text = "LOADING"
        end
        
        if mode == "loading" then
        
            local mapName = Shared.GetMapName()
            if mapName ~= "" then
                text = text .. " " .. Shared.GetMapName()
            end
            
        end
        
        statusText:SetText(text)
        statusTextShadow:SetText(text)
        
        // Add animated dots to the text.
        local numDots = math.floor(time / dotsSpeed) % (maxDots + 1)
        dotsText:SetText(string.rep(".", numDots))
        dotsTextShadow:SetText(string.rep(".", numDots))
        
    end
    
    // Check if map specific backgrounds became available
    local newMapName = GetMapName()
    if newMapName ~= '' and currentMapName ~= newMapName then
    
        currentMapName = newMapName
        InitializeBackgrounds()
        currentBgId = 0
        lastFadeEndTime = time - 2 * kBgStayTime
        
    end
    
    // Update background image slideshow
    if backgrounds ~= nil then
    
        if transition then
        
            local fraction = (time - transition.startTime) / transition.duration
            
            if fraction > 1.0 then
            
                // fade done - swap buffers
                if transition.from then
                
                    transition.from:SetLayer(1)
                    transition.from:SetIsVisible(false)
                    
                end
                
                if transition.to then
                
                    transition.to:SetLayer(2)
                    transition.to:SetColor(Color(1, 1, 1, 1))
                    
                end
                
                transition = nil
                lastFadeEndTime = time
                
            else
            
                if transition.from then
                    transition.from:SetLayer(1)
                end
                
                if transition.to then
                
                    transition.to:SetLayer(2)
                    transition.to:SetColor(Color(1, 1, 1, fraction))
                    transition.to:SetIsVisible(true)
                    
                end
                
            end
            
        else
        
            if (time - lastFadeEndTime) > kBgStayTime then
            
                if currentBgId < #backgrounds then
                
                    // time to fade
                    local nextBgId = math.min(currentBgId + 1, #backgrounds)
                    
                    transition = { }
                    transition.startTime = time
                    transition.duration = kBgFadeTime
                    transition.from = currentBackground
                    transition.to = backgrounds[nextBgId]
                    currentBgId = nextBgId
                    currentBackground = backgrounds[currentBgId]
                    
                end
                
            end
            
        end
        
    end
    
end
Event.Hook("UpdateRender", OnUpdateRender)

// out - a table reference, which will be filled with ordered filenames
local function InitBackgroundFileNames( out )

    // First try to get screens for the map
    // local mapname = Client.GetOptionString("lastServerMapName", "")
    local mapname = GetMapName()

    if mapname ~= '' then
    
        for i = 1,100 do
            
            local searchResult = {}
            Shared.GetMatchingFileNames( string.format("screens/%s/%d.jpg", mapname, i ), false, searchResult )

            if #searchResult == 0 then
                // found no more - must be done
                break
            else
                // found one - add it
                out[ #out+1 ] = searchResult[1]
            end

        end
        
    end
    
    // did we find any?
    if #out == 0 then
        //Print("Found no map-specific ordered screenshots for %s. Using shots in 'screens' instead.", mapname)
        Shared.GetMatchingFileNames("screens/*.jpg", false, out )
    end
    
end

local function InitializeBackgrounds()

    local backgroundFileNames = {}
    InitBackgroundFileNames( backgroundFileNames )
    backgrounds = {}
    for i = 1, #backgroundFileNames do

        backgrounds[i] = GUI.CreateItem()
        backgrounds[i]:SetSize( bgSize )
        backgrounds[i]:SetPosition( bgPos )
        backgrounds[i]:SetTexture( backgroundFileNames[i] )
        backgrounds[i]:SetIsVisible( false )

    end

end


-- NOTE: This does not refer to the loading screen being done.
-- It's referring to the loading of the loading screen.
local function OnLoadComplete()

    local backgroundAspect = 16.0 / 9.0
    
    local ySize = Client.GetScreenHeight()
    local xSize = ySize * backgroundAspect
    
    bgSize = Vector(xSize, ySize, 0)
    bgPos = Vector( (Client.GetScreenWidth() - xSize) / 2, (Client.GetScreenHeight() - ySize) / 2, 0 ) 

    // Create all bgs
    
    currentMapName = GetMapName()
    InitializeBackgrounds()

    // Init background slideshow state

    lastFadeEndTime = Shared.GetTime()
    currentBgId = 1
    if currentBgId <= #backgrounds then
        currentBackground = backgrounds[currentBgId]
        currentBackground:SetIsVisible( true )
    end
    
    local spinnerSize   = GUIScale(256)
    local spinnerOffset = GUIScale(50)

    spinner = GUI.CreateItem()
    spinner:SetTexture("ui/loading/spinner.dds")
    spinner:SetSize( Vector( spinnerSize, spinnerSize, 0 ) )
    spinner:SetPosition( Vector( Client.GetScreenWidth() - spinnerSize - spinnerOffset, Client.GetScreenHeight() - spinnerSize - spinnerOffset, 0 ) )
    spinner:SetBlendTechnique( GUIItem.Add )
    spinner:SetLayer(3)
    
    local statusOffset = GUIScale(50)

    local shadowOffset = 2

    statusTextShadow = GUI.CreateItem()
    statusTextShadow:SetOptionFlag(GUIItem.ManageRender)
    statusTextShadow:SetPosition( Vector( Client.GetScreenWidth() - spinnerSize - spinnerOffset - statusOffset+shadowOffset, Client.GetScreenHeight() - spinnerSize / 2 - spinnerOffset+shadowOffset, 0 ) )
    statusTextShadow:SetTextAlignmentX(GUIItem.Align_Max)
    statusTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
    statusTextShadow:SetFontName("fonts/AgencyFB_large.fnt")
    statusTextShadow:SetColor(Color(0,0,0,1))
    statusTextShadow:SetLayer(3)
        
    statusText = GUI.CreateItem()
    statusText:SetOptionFlag(GUIItem.ManageRender)
    statusText:SetPosition( Vector( Client.GetScreenWidth() - spinnerSize - spinnerOffset - statusOffset, Client.GetScreenHeight() - spinnerSize / 2 - spinnerOffset, 0 ) )
    statusText:SetTextAlignmentX(GUIItem.Align_Max)
    statusText:SetTextAlignmentY(GUIItem.Align_Center)
    statusText:SetFontName("fonts/AgencyFB_large.fnt")
    statusText:SetLayer(3)

    dotsTextShadow = GUI.CreateItem()
    dotsTextShadow:SetOptionFlag(GUIItem.ManageRender)
    dotsTextShadow:SetPosition( Vector( Client.GetScreenWidth() - spinnerSize - spinnerOffset - statusOffset+shadowOffset, Client.GetScreenHeight() - spinnerSize / 2 - spinnerOffset+shadowOffset, 0 ) )
    dotsTextShadow:SetTextAlignmentX(GUIItem.Align_Min)
    dotsTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
    dotsTextShadow:SetFontName("fonts/AgencyFB_large.fnt")
    dotsTextShadow:SetColor(Color(0,0,0,1))
    dotsTextShadow:SetLayer(3)
    
    dotsText = GUI.CreateItem()
    dotsText:SetOptionFlag(GUIItem.ManageRender)
    dotsText:SetPosition( Vector( Client.GetScreenWidth() - spinnerSize - spinnerOffset - statusOffset, Client.GetScreenHeight() - spinnerSize / 2 - spinnerOffset, 0 ) )
    dotsText:SetTextAlignmentX(GUIItem.Align_Min)
    dotsText:SetTextAlignmentY(GUIItem.Align_Center)
    dotsText:SetFontName("fonts/AgencyFB_large.fnt")
    dotsText:SetLayer(3)
    
end
Event.Hook("LoadComplete", OnLoadComplete)

-- Return true if the event should be stopped here.
local function OnSendKeyEvent(key, down)
    return true
end
Event.Hook("SendKeyEvent", OnSendKeyEvent)