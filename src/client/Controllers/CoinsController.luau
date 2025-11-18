-- CoinsController.luau
-- Robust: rebinds if PlayerGui.MainGui or leaderstats is recreated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local CoinsController = Knit.CreateController { Name = "CoinsController" }

local player = Players.LocalPlayer

print("[CoinsController] Controller module loaded (robust)")

-- state for dynamic listeners
local leaderstatsConn = nil
local coinsValueConn = nil
local attributeConn = nil
local playerGuiConn = nil
local mainGuiRef = nil

-- utility: safely fetch current CoinsTextLabel (may have been recreated)
local function getCoinsTextLabel()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local mainGui = gui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local coinsFrame = mainGui:FindFirstChild("CoinsFrame")
    if not coinsFrame then return nil end
    return coinsFrame:FindFirstChild("CoinsTextLabel")
end

-- update display (always fetch the label dynamically)
local function updateCoinsDisplay()
    local coins
    -- prefer leaderstats IntValue (backwards compat)
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local coinsVal = ls:FindFirstChild("Coins")
        if coinsVal then
            coins = coinsVal.Value
        end
    end
    -- fallback to attribute
    if coins == nil then
        coins = player:GetAttribute("Coins")
    end

    local label = getCoinsTextLabel()
    if label and label:IsA("TextLabel") then
        label.Text = tostring(coins or 0)
    else
        -- safe debug if label not present
        -- print("[CoinsController] Coins label not found (maybe GUI was recreated).")
    end
end

-- Ensure we have a connection to leaderstats.Coins Value changes
local function connectLeaderstatsValue()
    -- disconnect old
    if coinsValueConn then
        pcall(function() coinsValueConn:Disconnect() end)
        coinsValueConn = nil
    end

    local ls = player:FindFirstChild("leaderstats")
    if ls then
        local coinsVal = ls:FindFirstChild("Coins")
        if coinsVal then
            -- Use Changed or GetPropertyChangedSignal; both work for IntValue
            coinsValueConn = coinsVal:GetPropertyChangedSignal("Value"):Connect(updateCoinsDisplay)
        end
    end
end

-- Called when PlayerGui children change (MainGui may be recreated on spawn)
local function onPlayerGuiChildAdded(child)
    if child and child.Name == "MainGui" then
        -- small delay to let children initialize
        task.delay(0.05, updateCoinsDisplay)
    end
end

function CoinsController:KnitStart()
    print("[CoinsController] KnitStart called")

    -- initial display attempt
    updateCoinsDisplay()

    -- connect to attribute changes
    if attributeConn then
        attributeConn:Disconnect()
        attributeConn = nil
    end
    attributeConn = player:GetAttributeChangedSignal("Coins"):Connect(updateCoinsDisplay)

    -- ensure leaderstats listener is present and rebind if leaderstats gets created later
    connectLeaderstatsValue()
    -- watch for leaderstats being added/removed on the player
    if player then
        if playerGuiConn then
            playerGuiConn:Disconnect()
            playerGuiConn = nil
        end
        player.ChildAdded:Connect(function(child)
            if child and child.Name == "leaderstats" then
                -- leaderstats created - (re)connect
                connectLeaderstatsValue()
                -- update display immediately
                task.defer(updateCoinsDisplay)
            end
        end)
        -- Also watch for leaderstats removal so we can reconnect if necessary
        player.ChildRemoved:Connect(function(child)
            if child and child.Name == "leaderstats" then
                connectLeaderstatsValue()
                task.defer(updateCoinsDisplay)
            end
        end)
    end

    -- Watch PlayerGui for MainGui recreation (ResetOnSpawn behavior)
    local pGui = player:FindFirstChild("PlayerGui")
    if pGui then
        -- reconnect on new MainGui
        playerGuiConn = pGui.ChildAdded:Connect(onPlayerGuiChildAdded)
    else
        -- Wait for PlayerGui if not yet present
        player:GetPropertyChangedSignal("Parent"):Connect(function()
            -- no-op: this is just defensive; PlayerGui normally exists
        end)
        task.spawn(function()
            local g = player:WaitForChild("PlayerGui")
            if g then
                playerGuiConn = g.ChildAdded:Connect(onPlayerGuiChildAdded)
            end
        end)
    end
end

function CoinsController:RefreshDisplay()
    -- Public: lets other controllers force a HUD refresh on demand
    updateCoinsDisplay()
end

return CoinsController