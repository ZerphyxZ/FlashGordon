local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local RobuxProducts = require(ReplicatedStorage.Configuration.RobuxProducts)

-- ── Durations (seconds) per product ─────────────────────────────────────────
-- These must match PRODUCT_DURATIONS in ProcessReceipt.luau.
local DURATIONS = {
	DoubleJump    = 60,
	FastRespawn   = 300,   -- 5 min
	GravityCoil   = 60,
	DoubleLuck    = 300,
	DoubleCoins   = 300,
	DisablePopups = 3600,  -- 1 hour
	WorldPass     = 3600,
	InfFlyBar     = 300,
}

local ProductsService = Knit.CreateService({
	Name = "ProductsService",
	Client = {
		-- Double Jump (149 R$)
		DoubleJumpActivated    = Knit.CreateSignal(),
		DoubleJumpExpired      = Knit.CreateSignal(),
		-- Fast Respawn (59 R$)
		FastRespawnActivated   = Knit.CreateSignal(),
		FastRespawnExpired     = Knit.CreateSignal(),
		-- Gravity Coil (119 R$)
		GravityActivated       = Knit.CreateSignal(),
		GravityExpired         = Knit.CreateSignal(),
		-- Double Luck (99 R$)
		DoubleLuckActivated    = Knit.CreateSignal(),
		DoubleLuckExpired      = Knit.CreateSignal(),
		-- Double Coins (110 R$)
		DoubleCoinsActivated   = Knit.CreateSignal(),
		DoubleCoinsExpired     = Knit.CreateSignal(),
		-- Disable Popups (49 R$)
		DisablePopupsActivated = Knit.CreateSignal(),
		DisablePopupsExpired   = Knit.CreateSignal(),
		-- World Pass (199 R$)
		WorldPassActivated     = Knit.CreateSignal(),
		WorldPassExpired       = Knit.CreateSignal(),
		-- Inf Fly Bar (349 R$)
		InfFlyBarActivated     = Knit.CreateSignal(),
		InfFlyBarExpired       = Knit.CreateSignal(),
		-- Legacy fly signal (kept for back-compat with existing code)
		FlyActivated           = Knit.CreateSignal(),
		FlyExpired             = Knit.CreateSignal(),
	},
})

-- ── Helper: grant a timed product, fire signals, schedule expiry ─────────────
local function grantTimedProduct(self, player, grantFn, clearFn, activatedSignal, expiredSignal)
	local endTime = grantFn(player)
	if not endTime then return end
	local remaining = math.max(0, endTime - os.time())
	if remaining <= 0 then return end
	activatedSignal:Fire(player, remaining)
	task.delay(remaining, function()
		expiredSignal:Fire(player)
		clearFn(player)
	end)
end

-- ── GetProductId ─────────────────────────────────────────────────────────────
-- Client calls this to get the Roblox product ID, then prompts purchase itself
-- via MarketplaceService:PromptProductPurchase(). ProcessReceipt handles grant.
function ProductsService.Client:GetProductId(player, productName)
	local id = RobuxProducts.Products and RobuxProducts.Products[productName]
	if not id or id == 0 then
		return false, ("No product ID configured for '%s'"):format(tostring(productName))
	end
	return true, id
end

-- ── Double Jump ───────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseDoubleJump(player)
	print("PurchaseDoubleJump:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantDoubleJump(p, DURATIONS.DoubleJump) end,
		function(p) PlayerDataHandler:ClearDoubleJump(p) end,
		self.DoubleJumpActivated,
		self.DoubleJumpExpired
	)
end

-- ── Fast Respawn ──────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseFastRespawn(player)
	print("PurchaseFastRespawn:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantFastRespawn(p, DURATIONS.FastRespawn) end,
		function(p) PlayerDataHandler:ClearFastRespawn(p) end,
		self.FastRespawnActivated,
		self.FastRespawnExpired
	)
end

-- ── Gravity Coil ──────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseGravity(player)
	print("PurchaseGravity:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantGravityCoil(p, DURATIONS.GravityCoil) end,
		function(p) PlayerDataHandler:ClearGravityCoil(p) end,
		self.GravityActivated,
		self.GravityExpired
	)
end

-- ── Double Luck ───────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseDoubleLuck(player)
	print("PurchaseDoubleLuck:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantDoubleLuck(p, DURATIONS.DoubleLuck) end,
		function(p) PlayerDataHandler:ClearDoubleLuck(p) end,
		self.DoubleLuckActivated,
		self.DoubleLuckExpired
	)
end

