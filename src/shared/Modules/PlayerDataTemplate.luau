-- ReplicatedStorage/Shared/Modules/PlayerDataTemplate.luau
-- Adds per-world stores + spin fields while keeping legacy fields for back-compat.

local PlayerDataTemplate = {
    Coins = 0,
    Playtime = 0,

    -- Legacy (kept for back-compat; mirrors the *current* world)
    LastCheckpoint = nil,            -- {x,y,z} or nil
    VisitedCheckpoints = {},         -- { [checkpointKeyLower]=true }

    -- NEW: per-world stores (keyed by numeric WorldIndex)
    --   LastCheckpointByWorld[worldIndex] = {x,y,z}
    --   VisitedCheckpointsByWorld[worldIndex] = { [checkpointKeyLower]=true }
    LastCheckpointByWorld = {},
    VisitedCheckpointsByWorld = {},

    -- === Spins system (used by SpinService) =================================
    -- SpinsAvailable     : how many spins the player currently has
    -- SpinRefillUnix     : next refill time (unix) when spins < MAX; nil/0 when at cap
    -- LastResetBonusUnix : guard timestamp when granting spins on global reset (optional)
    -- __spinsInitialized : internal flag so first-join grant happens once (managed at runtime)
    SpinsAvailable = 0,
    SpinRefillUnix = nil,
    LastResetBonusUnix = nil,
    __spinsInitialized = nil,
}

return PlayerDataTemplate
