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

	--Hoverboards Inventory
	TotalHoverboards = 20, -- Total available hoverboards in game
	OwnedHoverboards = {"Hoverboard1"}, -- Start with default hoverboard
	EquippedHoverboard = "Hoverboard1", -- Currently equipped hoverboard

	--Trails Inventory
	TotalTrails = 4, -- Total available trails in game
	OwnedTrails = {"RedTrail"}, -- Start with default trail
	EquippedTrail = "RedTrail", -- Currently equipped trail

	--Crates Inventory
	TotalCrates = 5, -- Total available crates in game
	OwnedCrates = {"BasicBoard"}, -- Start with default crate
	EquippedCrate = "BasicBoard", -- Currently equipped crate

	--Products Inventory
	DoubleJumpEndTime = nil, -- timestamp or nil
	GravityEndTime = nil, -- timestamp or nil
	FlyEndTime = nil, -- timestamp or nil
}

return PlayerDataTemplate
