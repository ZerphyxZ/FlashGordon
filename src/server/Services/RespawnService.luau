-- ServerScriptService/Server/Services/RespawnService.luau
-- Applies the *current world's* saved checkpoint to player attributes,
-- then respawns (LoadCharacter) and restores state/progress.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local RespawnService = Knit.CreateService {
    Name = "RespawnService";
    Client = {};
}

print("[RespawnService] Service module loaded (per-world aware)")

-- ---------- helpers ----------------------------------------------------------

local function getCurrentWorldIndex(player: Player): number
    local idx = player and player:GetAttribute("WorldIndex")
    if typeof(idx) ~= "number" then
        idx = ReplicatedStorage:GetAttribute("WorldIndex")
    end
    if typeof(idx) ~= "number" or idx < 1 then idx = 1 end
    return idx
end

local function applyProfileToPlayer(player: Player, data: table)
    if not player or not data then return end

    -- Coins/leaderstats (unchanged)
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

    -- Per-world checkpoint → attributes
    local w  = getCurrentWorldIndex(player)
    data.LastCheckpointByWorld = data.LastCheckpointByWorld or {}
    local cp = data.LastCheckpointByWorld[w]

    if cp and type(cp) == "table" and cp[1] ~= nil then
        player:SetAttribute("CheckpointX", cp[1])
        player:SetAttribute("CheckpointY", cp[2])
        player:SetAttribute("CheckpointZ", cp[3])
        print(("[RespawnService] Using saved checkpoint for %s in world %d → (%.2f, %.2f, %.2f)")
            :format(player.Name, w, cp[1], cp[2], cp[3]))
    else
        player:SetAttribute("CheckpointX", nil)
        player:SetAttribute("CheckpointY", nil)
        player:SetAttribute("CheckpointZ", nil)
        print(("[RespawnService] No saved checkpoint for %s in world %d"):format(player.Name, w))
    end
end

local function waitForProfileData(player: Player, timeout: number?)
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

-- ---------- client RPC -------------------------------------------------------

function RespawnService.Client:Respawn(player: Player)
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
        print("[RespawnService] Applied profile BEFORE LoadCharacter for", player.Name, "Coins:", tostring(pdata.Coins))
    else
        warn("[RespawnService] Could not find profile data to apply before respawn for", player.Name)
    end

    player:LoadCharacter()

    -- small settle, then clear death flag and update progress for this world
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
