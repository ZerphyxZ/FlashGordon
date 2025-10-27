--[[
    PlayerDataTemplate.luau

    Defines the default data structure for a player's profile.  This table
    should be passed to ProfileService when creating a ProfileStore.  When
    loading profiles, missing keys will be reconciled automatically
    using this template【31138390420226†L39-L46】.  Clients and other
    server modules can require this module to access the schema.

    Fields:
      * Coins         – Number of coins the player has earned.
      * Playtime      – Total accumulated playtime in seconds.
      * LastCheckpoint – Table containing the last checkpoint position as
                         {x, y, z}; nil if the player has not reached a
                         checkpoint yet.
]]

local PlayerDataTemplate = {
    Coins = 0,
    Playtime = 0,
    LastCheckpoint = nil,
    -- Tracks checkpoints that the player has visited.  Keys are
    -- checkpoint names and values are true.  This prevents players
    -- from repeatedly triggering the same checkpoint across sessions.
    VisitedCheckpoints = {},
}

return PlayerDataTemplate