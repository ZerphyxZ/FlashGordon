--[[
    RespawnController.luau

    A Knit controller that binds the respawn UI button and keyboard
    input to a local respawn action.  When the player holds the
    Respawn button for at least one second or holds the `R` key for
    at least one second, this controller teleports the player's
    character to their last saved checkpoint.  The last checkpoint is
    replicated via the attributes `CheckpointX`, `CheckpointY` and
    `CheckpointZ` on the player.  If no checkpoint is recorded, the
    controller falls back to the character's current position or does
    nothing.

    By performing the teleport client‑side, we avoid needing to
    communicate with the server for respawns.  This aligns with the
    requirement to avoid custom remote events or RemoteFunctions.

    Place this script in `StarterPlayer → StarterPlayerScripts → Client → Controllers`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local RespawnController = Knit.CreateController { Name = "RespawnController" }

-- Debug message when the controller module is loaded
print("[RespawnController] Controller module loaded")

-- KnitStart is called by Knit after all controllers and services have been initialized.
function RespawnController:KnitStart()
    print("[RespawnController] KnitStart called")
    local player = Players.LocalPlayer
    -- Wait for the player's GUI to be present.  This yields until the
    -- PlayerGui and required descendants are available.
    local gui = player:WaitForChild("PlayerGui")
    local mainGui = gui:WaitForChild("MainGui")
    local respawnFrame = mainGui:WaitForChild("RespawnClientFrame")
    local respawnButton = respawnFrame:WaitForChild("RespawnButton")

    -- Helper to perform the teleport.  Invokes the server-side
    -- RequestRespawn method on CheckpointService.  Knit handles
    -- passing the local player automatically.
    local function teleportToCheckpoint()
        local checkpointService = Knit.GetService("CheckpointService")
        local ok, result = pcall(function()
            return checkpointService:RequestRespawn()
        end)
        if ok then
            print("[RespawnController] Requested respawn; server returned", result)
        else
            warn("[RespawnController] Failed to request respawn:", result)
        end
    end

    -- Variables to track holding state
    local isHoldingButton = false
    local buttonHoldStart = 0
    local isHoldingKey = false
    local keyHoldStart = 0

    -- Called when the button is pressed down.  Records the time and
    -- starts the hold state.  A delayed task checks if the hold
    -- duration reaches the threshold; if so, it teleports.
    local function onButtonDown()
        if isHoldingButton then return end
        isHoldingButton = true
        buttonHoldStart = os.clock()
        task.delay(1.0, function()
            if isHoldingButton and (os.clock() - buttonHoldStart >= 1.0) then
                teleportToCheckpoint()
                isHoldingButton = false
            end
        end)
    end

    local function onButtonUp()
        isHoldingButton = false
    end

    -- Connect button down/up events.  Use MouseButton1Down/Up so we
    -- detect holding rather than click.
    respawnButton.MouseButton1Down:Connect(onButtonDown)
    respawnButton.MouseButton1Up:Connect(onButtonUp)

    -- Set up keyboard handling for the "R" key.  When the player
    -- holds R for at least one second, teleport them to the checkpoint.
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.R then
            if isHoldingKey then return end
            isHoldingKey = true
            keyHoldStart = os.clock()
            task.delay(1.0, function()
                if isHoldingKey and (os.clock() - keyHoldStart >= 1.0) then
                    teleportToCheckpoint()
                    isHoldingKey = false
                end
            end)
        end
    end)
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.R then
            isHoldingKey = false
        end
    end)
end

return RespawnController