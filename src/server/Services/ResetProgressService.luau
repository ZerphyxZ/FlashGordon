-- ResetProgressService.lua
-- Server-side Knit service that handles full progress resets safely.
-- Now: always reloads the character after reset, clears attributes,
-- clears session debounces, and publishes per-player repaint pulses only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local PlayerDataHandler   = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local PlayerDataTemplate  = require(game.ReplicatedStorage.Shared.Modules.PlayerDataTemplate)

local ResetProgressService = Knit.CreateService {
    Name = "ResetProgressService";
    Client = {};
}

print("[ResetProgressService] Loaded (server)")

-- Debounce table keyed by player → touched part keys (for Reset parts)
local debounceMap = {}

-- Show reset UI for player; hide after 10s if not confirmed
local function showResetUIForPlayer(player, part)
    if not player or not player:IsA("Player") then return end
    player:SetAttribute("ResetUI", true)
    player:SetAttribute("ResetUIFromPart", tostring(part.Name))
    player:SetAttribute("ResetResult", nil)
    player:SetAttribute("ResetResultMsg", nil)

    task.delay(10, function()
        if player and player.Parent and player:GetAttribute("ResetUI") == true then
            player:SetAttribute("ResetUI", false)
            player:SetAttribute("ResetUIFromPart", nil)
        end
    end)
end

-- Connect touch detection on a Reset_%d part
local function connectResetPart(part)
    if not (part and part:IsA("BasePart")) then return end
    print("[ResetProgressService] Connecting Reset part:", part:GetFullName())
    part.Touched:Connect(function(hit)
        local character = hit and hit.Parent
        if not (character and character:FindFirstChild("Humanoid")) then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        debounceMap[player] = debounceMap[player] or {}
        local partKey = part:GetFullName()
        if debounceMap[player][partKey] then return end
        debounceMap[player][partKey] = true
        task.delay(1.0, function()
            if debounceMap[player] then debounceMap[player][partKey] = nil end
        end)

        showResetUIForPlayer(player, part)
    end)
end

function ResetProgressService:KnitStart()
    print("[ResetProgressService] KnitStart - scanning workspace.Reset")
    local resetFolder = Workspace:FindFirstChild("Reset")
    if resetFolder then
        for _, desc in ipairs(resetFolder:GetDescendants()) do
            if desc:IsA("BasePart") and tostring(desc.Name):match("^Reset_%d+$") then
                connectResetPart(desc)
            end
        end
        resetFolder.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") and tostring(desc.Name):match("^Reset_%d+$") then
                connectResetPart(desc)
            end
        end)
    else
        warn("[ResetProgressService] workspace.Reset folder not found.")
    end

    Players.PlayerRemoving:Connect(function(player)
        debounceMap[player] = nil
    end)
end

-- Deep copy helper (fallback)
local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in next, orig do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

-- Fallback reset if handler helper missing
local function fallbackResetProfileToTemplate(player)
    local profile = PlayerDataHandler:GetProfile(player)
    if not profile then
        return false, "No active profile"
    end
    if not profile:IsActive() then
        return false, "Profile not active"
    end
    profile.Data = deepCopy(PlayerDataTemplate)
    local ok, err = pcall(function() profile:Save() end)
    if not ok then
        return false, "Save failed: " .. tostring(err)
    end
    return true, "Reset via fallback succeeded"
end

-- Helper: brief wait for PlayerDataHandler:GetData(player) to become non-nil
local function waitForDataAvailable(player, timeout)
    timeout = timeout or 3
    local t = 0
    while t < timeout do
        local d = PlayerDataHandler:GetData(player)
        if d then return d end
        task.wait(0.1)
        t += 0.1
    end
    return nil
end

