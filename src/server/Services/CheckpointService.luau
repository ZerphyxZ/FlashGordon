-- CheckpointService.lua
-- Pure client-side coloring: server no longer edits Workspace flag colors.
-- Publishes per-player attributes the client uses to paint locally:
--   * VisitedCheckpointsBlob (csv)
--   * LastVisitedCheckpointKey (string)
-- Also exposes GetVisitedCheckpointKeys() for client fallback fetch.

local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit          = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local CheckpointService = Knit.CreateService {
    Name = "CheckpointService";
    Client = {};
}

print("[CheckpointService] Service module loaded")

local sessionCheckpointFlags = {}

-- Convert Vector3 to table for storage in ProfileService data if needed
local function vectorToTable(vec) return {vec.X, vec.Y, vec.Z} end

local function awardCoins(player, amount)
    local ok, cs = pcall(function() return Knit.GetService("CurrencyService") end)
    if ok and cs and cs.AwardCoins then
        cs:AwardCoins(player, amount)
    else
        warn("[CheckpointService] CurrencyService not available to award coins")
    end
end

function CheckpointService:ClearPlayerSessionFlags(player)
    if player then
        sessionCheckpointFlags[player] = nil
        print("[CheckpointService] Cleared session checkpoint flags for", player.Name)
    end
end

local function isCheckpointName(name)
    if not name then return false end
    return tostring(name):lower():match("^checkpoint_l%d+_i%d+$") ~= nil
end

-- Resolve a checkpoint "key" to a BasePart in Workspace
local function findCheckpointPartByKey(key)
    if not key then return nil end
    local folder = Workspace:FindFirstChild("Checkpoints")
    if not folder then return nil end
    local lowerKey = tostring(key):lower()

    local direct = folder:FindFirstChild(key) or folder:FindFirstChild(lowerKey)
    if direct and direct:IsA("BasePart") then return direct end

    for _, desc in ipairs(folder:GetDescendants()) do
        if desc:IsA("BasePart") and tostring(desc.Name):lower() == lowerKey then
            return desc
        end
    end
    return nil
end

-- Persist "visited" (ProfileService-backed)
local function persistMarkCheckpointVisited(player, checkpointKey)
    if PlayerDataHandler.MarkCheckpointVisited then
        PlayerDataHandler:MarkCheckpointVisited(player, checkpointKey)
        return
    end
    local profile = PlayerDataHandler:GetProfile(player)
    if profile and profile:IsActive() then
        profile.Data.VisitedCheckpoints = profile.Data.VisitedCheckpoints or {}
        profile.Data.VisitedCheckpoints[checkpointKey] = true
        pcall(function() profile:Save() end)
    else
        warn("[CheckpointService] persistMarkCheckpointVisited: profile not active for", player.Name)
    end
end

-- Build "visited csv" and publish to player's attribute so client can paint locally
local function publishVisitedBlobForPlayer(player)
    local data = PlayerDataHandler:GetData(player)
    local csv = ""
    if data and data.VisitedCheckpoints then
        local buffer = {}
        for k, v in pairs(data.VisitedCheckpoints) do
            if v then
                table.insert(buffer, tostring(k):lower())
            end
        end
        table.sort(buffer)
        csv = table.concat(buffer, ",")
    end
    player:SetAttribute("VisitedCheckpointsBlob", csv)
    -- Also useful to send current count:
    local count = 0
    if csv ~= "" then
        for _ in string.gmatch(csv, "([^,]+)") do count += 1 end
    end
    player:SetAttribute("VisitedCount", count)
end

-- Client-callable: fallback fetch of visited keys
function CheckpointService.Client:GetVisitedCheckpointKeys(player)
    local data = PlayerDataHandler:GetData(player)
    local t = {}
    if data and data.VisitedCheckpoints then
        for k, v in pairs(data.VisitedCheckpoints) do
            if v then table.insert(t, tostring(k):lower()) end
        end
        table.sort(t)
    end
    return t
end

-- Optional helper: wait for PlayerData
local function waitForPlayerData(player, timeout)
    timeout = timeout or 2
    local elapsed, step = 0, 0.1
    while elapsed < timeout do
        local d = PlayerDataHandler:GetData(player)
        if d then return d end
        task.wait(step)
        elapsed += step
    end
    return nil
end

