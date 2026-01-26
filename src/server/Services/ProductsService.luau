local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local DOUBLE_JUMP_DURATION = 100 -- seconds

local ProductsService = Knit.CreateService({
	Name = "ProductsService",
	Client = {
        DoubleJumpActivated = Knit.CreateSignal(),
        DoubleJumpExpired = Knit.CreateSignal(),
        FlyEnabled = Knit.CreateSignal(),
    },
})



function ProductsService.Client:PurchaseDoubleJump(player)
    print("Player purchased Double Jump:", player.Name)
	local endTime = PlayerDataHandler:GrantDoubleJump(player, DOUBLE_JUMP_DURATION)

	-- Sync client
	self.DoubleJumpActivated:Fire(player, endTime)

	-- Schedule expiry (server authority)
	task.delay(endTime - os.time(), function()
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

function ProductsService:KnitStart()
    print("ProductsService started")
end

return ProductsService