-- ── Double Coins ──────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseDoubleCoins(player)
	print("PurchaseDoubleCoins:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantDoubleCoins(p, DURATIONS.DoubleCoins) end,
		function(p) PlayerDataHandler:ClearDoubleCoins(p) end,
		self.DoubleCoinsActivated,
		self.DoubleCoinsExpired
	)
end

-- ── Disable Popups ────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseDisablePopups(player)
	print("PurchaseDisablePopups:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantDisablePopups(p, DURATIONS.DisablePopups) end,
		function(p) PlayerDataHandler:ClearDisablePopups(p) end,
		self.DisablePopupsActivated,
		self.DisablePopupsExpired
	)
end

-- ── World Pass ────────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseWorldPass(player)
	print("PurchaseWorldPass:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantWorldPass(p, DURATIONS.WorldPass) end,
		function(p) PlayerDataHandler:ClearWorldPass(p) end,
		self.WorldPassActivated,
		self.WorldPassExpired
	)
end

-- ── Inf Fly Bar ───────────────────────────────────────────────────────────────
function ProductsService.Client:PurchaseInfFlyBar(player)
	print("PurchaseInfFlyBar:", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantInfFlyBar(p, DURATIONS.InfFlyBar) end,
		function(p) PlayerDataHandler:ClearInfFlyBar(p) end,
		self.InfFlyBarActivated,
		self.InfFlyBarExpired
	)
end

-- ── Legacy Fly (kept for back-compat) ────────────────────────────────────────
function ProductsService.Client:PurchaseFly(player)
	print("PurchaseFly (legacy):", player.Name)
	grantTimedProduct(self, player,
		function(p) return PlayerDataHandler:GrantFly(p, 60) end,
		function(p) PlayerDataHandler:ClearFly(p) end,
		self.FlyActivated,
		self.FlyExpired
	)
end

function ProductsService:KnitStart()
	print("ProductsService started")
end

return ProductsService











-- local Global =
-- 	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
-- local Knit = Global.Knit
-- local ReplicatedStorage = Global.ReplicatedStorage
-- local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

-- local DOUBLE_JUMP_DURATION = 60-- seconds
-- local FLY_DURATION = 60 -- seconds
-- local GRAVITY_DURATION = 60 -- seconds

-- local ProductsService = Knit.CreateService({
-- 	Name = "ProductsService",
-- 	Client = {
--         DoubleJumpActivated = Knit.CreateSignal(),
--         DoubleJumpExpired = Knit.CreateSignal(),
--         FlyActivated = Knit.CreateSignal(),
-- 		FlyExpired = Knit.CreateSignal(),
-- 		GravityActivated = Knit.CreateSignal(),
-- 		GravityExpired = Knit.CreateSignal(),
--     },
-- })



-- function ProductsService.Client:PurchaseDoubleJump(player)
--     print("Player purchased Double Jump:", player.Name)
-- 	local endTime = PlayerDataHandler:GrantDoubleJump(player, DOUBLE_JUMP_DURATION)
-- 	if not endTime then return end

-- 	-- Sync client
-- 	local remaining = math.max(0, endTime - os.time())
-- 	if remaining < 0 then return end
-- 	self.DoubleJumpActivated:Fire(player, remaining)
-- 	task.delay(remaining, function()
-- 		self.DoubleJumpExpired:Fire(player)
-- 		PlayerDataHandler:ClearDoubleJump(player)
-- 	end)
-- end

-- function ProductsService.Client:PurchaseFly(player)
--     print("Player purchased Fly: " .. player.Name)
--     local endTime = PlayerDataHandler:GrantFly(player, FLY_DURATION)
-- 	if not endTime then return end

-- 	-- Sync client
-- 	local remaining = math.max(0, endTime - os.time())
-- 	if remaining < 0 then return end
-- 	self.FlyActivated:Fire(player, remaining)
-- 	task.delay(remaining, function()
-- 		self.FlyExpired:Fire(player)
-- 		PlayerDataHandler:ClearFly(player)
-- 	end)

-- end

-- function ProductsService.Client:PurchaseGravity(player)
-- 	print("Player purchased Gravity: " .. player.Name)
-- 	local endTime = PlayerDataHandler:GrantGravityCoil(player, GRAVITY_DURATION)
-- 	if not endTime then return end

-- 	-- Sync client
-- 	local remaining = math.max(0, endTime - os.time())
-- 	print("Total gravity time on server: ", remaining)
-- 	if remaining < 0 then return end
-- 	self.GravityActivated:Fire(player, remaining)
-- 	task.delay(remaining, function()
-- 		self.GravityExpired:Fire(player)
-- 		PlayerDataHandler:ClearGravityCoil(player)
-- 	end)
-- end


-- function ProductsService:KnitStart()
--     print("ProductsService started")
-- end

-- return ProductsService