-- Connect touch behaviour to a checkpoint part (NO server-side color edits)
function CheckpointService:ConnectCheckpointPart(part)
    print("[CheckpointService] Connecting checkpoint part", part:GetFullName())
    part.Touched:Connect(function(hit)
        local character = hit and hit.Parent
        if not (character and character:FindFirstChild("Humanoid")) then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- Robust: wait for data if temporarily nil (e.g., right after a reset)
        local data = PlayerDataHandler:GetData(player) or waitForPlayerData(player, 2)
        if not data then
            warn("[CheckpointService] No data available for", player.Name, "(touch ignored)")
            return
        end

        local checkpointKey = tostring(part.Name):lower()
        sessionCheckpointFlags[player] = sessionCheckpointFlags[player] or {}
        if sessionCheckpointFlags[player][checkpointKey] then
            return
        end

        -- Already visited?
        if PlayerDataHandler.HasVisitedCheckpoint and PlayerDataHandler:HasVisitedCheckpoint(player, checkpointKey) then
            print("[CheckpointService] Already visited (persisted):", checkpointKey, "for", player.Name)
            return
        elseif data.VisitedCheckpoints and data.VisitedCheckpoints[checkpointKey] then
            print("[CheckpointService] Already visited (data):", checkpointKey, "for", player.Name)
            return
        end

        sessionCheckpointFlags[player][checkpointKey] = true

        local posTable = vectorToTable(part.Position)

        -- persist visited
        persistMarkCheckpointVisited(player, checkpointKey)

        -- update last checkpoint pos in profile
        PlayerDataHandler:SetLastCheckpoint(player, posTable)

        -- replicate to attributes (teleport uses these)
        player:SetAttribute("CheckpointX", posTable[1])
        player:SetAttribute("CheckpointY", posTable[2])
        player:SetAttribute("CheckpointZ", posTable[3])

        -- **NEW**: publish per-player visited csv + immediate event for client color
        publishVisitedBlobForPlayer(player)
        player:SetAttribute("LastVisitedCheckpointKey", checkpointKey)

        awardCoins(player, 5)
        print("[CheckpointService] First visit: awarded coins + saved checkpoint for", player.Name, part:GetFullName())

        -- notify progress service (defensive)
        local ok, progressService = pcall(function() return Knit.GetService("ProgressBarService") end)
        if ok and progressService and progressService.UpdatePlayerNow then
            progressService:UpdatePlayerNow(player)
        end
    end)
end

function CheckpointService:KnitStart()
    local folder = Workspace:FindFirstChild("Checkpoints")
    if not folder then
        warn("[CheckpointService] workspace.Checkpoints folder not found")
        return
    end
    print("[CheckpointService] Found Checkpoints folder", folder:GetFullName())

    local CHECKPOINT_PATTERN = "^checkpoint_l%d+_i%d+$"
    local function isCheckpointPart(p)
        if not p or not p:IsA("BasePart") then return false end
        return tostring(p.Name):lower():match(CHECKPOINT_PATTERN) ~= nil
    end

    for _, descendant in ipairs(folder:GetDescendants()) do
        if isCheckpointPart(descendant) then
            self:ConnectCheckpointPart(descendant)
        end
    end

    folder.DescendantAdded:Connect(function(child)
        if isCheckpointPart(child) then
            self:ConnectCheckpointPart(child)
        end
    end)

    -- On join: publish initial blob so client can paint immediately
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            -- Wait for profile data to exist (timeout after ~10s)
            local timeout = 10
            local waited = 0
            while waited < timeout do
                local data = PlayerDataHandler:GetData(player)
                if data then
                    publishVisitedBlobForPlayer(player)
                    return
                end
                task.wait(0.25)
                waited = waited + 0.25
            end
            warn("[CheckpointService] Timed out waiting for profile data for player:", player.Name)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        sessionCheckpointFlags[player] = nil
    end)
end

-- Client-callable respawn (teleport to saved checkpoint or StartSpawn)
function CheckpointService.Client:RequestRespawn(player)
    if not player then return false end
    local cx = player:GetAttribute("CheckpointX")
    local cy = player:GetAttribute("CheckpointY")
    local cz = player:GetAttribute("CheckpointZ")
    local teleported = false
    if cx and cy and cz then
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(cx, cy, cz)
            teleported = true
            print("[CheckpointService] Teleported", player.Name, "to saved checkpoint via RequestRespawn")
        end
    end
    if not teleported then
        local startSpawn = Workspace:FindFirstChild("StartSpawn")
        if startSpawn and startSpawn:IsA("BasePart") then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = startSpawn.CFrame + Vector3.new(0, 3, 0)
                teleported = true
                print("[CheckpointService] Teleported", player.Name, "to StartSpawn (fallback) via RequestRespawn")
            end
        end
    end
    return teleported
end

return CheckpointService
