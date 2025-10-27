-- RespawnService.lua
-- Slightly more robust: small post-LoadCharacter wait before updating progress.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local PlayerDataHandler = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local RespawnService = Knit.CreateService {
    Name = "RespawnService";
    Client = {};
}

print("[RespawnService] Service module loaded (improved)")

local function applyProfileToPlayer(player, data)
    if not player or not data then return end

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local coinsVal = leaderstats:FindFirstChild("Coins")
    if not coinsVal then
        coinsVal = Instance.new("IntValue")
        coinsVal.Name = "Coins"
        coinsVal.Parent = leaderstats
    end

    local coins = data.Coins or 0
    coinsVal.Value = coins
    player:SetAttribute("Coins", coins)

    if data.LastCheckpoint and type(data.LastCheckpoint) == "table" and data.LastCheckpoint[1] then
        local cx, cy, cz = data.LastCheckpoint[1], data.LastCheckpoint[2], data.LastCheckpoint[3]
        player:SetAttribute("CheckpointX", cx)
        player:SetAttribute("CheckpointY", cy)
        player:SetAttribute("CheckpointZ", cz)
    else
        player:SetAttribute("CheckpointX", nil)
        player:SetAttribute("CheckpointY", nil)
        player:SetAttribute("CheckpointZ", nil)
    end
end

local function waitForProfileData(player, timeout)
    timeout = timeout or 3
    local elapsed  = 0
    local interval = 0.15
    while elapsed < timeout do
        local pdata = PlayerDataHandler:GetData(player)
        if pdata then return pdata end
        task.wait(interval)
        elapsed += interval
    end
    return nil
end

function RespawnService.Client:Respawn(player)
    if not (player and player:IsA("Player")) then
        warn("[RespawnService] Respawn called without a valid player")
        return false
    end

    print("[RespawnService] Respawn requested by", player.Name)

    local pdata = PlayerDataHandler:GetData(player)
    if not pdata then
        print("[RespawnService] Profile data not immediately available for", player.Name, "- waiting briefly")
        pdata = waitForProfileData(player, 3)
    end

    if pdata then
        applyProfileToPlayer(player, pdata)
        print("[RespawnService] Applied profile values BEFORE LoadCharacter for", player.Name, "Coins:", tostring(pdata.Coins))
    else
        warn("[RespawnService] Could not find profile data to apply before respawn for", player.Name)
    end

    player:LoadCharacter()

    -- brief stabilization
    task.delay(0.1, function()
        local deathService = Knit.GetService("DeathService")
        if deathService and deathService.SetAlive then
            deathService:SetAlive(player)
        end

        local progressService = Knit.GetService("ProgressBarService")
        if progressService and progressService.UpdatePlayerNow then
            progressService:UpdatePlayerNow(player)
        end

        print("[RespawnService] Completed Respawn for", player.Name)
    end)

    return true
end

return RespawnService