-- Client-callable: perform a progress reset (player has confirmed)
function ResetProgressService.Client:RequestReset(player)
    if not (player and player:IsA("Player")) then return false end
    print("[ResetProgressService] Reset requested by", player.Name)

    -- Wait briefly for profile to load
    local timeout = 5
    local waited  = 0
    while not PlayerDataHandler:GetProfile(player) and waited < timeout do
        task.wait(0.25)
        waited = waited + 0.25
    end

    local profile = PlayerDataHandler:GetProfile(player)
    if not profile then
        warn("[ResetProgressService] No active profile for", player.Name)
        player:SetAttribute("ResetResult", "Failure")
        player:SetAttribute("ResetResultMsg", "Profile not active")
        player:SetAttribute("ResetUI", false)
        return false
    end

    -- Gather visited keys before reset (for optional visuals; retained for analytics)
    local dataBefore = PlayerDataHandler:GetData(player)
    local visitedKeys = {}
    if dataBefore and dataBefore.VisitedCheckpoints then
        for k, v in pairs(dataBefore.VisitedCheckpoints) do
            if v then table.insert(visitedKeys, k) end
        end
    end
    print("[ResetProgressService] Visited before reset:", #visitedKeys)

    -- Perform reset
    local success, msg
    if PlayerDataHandler.ResetProfileToTemplate then
        success, msg = PlayerDataHandler:ResetProfileToTemplate(player)
    else
        success, msg = fallbackResetProfileToTemplate(player)
    end

    if not success then
        warn("[ResetProgressService] Reset FAILED for", player.Name, tostring(msg))
        player:SetAttribute("ResetResult", "Failure")
        player:SetAttribute("ResetResultMsg", tostring(msg))
        player:SetAttribute("ResetUI", false)
        return false
    end
    print("[ResetProgressService] Profile reset OK for", player.Name, "-", tostring(msg))

    -- Clear session flags so the very next touch at any checkpoint is treated as first-visit
    local cpService = Knit.GetService("CheckpointService")
    if cpService and cpService.ClearPlayerSessionFlags then
        cpService:ClearPlayerSessionFlags(player)
        print("[ResetProgressService] Cleared session flags for", player.Name)
    end

    -- Clear client-facing attributes for checkpoints & progress
    player:SetAttribute("CheckpointX", nil)
    player:SetAttribute("CheckpointY", nil)
    player:SetAttribute("CheckpointZ", nil)
    player:SetAttribute("VisitedCheckpointsBlob", "") -- IMPORTANT: tell client no visits
    player:SetAttribute("LastVisitedCheckpointKey", nil)
    player:SetAttribute("ProgressPercent", 0)
    player:SetAttribute("VisitedCount", 0)

    -- Per-player repaint pulse (client will repaint ONLY for this player)
    player:SetAttribute("ResetProgressColours", true)
    task.delay(0.1, function()
        if player and player.Parent == Players then
            player:SetAttribute("ResetProgressColours", false)
        end
    end)

    -- Hide UI and mark result
    player:SetAttribute("ResetUI", false)
    player:SetAttribute("ResetResult", "Success")
    player:SetAttribute("ResetResultMsg", "Reset complete")

    -- Always reload character to get a clean slate after reset
    print("[ResetProgressService] Loading character for", player.Name, "after reset …")
    player:LoadCharacter()

    -- Brief wait for new character and profile rehydrate, then update progress
    task.spawn(function()
        -- allow data to reappear (ProfileService flush can take a few frames)
        local data = waitForDataAvailable(player, 3)
        if not data then
            warn("[ResetProgressService] Data did not rehydrate quickly for", player.Name, "continuing anyway")
        end

        local progressService = Knit.GetService("ProgressBarService")
        if progressService and progressService.UpdatePlayerNow then
            progressService:UpdatePlayerNow(player)
            print("[ResetProgressService] ProgressBar updated post-reset for", player.Name)
        end

        -- Make sure they are considered alive again (for any death gating)
        local deathService = Knit.GetService("DeathService")
        if deathService and deathService.SetAlive then
            deathService:SetAlive(player)
        end
    end)

    print("[ResetProgressService] Reset completed for", player.Name)
    return true
end

return ResetProgressService
