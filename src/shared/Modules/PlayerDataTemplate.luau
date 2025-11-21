local PlayerDataTemplate = {
	Coins = 0,
	Playtime = 0,

	-- Legacy (kept for back-compat; mirrors the *current* world)
	LastCheckpoint = nil, -- {x,y,z} or nil
	VisitedCheckpoints = {}, -- { [checkpointKeyLower]=true }

	-- NEW: per-world stores (keyed by numeric WorldIndex)
	--   LastCheckpointByWorld[worldIndex] = {x,y,z}
	--   VisitedCheckpointsByWorld[worldIndex] = { [checkpointKeyLower]=true }
	LastCheckpointByWorld = {},
	VisitedCheckpointsByWorld = {},

	-- Daily Rewards
	DailyStreak = 0,
	LastDailyReward = 0,

	--Spins system
	AvailableSpin = 0,
	LastSpinReward = 0,

	-- Claimed Redeem Codes
	Codes = {},
}

return PlayerDataTemplate
