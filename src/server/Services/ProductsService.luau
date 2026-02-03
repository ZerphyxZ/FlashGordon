local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local DOUBLE_JUMP_DURATION = 60-- seconds
local FLY_DURATION = 60 -- seconds
local GRAVITY_DURATION = 60 -- seconds

local ProductsService = Knit.CreateService({
	Name = "ProductsService",
	Client = {
        DoubleJumpActivated = Knit.CreateSignal(),
        DoubleJumpExpired = Knit.CreateSignal(),
        FlyActivated = Knit.CreateSignal(),
		FlyExpired = Knit.CreateSignal(),
		GravityActivated = Knit.CreateSignal(),
		GravityExpired = Knit.CreateSignal(),
    },
})



function ProductsService.Client:PurchaseDoubleJump(player)
    print("Player purchased Double Jump:", player.Name)
	local endTime = PlayerDataHandler:GrantDoubleJump(player, DOUBLE_JUMP_DURATION)
	if not endTime then return end

	-- Sync client
	local remaining = math.max(0, endTime - os.time())
	if remaining < 0 then return end
	self.DoubleJumpActivated:Fire(player, remaining)
	task.delay(remaining, function()
		self.DoubleJumpExpired:Fire(player)
		PlayerDataHandler:ClearDoubleJump(player)
	end)
end

function ProductsService.Client:PurchaseFly(player)
    print("Player purchased Fly: " .. player.Name)
    local endTime = PlayerDataHandler:GrantFly(player, FLY_DURATION)
	if not endTime then return end

	-- Sync client
	local remaining = math.max(0, endTime - os.time())
	if remaining < 0 then return end
	self.FlyActivated:Fire(player, remaining)
	task.delay(remaining, function()
		self.FlyExpired:Fire(player)
		PlayerDataHandler:ClearFly(player)
	end)

end

function ProductsService.Client:PurchaseGravity(player)
	print("Player purchased Gravity: " .. player.Name)
	local endTime = PlayerDataHandler:GrantGravityCoil(player, GRAVITY_DURATION)
	if not endTime then return end

	-- Sync client
	local remaining = math.max(0, endTime - os.time())
	print("Total gravity time on server: ", remaining)
	if remaining < 0 then return end
	self.GravityActivated:Fire(player, remaining)
	task.delay(remaining, function()
		self.GravityExpired:Fire(player)
		PlayerDataHandler:ClearGravityCoil(player)
	end)
end


function ProductsService:KnitStart()
    print("ProductsService started")
end

return ProductsService