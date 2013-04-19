
// The ConsoleBindings.lua ConsoleBindingsKeyPressed function is used below.
// It is possible for the OnSendKeyEvent function below to be called
// before ConsoleBindings.lua is loaded so make sure to load it here.
Script.Load("lua/ConsoleBindings.lua")
Script.Load("lua/menu/MouseTracker.lua")
Script.Load("lua/PlayerInput.lua")

Script.Load("lua/KeybindInfo.lua")
Script.Load("lua/KeybindMapper.lua")

local keyEventBlocker = nil
local moveInputBlocked = false

InputKeyLookup = {}

for k,v in pairs(InputKey) do
  InputKeyLookup[v] = k
end

local _keyBinding =
{
    MoveForward = InputKey.W,
    MoveLeft = InputKey.A,
    MoveBackward = InputKey.S,
    MoveRight = InputKey.D,
    Jump = InputKey.Space,
    MovementModifier = InputKey.LeftShift,
    Crouch = InputKey.LeftControl,
    Scoreboard = InputKey.Tab,
    PrimaryAttack = InputKey.MouseButton0,
    SecondaryAttack = InputKey.MouseButton1,
    Reload = InputKey.R,
    Use = InputKey.E,
    Drop = InputKey.G,
    Buy = InputKey.B,
    ShowMap = InputKey.M,
    VoiceChat = InputKey.LeftAlt,
    TextChat = InputKey.Y,
    TeamChat = InputKey.Return,
    Weapon1 = InputKey.Num1,
    Weapon2 = InputKey.Num2,
    Weapon3 = InputKey.Num3,
    Weapon4 = InputKey.Num4,
    Weapon5 = InputKey.Num5,
    ToggleConsole = InputKey.Grave,
    ToggleFlashlight = InputKey.F,
    ReadyRoom = InputKey.F4,
    RequestMenu = InputKey.X,
    RequestHealth = InputKey.Q,
    RequestAmmo = InputKey.Z,
    RequestOrder = InputKey.H,
    Taunt = InputKey.T,
    PingLocation = InputKey.MouseButton2,
    NextWeapon = InputKey.MouseZ,
    ScrollForward = InputKey.Up,
    ScrollBackward = InputKey.Down,
    ScrollLeft = InputKey.Left,
    ScrollRight = InputKey.Right,
    Q = InputKey.Q,
    W = InputKey.W,
    E = InputKey.E,
    R = InputKey.R,
    T = InputKey.T,
    Y = InputKey.Y,
    U = InputKey.U,
    I = InputKey.I,
    O = InputKey.O,
    P = InputKey.P,
    A = InputKey.A,
    S = InputKey.S,
    D = InputKey.D,
    F = InputKey.F,
    G = InputKey.G,
    H = InputKey.H,
    J = InputKey.J,
    K = InputKey.K,
    L = InputKey.L,
    Z = InputKey.Z,
    X = InputKey.X,
    C = InputKey.C,
    V = InputKey.V,
    B = InputKey.B,
    N = InputKey.N,
    M = InputKey.M,
    ESC = InputKey.Escape,
    Space = InputKey.Space
}

local _mouseAccel = 1.0
local _sensitivityScalar = 1.0
local _cameraYaw = 0
local _cameraPitch = 0
local _keyState = { }
local _keyPressed = { }

local _bufferedCommands = 0
local _lastProcessedCommands = 0
local _bufferedMove = Vector(0, 0, 0)
local _bufferedHotKey = 0

// Provide support for these functions that were removed from the API in Build 237
function Client.SetYaw(yaw)
    _cameraYaw = yaw
end
function Client.SetPitch(pitch)
    _cameraPitch = pitch
end

// Provide support for these functions that were removed from the API in Build 237
function Client.SetMouseSensitivityScalar(sensitivityScalar)
    _sensitivityScalar = sensitivityScalar
end
function Client.GetMouseSensitivityScalar()
    return _sensitivityScalar
end

