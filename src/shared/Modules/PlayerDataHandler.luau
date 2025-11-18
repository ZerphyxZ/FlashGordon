-- ReplicatedStorage/Shared/Modules/PlayerDataHandler.luau
-- Per-world checkpoint/visited handling with legacy field mirroring.
-- Adds spin helpers used by SpinService (non-breaking).
-- DEBUG prints added.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTemplate = require(script.Parent:WaitForChild("PlayerDataTemplate"))
local ProfileService     = require(game.ServerScriptService.Server.Services.ProfileService)

local PlayerDataHandler = {}

print("[PlayerDataHandler] Module loaded")

local ProfileStore = ProfileService.GetProfileStore("PlayerData", PlayerDataTemplate)

local Profiles : {[Player]: any} = {}
local JoinTimes : {[Player]: number} = {}

-- Internal key used to tag which world the *flat snapshot* reflects.
-- This field is stored inside profile.Data and keeps migrations world-safe.
local FLAT_MIRROR_WORLD_KEY = "_FlatMirrorWorldIndex"

-- === helpers ================================================================

local function getCurrentWorldIndex(player: Player): number
    -- Prefer per-player attribute (set by WorldRouterService), else global.
    local idx = player:GetAttribute("WorldIndex")
    if typeof(idx) ~= "number" then
        idx = ReplicatedStorage:GetAttribute("WorldIndex")
    end
    if typeof(idx) ~= "number" then idx = 1 end
    if idx < 1 then idx = 1 end
    return idx
end

local function ensurePerWorldContainers(profileData: table)
    profileData.LastCheckpointByWorld = profileData.LastCheckpointByWorld or {}
    profileData.VisitedCheckpointsByWorld = profileData.VisitedCheckpointsByWorld or {}
end

-- Copy the *current* world's per-world data into legacy flat fields for
-- back-compat with existing systems (ProgressBarService, CheckpointService, etc.)
-- Also tag which world those flat fields represent so we can migrate safely later.
function PlayerDataHandler:SyncFlatToWorldSnapshot(player: Player)
    local profile = Profiles[player]
    if not profile or not profile:IsActive() then return end
    local data = profile.Data
    ensurePerWorldContainers(data)

    local w = getCurrentWorldIndex(player)
    local worldVisited = data.VisitedCheckpointsByWorld[w] or {}
    local worldCP      = data.LastCheckpointByWorld[w]

    -- mirror to legacy keys
    data.VisitedCheckpoints = {}
    for k, v in pairs(worldVisited) do
        if v then data.VisitedCheckpoints[k] = true end
    end
    data.LastCheckpoint = worldCP and { worldCP[1], worldCP[2], worldCP[3] } or nil

    -- Tag which world these flat fields belong to
    data[FLAT_MIRROR_WORLD_KEY] = w
    print(("[PlayerDataHandler] SyncFlatToWorldSnapshot → world %d mirrored to flat for %s"):format(w, player.Name))
end

-- When some older system writes to the legacy flat fields, this pushes those
-- values back into the *current* world’s slot. To avoid cross-place bleed,
-- we ONLY migrate if the flat snapshot is tagged for the same world.
function PlayerDataHandler:MigrateFlatToWorldForCurrent(player: Player)
    local profile = Profiles[player]
    if not profile or not profile:IsActive() then return end
    local data = profile.Data
    ensurePerWorldContainers(data)

    local w = getCurrentWorldIndex(player)

    -- World-safe guard: only migrate if the flat mirror matches current world.
    -- If there is no tag, we *skip migration* to avoid accidental bleed across worlds.
    local flatWorld = data[FLAT_MIRROR_WORLD_KEY]
    if typeof(flatWorld) ~= "number" or flatWorld ~= w then
        print(string.format(
            "[PlayerDataHandler] Skip migrate: flat belongs to world %s, current is %d (player=%s)",
            tostring(flatWorld), w, player.Name
        ))
        return
    end

    -- migrate LastCheckpoint
    if data.LastCheckpoint ~= nil then
        local lc = data.LastCheckpoint
        if type(lc) == "table" and lc[1] ~= nil then
            data.LastCheckpointByWorld[w] = { lc[1], lc[2], lc[3] }
        else
            data.LastCheckpointByWorld[w] = nil
        end
    end

    -- migrate VisitedCheckpoints
    if data.VisitedCheckpoints ~= nil then
        local byWorld = {}
        for k, v in pairs(data.VisitedCheckpoints) do
            if v then byWorld[string.lower(k)] = true end
        end
        data.VisitedCheckpointsByWorld[w] = byWorld
    end

    print(("[PlayerDataHandler] MigrateFlatToWorldForCurrent OK → world %d for %s"):format(w, player.Name))
