-- ServerScriptService/Server/Services/ResetProgressService.lua
-- Server-side Knit service that handles full progress resets safely.
-- UPDATED: Finds Reset parts anywhere under Workspace (not just Workspace.Reset)
-- and hooks them dynamically as worlds are loaded/changed.

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

-- ==== UI attribute helpers ====

local function showResetUIForPlayer(player, part)
    if not player or not player:IsA("Player") then return end
    -- Open instantly, every time
    player:SetAttribute("ResetUI", true)
    player:SetAttribute("ResetUIFromPart", tostring(part and part.Name or "Reset"))
    player:SetAttribute("ResetResult", nil)
    player:SetAttribute("ResetResultMsg", nil)

    -- Auto-close after 10s if ignored
    task.delay(30, function()
        if player and player.Parent and player:GetAttribute("ResetUI") == true then
            player:SetAttribute("ResetUI", false)
            player:SetAttribute("ResetUIFromPart", nil)
        end
    end)
end

-- ==== Touch wiring ====

local CONNECTED = setmetatable({}, { __mode = "k" }) -- weak keys: BasePart → true

local function isResetTouchPart(inst: Instance?): boolean
    if not (inst and inst:IsA("BasePart")) then return false end
    return tostring(inst.Name):match("^Reset_%d+$") ~= nil
end

local function connectResetPart(part: BasePart)
    if not (part and part:IsA("BasePart")) then return end
    if CONNECTED[part] then return end
    CONNECTED[part] = true

    print("[ResetProgressService] Connecting Reset part:", part:GetFullName())
    part.Touched:Connect(function(hit)
        local character = hit and hit.Parent
        if not (character and character:FindFirstChild("Humanoid")) then return end
        local player = Players:GetPlayerFromCharacter(character)
        if not player then return end

        -- very small per-part debounce so Touched spam doesn’t flicker UI,
        -- but lets the player close and immediately re-open on a fresh step
        debounceMap[player] = debounceMap[player] or {}
        local partKey = part:GetFullName()
        if debounceMap[player][partKey] then return end
        debounceMap[player][partKey] = true
        task.delay(0.4, function()
            if debounceMap[player] then debounceMap[player][partKey] = nil end
        end)

        showResetUIForPlayer(player, part)
    end)
end

local function connectAllResetUnder(container: Instance)
    -- 1) Any folder named "Reset" at any depth
    for _, desc in ipairs(container:GetDescendants()) do
        if desc:IsA("Folder") and desc.Name == "Reset" then
            for _, d in ipairs(desc:GetDescendants()) do
                if isResetTouchPart(d) then
                    connectResetPart(d)
                end
            end
            desc.DescendantAdded:Connect(function(newInst)
                if isResetTouchPart(newInst) then
                    connectResetPart(newInst)
                end
            end)
        end
    end

    -- 2) Or any stray Reset_%d+ parts anywhere
    for _, desc in ipairs(container:GetDescendants()) do
        if isResetTouchPart(desc) then
            connectResetPart(desc)
        end
    end
end

function ResetProgressService:KnitStart()
    print("[ResetProgressService] KnitStart scanning Reset nodes across Workspace")

    -- Initial sweep
    connectAllResetUnder(Workspace)

    -- Live hook for worlds streamed/inserted later
    Workspace.DescendantAdded:Connect(function(inst)
        if inst:IsA("Folder") and inst.Name == "Reset" then
            for _, d in ipairs(inst:GetDescendants()) do
                if isResetTouchPart(d) then
                    connectResetPart(d)
                end
            end
            inst.DescendantAdded:Connect(function(d)
                if isResetTouchPart(d) then
                    connectResetPart(d)
                end
            end)
        elseif isResetTouchPart(inst) then
            connectResetPart(inst)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        debounceMap[player] = nil
    end)
end

-- ==== Deep copy fallback ====

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in next, orig do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

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

-- ==== Client API ====

function ResetProgressService.Client:RequestReset(player)
    if not (player and player:IsA("Player")) then return false end
    print("[ResetProgressService] Reset requested by", player.Name)

    -- Wait briefly for profile
    local timeout = 5
    local waited  = 0
    while not PlayerDataHandler:GetProfile(player) and waited < timeout do
        task.wait(0.25)
        waited += 0.25
    end

    local profile = PlayerDataHandler:GetProfile(player)
    if not profile then
        warn("[ResetProgressService] No active profile for", player.Name)
        player:SetAttribute("ResetResult", "Failure")
        player:SetAttribute("ResetResultMsg", "Profile not active")
        player:SetAttribute("ResetUI", false)
        return false
    end

    -- (optional analytics) count visited before reset
    local dataBefore = PlayerDataHandler:GetData(player)
    local visitedCount = 0
    if dataBefore and dataBefore.VisitedCheckpoints then
        for _, v in pairs(dataBefore.VisitedCheckpoints) do
            if v then visitedCount += 1 end
        end
    end
    print("[ResetProgressService] Visited before reset:", visitedCount)

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

    -- Clear session flags so the very next checkpoint counts again
    local cpService = Knit.GetService("CheckpointService")
    if cpService and cpService.ClearPlayerSessionFlags then
        cpService:ClearPlayerSessionFlags(player)
    end

    -- Clear client-facing attrs (progress + checkpoints)
    player:SetAttribute("CheckpointX", nil)
    player:SetAttribute("CheckpointY", nil)
    player:SetAttribute("CheckpointZ", nil)
    player:SetAttribute("VisitedCheckpointsBlob", "")
    player:SetAttribute("LastVisitedCheckpointKey", nil)
    player:SetAttribute("ProgressPercent", 0)
    player:SetAttribute("VisitedCount", 0)

    -- Pulse for repaint (LOCAL player only)
    player:SetAttribute("ResetProgressColours", true)
    task.delay(0.1, function()
        if player and player.Parent == Players then
            player:SetAttribute("ResetProgressColours", false)
        end
    end)

    -- Hide UI and flag success
    player:SetAttribute("ResetUI", false)
    player:SetAttribute("ResetResult", "Success")
    player:SetAttribute("ResetResultMsg", "Reset complete")

    -- Fresh character after reset
    player:LoadCharacter()

    -- Recompute progress once data rehydrates
    task.spawn(function()
        local _ = waitForDataAvailable(player, 3)
        local progressService = Knit.GetService("ProgressBarService")
        if progressService and progressService.UpdatePlayerNow then
            progressService:UpdatePlayerNow(player)
        end

        local deathService = Knit.GetService("DeathService")
        if deathService and deathService.SetAlive then
            deathService:SetAlive(player)
        end
    end)

    return true
end

return ResetProgressService