function SetKeyEventBlocker(setKeyEventBlocker)
    keyEventBlocker = setKeyEventBlocker
end

function IsKeyDown(inputKeyNum)
    return _keyState[inputKeyNum]
end

/**
 * This will update the internal state to match the settings that have been
 * specified in the options. This function should be called when the options
 * have been updated.
 */
function Input_SyncInputOptions()
    
    // Sync the key bindings.
    for action, _ in pairs(_keyBinding) do
    
        local keyName = Client.GetOptionString( "input/" .. action, "" )

        // The number keys are stored as 1, 2, etc. but the enum name is Num1, Num2, etc.        
        if tonumber(keyName) then
            keyName = "Num" .. keyName
        end
        
        local key = InputKey[keyName]
        if key ~= nil then
            _keyBinding[action] = key
        end
        
    end
    
    // Sync the acceleration and sensitivity.
    _mouseAccel = Client.GetOptionFloat("input/mouse/acceleration-amount", 1.0);
    if not Client.GetOptionBoolean("input/mouse/acceleration", false) then
        _mouseAccel = 1.0
    end

end

/**
 * Adjusts the mouse movement to take into account the sensitivity setting and
 * and any mouse acceleration.
 */
local function ApplyMouseAdjustments(amount)
    
    // This value matches what the GoldSrc/Source engine uses, so that
    // players can use the values they are familiar with.
    local rotateScale = 0.00038397243
    
    local sign = 1.0
    if amount < 0 then
        sign = -1.0
    end
    
    return sign * math.pow(math.abs(amount * rotateScale), _mouseAccel) * _sensitivityScalar
    
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
    
    if not stop and GetGUIManager then
        stop = GetGUIManager():SendKeyEvent(key, down, amount)
    end
    
    if not stop and GetWindowManager then
    
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
        
        // Filter out the OS key repeat for our general movement (but we'll use it for GUI).
        if not repeated then
          
            KeybindMapper:SendKeyEvent(key, down, amount)
          
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

// Return true if the event should be stopped here.
local function OnSendCharacterEvent(character)

    local stop = false
    
    local winMan = GetWindowManager and GetWindowManager()
    if winMan then
        stop = winMan:SendCharacterEvent(character)
    end
    
    if not stop and GetGUIManager then
        stop = GetGUIManager():SendCharacterEvent(character)
    end
    
    return stop
    
end

local function AdjustMoveForInversion(move)

    // Invert mouse if specified in options.
    local invertMouse = Client.GetOptionBoolean(kInvertedMouseOptionsKey, false)
    if invertMouse then
        move.pitch = -move.pitch
    end
    
end

