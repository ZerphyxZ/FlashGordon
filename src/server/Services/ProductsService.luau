local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local DOUBLE_JUMP_DURATION = 60 -- seconds
local FLY_DURATION = 60 -- seconds
local GRAVITY_DURATION = 60 -- seconds

local ProductsService = Knit.CreateService({
	Name = "ProductsService",
	Client = {
        DoubleJumpActivated = Knit.CreateSignal(),
        DoubleJumpExpired = Knit.CreateSignal(),
        FlyEnabled = Knit.CreateSignal(),
		GravityActivated = Knit.CreateSignal(),
		GravityExpired = Knit.CreateSignal(),
    },
})



function ProductsService.Client:PurchaseDoubleJump(player)
    print("Player purchased Double Jump:", player.Name)
	local endTime = PlayerDataHandler:GrantDoubleJump(player, DOUBLE_JUMP_DURATION)
	if not endTime then return end

	-- Sync client
	self.DoubleJumpActivated:Fire(player, endTime)
	local remaining = endTime - os.time()
	if remaining < 0 then return end

	-- Schedule expiry (server authority)
	task.delay(remaining, function()
		if PlayerDataHandler:HasDoubleJump(player) then
			PlayerDataHandler:ClearDoubleJump(player)
			self.DoubleJumpExpired:Fire(player)
		end
	end)
end

function ProductsService.Client:PurchaseFly(player)
    print("Player purchased Fly: " .. player.Name)
    self.FlyEnabled:Fire(player)
end

function ProductsService.Client:PurchaseGravity(player)
	print("Player purchased Gravity: " .. player.Name)
	local endTime = PlayerDataHandler:GrantGravityCoil(player, GRAVITY_DURATION)
	if not endTime then return end

	-- Sync client
	self.GravityActivated:Fire(player, endTime)
	local remaining = endTime - os.time()
	if remaining < 0 then return end

	-- Schedule expiry (server authority)
	task.delay(remaining, function()
		PlayerDataHandler:ClearGravityCoil(player)
		self.GravityExpired:Fire(player)
	end)
end


function ProductsService:KnitStart()
    print("ProductsService started")
end

return ProductsService