end

-- === lifecycle ===============================================================

function PlayerDataHandler:LoadProfile(player: Player)
    print("[PlayerDataHandler] Loading profile for", player.Name)
    local key = "Player_v6_" .. tostring(player.UserId)
    local profile = ProfileStore:LoadProfileAsync(key)
    if profile then
        print("[PlayerDataHandler] Profile loaded for", player.Name)
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        ensurePerWorldContainers(profile.Data)

        profile:ListenToRelease(function()
            Profiles[player]  = nil
            JoinTimes[player] = nil
            if player and player.Parent then
                player:Kick("Data conflict: profile released elsewhere")
            end
        end)

        if player:IsDescendantOf(Players) then
            Profiles[player] = profile
            JoinTimes[player] = os.time()
            print("[PlayerDataHandler] Active profile data for", player.Name, profile.Data)
        else
            profile:Release()
        end
    else
        warn("[PlayerDataHandler] Failed to load profile for", player.Name)
        player:Kick("Failed to load your data. Please rejoin later.")
    end
end

function PlayerDataHandler:ReleaseProfile(player: Player)
    print("[PlayerDataHandler] Releasing profile for", player.Name)
    local profile = Profiles[player]
    if profile then
        local joinStamp = JoinTimes[player]
        if joinStamp then
            local elapsed = os.time() - joinStamp
            profile.Data.Playtime = (profile.Data.Playtime or 0) + elapsed
            print("[PlayerDataHandler] Added playtime", elapsed, "seconds for", player.Name)
        end
        JoinTimes[player] = nil
        pcall(function() profile:Save() end)
        profile:Release()
        print("[PlayerDataHandler] Profile released for", player.Name)
        Profiles[player] = nil
    end
end

function PlayerDataHandler:GetProfile(player: Player)
    return Profiles[player]
end

function PlayerDataHandler:GetData(player: Player)
    local profile = Profiles[player]
    if profile then
        return profile.Data
    end
    return nil
end

-- === currency ================================================================

function PlayerDataHandler:IncrementCoins(player: Player, amount: number)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        profile.Data.Coins = (profile.Data.Coins or 0) + amount
        print("[PlayerDataHandler] IncrementCoins: Added", amount, "coins to", player.Name, "new total", profile.Data.Coins)
        pcall(function() profile:Save() end)
    end
end

-- === checkpoints (per-world, with legacy mirror) =============================

function PlayerDataHandler:SetLastCheckpoint(player: Player, positionTable: {number})
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        ensurePerWorldContainers(profile.Data)
        local w = getCurrentWorldIndex(player)
        profile.Data.LastCheckpointByWorld[w] = { positionTable[1], positionTable[2], positionTable[3] }

        -- mirror to legacy field for back-compat AND tag which world it mirrors
        profile.Data.LastCheckpoint = { positionTable[1], positionTable[2], positionTable[3] }
        profile.Data[FLAT_MIRROR_WORLD_KEY] = w

        print("[PlayerDataHandler] SetLastCheckpoint (world", w, ") for", player.Name, "to", positionTable[1], positionTable[2], positionTable[3])
        pcall(function() profile:Save() end)
    end
end

function PlayerDataHandler:HasVisitedCheckpoint(player: Player, checkpointKey: string)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        ensurePerWorldContainers(profile.Data)
        local w = getCurrentWorldIndex(player)
        profile.Data.VisitedCheckpointsByWorld[w] = profile.Data.VisitedCheckpointsByWorld[w] or {}
        return profile.Data.VisitedCheckpointsByWorld[w][string.lower(checkpointKey)] == true
    end
    return false
end