local function GenerateMove()

    local move = Move()
    
    move.yaw = _cameraYaw
    move.pitch = _cameraPitch
    
    AdjustMoveForInversion(move)
    
    if not moveInputBlocked then
    
        if _keyPressed[ _keyBinding.Exit ] then
            move.commands = bit.bor(move.commands, Move.Exit)
        end
        if _keyState[ _keyBinding.Buy ] then
            move.commands = bit.bor(move.commands, Move.Buy)
        end
        
        if _keyState[ _keyBinding.MoveForward ] then
            move.move.z = move.move.z + 1
        end
        if _keyState[ _keyBinding.MoveBackward ] then
            move.move.z = move.move.z - 1
        end
        if _keyState[ _keyBinding.MoveLeft ] then
            move.move.x = move.move.x + 1
        end
        if _keyState[ _keyBinding.MoveRight ] then
            move.move.x = move.move.x - 1
        end    
        
        if _keyState[ _keyBinding.Jump ] then
            move.commands = bit.bor(move.commands, Move.Jump)
        end    
        if _keyState[ _keyBinding.Crouch ] then
            move.commands = bit.bor(move.commands, Move.Crouch)
        end    
        if _keyState[ _keyBinding.MovementModifier ] then
            move.commands = bit.bor(move.commands, Move.MovementModifier)
        end    
        
        if _keyState[ _keyBinding.ScrollForward ] then
            move.commands = bit.bor(move.commands, Move.ScrollForward)
        end     
        if _keyState[ _keyBinding.ScrollBackward ] then
            move.commands = bit.bor(move.commands, Move.ScrollBackward)
        end     
        if _keyState[ _keyBinding.ScrollLeft ] then
            move.commands = bit.bor(move.commands, Move.ScrollLeft)
        end     
        if _keyState[ _keyBinding.ScrollRight ] then
            move.commands = bit.bor(move.commands, Move.ScrollRight)
        end     
        
        if _keyPressed[ _keyBinding.ToggleRequest ] then
            move.commands = bit.bor(move.commands, Move.ToggleRequest)
        end
        if _keyPressed[ _keyBinding.ToggleSayings ] then
            move.commands = bit.bor(move.commands, Move.ToggleSayings)
        end
        if _keyPressed[ _keyBinding.ToggleVoteMenu ] then
            move.commands = bit.bor(move.commands, Move.ToggleVoteMenu)
        end

        // FPS action relevant to spectator
        if _keyPressed[ _keyBinding.NextWeapon ] ~= nil then
            if _keyPressed[ _keyBinding.NextWeapon ] > 0 then
                move.commands = bit.bor(move.commands, Move.NextWeapon)
            else
                move.commands = bit.bor(move.commands, Move.PrevWeapon)
            end
        end    
        
        if _keyPressed[ _keyBinding.Weapon1 ] then
            move.commands = bit.bor(move.commands, Move.Weapon1)
        end
        if _keyPressed[ _keyBinding.Weapon2 ] then
            move.commands = bit.bor(move.commands, Move.Weapon2)
        end
        if _keyPressed[ _keyBinding.Weapon3 ] then
            move.commands = bit.bor(move.commands, Move.Weapon3)
        end
        if _keyPressed[ _keyBinding.Weapon4 ] then
            move.commands = bit.bor(move.commands, Move.Weapon4)
        end
        if _keyPressed[ _keyBinding.Weapon5 ] then
            move.commands = bit.bor(move.commands, Move.Weapon5)
        end
        
        // Process FPS actions only if mouse captured
        if not Client.GetMouseVisible() then
        
            if _keyState[ _keyBinding.Use ] then
                move.commands = bit.bor(move.commands, Move.Use)
            end
            if _keyPressed[ _keyBinding.ToggleFlashlight ] then
                move.commands = bit.bor(move.commands, Move.ToggleFlashlight)
            end
            if _keyState[ _keyBinding.PrimaryAttack ] then
                move.commands = bit.bor(move.commands, Move.PrimaryAttack)
            end
            if _keyState[ _keyBinding.SecondaryAttack ] then
                move.commands = bit.bor(move.commands, Move.SecondaryAttack)
            end
            if _keyState[ _keyBinding.Reload ] then
                move.commands = bit.bor(move.commands, Move.Reload)
            end
                
            if _keyPressed[ _keyBinding.Drop ] then
                move.commands = bit.bor(move.commands, Move.Drop)
            end
          
            if _keyPressed[ _keyBinding.Taunt ] then
                move.commands = bit.bor(move.commands, Move.Taunt)
            end

        end
        
        // Handle the hot keys used for commander mode.
        
        if _keyPressed[ _keyBinding.Q ] then
            move.hotkey = Move.Q
        end 
        if _keyPressed[ _keyBinding.W ] then
            move.hotkey = Move.W
        end 
        if _keyPressed[ _keyBinding.E ] then
            move.hotkey = Move.E
        end 
        if _keyPressed[ _keyBinding.R ] then
            move.hotkey = Move.R
        end 
        if _keyPressed[ _keyBinding.T ] then
            move.hotkey = Move.T
        end 
        if _keyPressed[ _keyBinding.Y ] then
            move.hotkey = Move.Y
        end         
        if _keyPressed[ _keyBinding.U ] then
            move.hotkey = Move.U
        end 
        if _keyPressed[ _keyBinding.I ] then
            move.hotkey = Move.I
        end 
        if _keyPressed[ _keyBinding.O ] then
            move.hotkey = Move.O
        end 
        if _keyPressed[ _keyBinding.P ] then
            move.hotkey = Move.P
        end  
        if _keyPressed[ _keyBinding.A ] then
            move.hotkey = Move.A
        end   
        if _keyPressed[ _keyBinding.S ] then
            move.hotkey = Move.S
        end     
        if _keyPressed[ _keyBinding.D ] then
            move.hotkey = Move.D
        end     
        if _keyPressed[ _keyBinding.F ] then
            move.hotkey = Move.F
        end       
        if _keyPressed[ _keyBinding.G ] then
            move.hotkey = Move.G
        end       
        if _keyPressed[ _keyBinding.H ] then
            move.hotkey = Move.H
        end   
        if _keyPressed[ _keyBinding.J ] then
            move.hotkey = Move.J
        end         
        if _keyPressed[ _keyBinding.K ] then
            move.hotkey = Move.K
        end         
        if _keyPressed[ _keyBinding.L ] then
            move.hotkey = Move.L
        end         
        if _keyPressed[ _keyBinding.Z ] then
            move.hotkey = Move.Z
        end         
        if _keyPressed[ _keyBinding.X ] then
            move.hotkey = Move.X
        end   
        if _keyPressed[ _keyBinding.C ] then
            move.hotkey = Move.C
        end   
        if _keyPressed[ _keyBinding.V ] then
            move.hotkey = Move.V
        end   
        if _keyPressed[ _keyBinding.B ] then
            move.hotkey = Move.B
        end
        if _keyPressed[ _keyBinding.N ] then
            move.hotkey = Move.N
        end
        if _keyPressed[ _keyBinding.M ] then
            move.hotkey = Move.M
        end
        if _keyPressed[ _keyBinding.Space ] then
            move.hotkey = Move.Space
        end
        if _keyPressed[ _keyBinding.ESC ] then
            move.hotkey = Move.ESC
        end
        
        // Allow the player to override move (needed for Commander)
        local player = Client.GetLocalPlayer()
        if player and Client.GetIsControllingPlayer() then
            move = player:OverrideInput(move)
        end
        
        _keyPressed = { }
        
    end
    
    return move
    
