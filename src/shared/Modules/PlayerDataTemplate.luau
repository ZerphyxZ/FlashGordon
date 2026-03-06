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

	--Products Inventory (timed, stored as os.time() end-timestamps or nil)
	DoubleJumpEndTime  = nil, -- Double Jump    (149 R$)
	GravityEndTime     = nil, -- Gravity Coil   (119 R$)
	FlyEndTime         = nil, -- legacy fly (kept for back-compat)
	FastRespawnEndTime = nil, -- Fast Respawn   (59  R$)
	DoubleLuckEndTime  = nil, -- Double Luck    (99  R$)
	DoubleCoinsEndTime = nil, -- Double Coins   (110 R$)
	DisablePopupsEndTime = nil, -- Disable Popups (49  R$)
	WorldPassEndTime   = nil, -- World Pass     (199 R$)
	InfFlyBarEndTime   = nil, -- Inf Fly Bar    (349 R$)
}

return PlayerDataTemplate