function PlayerDataHandler:MarkCheckpointVisited(player: Player, checkpointKey: string)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        ensurePerWorldContainers(profile.Data)
        local w = getCurrentWorldIndex(player)
        local key = string.lower(checkpointKey)

        profile.Data.VisitedCheckpointsByWorld[w] = profile.Data.VisitedCheckpointsByWorld[w] or {}
        profile.Data.VisitedCheckpointsByWorld[w][key] = true

        -- mirror to legacy set for *current* world and tag it
        profile.Data.VisitedCheckpoints = {}
        for k, v in pairs(profile.Data.VisitedCheckpointsByWorld[w]) do
            if v then profile.Data.VisitedCheckpoints[k] = true end
        end
        profile.Data[FLAT_MIRROR_WORLD_KEY] = w

        print("[PlayerDataHandler] MarkCheckpointVisited (world", w, "):", player.Name, key)
        pcall(function() profile:Save() end)
    end
end

-- === full reset to template (experience-wide) =================================
-- (kept API; now also clears per-world stores)
function PlayerDataHandler:ResetProfileToTemplate(player: Player)
    local profile = Profiles[player]
    if not profile or not profile:IsActive() then
        return false, "Profile not active"
    end

    profile.Data.Coins = PlayerDataTemplate.Coins or 0
    profile.Data.Playtime = PlayerDataTemplate.Playtime or 0

    -- Clear *all* worlds
    profile.Data.LastCheckpointByWorld = {}
    profile.Data.VisitedCheckpointsByWorld = {}

    -- Mirror legacy (current world view cleared) and clear the tag
    profile.Data.LastCheckpoint = nil
    profile.Data.VisitedCheckpoints = {}
    profile.Data[FLAT_MIRROR_WORLD_KEY] = nil

    -- Also reset spin system to template defaults (non-breaking)
    profile.Data.SpinsAvailable = PlayerDataTemplate.SpinsAvailable
    profile.Data.SpinRefillUnix = PlayerDataTemplate.SpinRefillUnix
    profile.Data.LastResetBonusUnix = PlayerDataTemplate.LastResetBonusUnix
    profile.Data.__spinsInitialized = nil

    local ok, err = pcall(function() profile:Save() end)
    if not ok then
        return false, ("Save failed: %s"):format(tostring(err))
    end

    print("[PlayerDataHandler] Profile reset to template for", player.Name)
    return true
end

-- === SPINS HELPERS (used by SpinService) =====================================

function PlayerDataHandler:GetSpins(player: Player): number
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return 0 end
    local n = tonumber(prof.Data.SpinsAvailable) or 0
    print(("[PlayerDataHandler] GetSpins(%s) → %d"):format(player.Name, n))
    return n
end

function PlayerDataHandler:IncrementSpins(player: Player, count: number)
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return end
    count = tonumber(count) or 1
    prof.Data.SpinsAvailable = (tonumber(prof.Data.SpinsAvailable) or 0) + count
    print(("[PlayerDataHandler] IncrementSpins %s +%d → %d"):format(player.Name, count, prof.Data.SpinsAvailable))
    pcall(function() prof:Save() end)
end

function PlayerDataHandler:DeductSpins(player: Player, count: number)
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return end
    count = tonumber(count) or 1
    local cur = tonumber(prof.Data.SpinsAvailable) or 0
    local new = math.max(0, cur - count)
    prof.Data.SpinsAvailable = new
    print(("[PlayerDataHandler] DeductSpins %s -%d → %d"):format(player.Name, count, new))
    pcall(function() prof:Save() end)
end

function PlayerDataHandler:GetSpinRefillUnix(player: Player): number?
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return nil end
    local t = prof.Data.SpinRefillUnix
    print(("[PlayerDataHandler] GetSpinRefillUnix(%s) → %s"):format(player.Name, tostring(t)))
    return t
end

function PlayerDataHandler:SetSpinRefillUnix(player: Player, unix: number?)
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return end
    prof.Data.SpinRefillUnix = unix
    print(("[PlayerDataHandler] SetSpinRefillUnix %s → %s"):format(player.Name, tostring(unix)))
    pcall(function() prof:Save() end)
end

function PlayerDataHandler:SetResetBonusStamp(player: Player, unix: number)
    local prof = Profiles[player]
    if not (prof and prof:IsActive()) then return end
    prof.Data.LastResetBonusUnix = unix
    print(("[PlayerDataHandler] SetResetBonusStamp %s → %d"):format(player.Name, unix))
    pcall(function() prof:Save() end)
end

return PlayerDataHandler