end

local function BufferMove(move)

    _bufferedMove.x = math.max(math.min(_bufferedMove.x + move.move.x, 1), -1)
    _bufferedMove.y = math.max(math.min(_bufferedMove.y + move.move.y, 1), -1)
    _bufferedMove.z = math.max(math.min(_bufferedMove.z + move.move.z, 1), -1)

    // Detect changes in the commands
    local changedCommands = bit.bxor( _lastProcessedCommands, _bufferedCommands )
    _bufferedCommands = bit.bor(
            bit.band( _bufferedCommands, changedCommands ), 
            bit.band( move.commands, bit.bnot(changedCommands) )
        )
        
    if move.hotkey ~= 0 then
        _bufferedHotKey = move.hotkey
    end
    
end

local function OnProcessGameInput()

    local move = GenerateMove()
    BufferMove(move)
    
    // Apply the buffered input.
    
    move.move     = _bufferedMove
    move.commands = _bufferedCommands

    if _bufferedHotKey ~= 0 then
        move.hotkey = _bufferedHotKey
        _bufferedHotKey = 0
    end    
    
    _lastProcessedCommands = _bufferedCommands
    _bufferedMove          = Vector(0, 0, 0)
    
    return move

end

local function OnProcessMouseInput()
    local move = GenerateMove()
    BufferMove(move)
    return move
end

Event.Hook("ProcessGameInput",      OnProcessGameInput)
Event.Hook("ProcessMouseInput",     OnProcessMouseInput)
Event.Hook("SendKeyEvent",          OnSendKeyEvent)
Event.Hook("SendCharacterEvent",    OnSendCharacterEvent)