local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local Hoverboards = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("HoverboardData"))
local HoverboardService

local GearService = Knit.CreateService({
	Name = "GearService",
	Client = {
		BoardPurchased = Knit.CreateSignal(),
		CratePurchased = Knit.CreateSignal(),
		BoardEquipped = Knit.CreateSignal(),
		TrailEquipped = Knit.CreateSignal(),
		TrailUnequipped = Knit.CreateSignal(),
		CrateEquipped = Knit.CreateSignal()
	},
})

local RED_COLOR = Color3.fromRGB(255, 0, 0)
local GREEN_COLOR = Color3.fromRGB(0, 255, 0)

---------- Client Methods -----------
--BOARDS-----------------------------
function GearService.Client:PurchaseHoverboard(player, boardName, price, currencyType)
	print("PurchaseHoverboard called:", player.Name, boardName, price, currencyType)
	local playerData = PlayerDataHandler:GetData(player)

	if not playerData then
		return false, "Player data not found!"
	end

	-- Check if already owned
	if PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
		return false, "Already owned!"
	end

	-- Check if valid hoverboard
	local config = Hoverboards.GetConfig(boardName)
	if not config then
		return false, "Invalid hoverboard!"
	end

	-- Process payment
	if currencyType == "Coins" then
		if playerData.Coins < price then
			return false, "Insufficient coins!"
		end
		PlayerDataHandler:DeductCoins(player, price)
	elseif currencyType == "Robux" then
		-- Implement Robux purchase logic here
		-- This would typically use MarketplaceService
		return false, "Robux purchases not implemented yet!"
	else
		return false, "Invalid currency type!"
	end

	-- Add to inventory
	local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
	if success then
		print("[GearService] Purchased hoverboard:", player.Name, boardName, price, currencyType)
		return true, "Purchase successful!"
	else
		-- Refund if failed to add to inventory
		if currencyType == "Coins" then
			PlayerDataHandler:IncrementCoins(player, price)
		end
		return false, "Purchase failed!"
	end
end

function GearService.Client:PlayerOwnsHoverboard(player, boardName)
	if PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
		return true
	end
	return false
end

--TRAILS-----------------------------
function GearService.Client:PurchaseTrail(player, trailName, price, currencyType)
	local data = PlayerDataHandler:GetData(player)
	if not data then
		return false, "Player Data Not Found!"
	end

	if PlayerDataHandler:PlayerOwnsTrail(player, trailName) then
		return false, "Player already owns this trail!"
	end

	if currencyType == "Coins" then
		if data.Coins < price then
			return false, "Insufficient coins to purchase trail"
		end
		PlayerDataHandler:DeductCoins(player, price)
		print("Deducted", price, "coins from", player.Name)
	end

	local success = PlayerDataHandler:AddTrailToInventory(player, trailName)
	if success then
		print("[GearService] Purchased hoverboard:", player.Name, boardName, price, currencyType)
		return true, "Purchase Successful!"
	else
		if currencyType == "Coins" then
			PlayerDataHandler:IncrementCoins(player, price)
		end
		return false, "Purchase Failed!"
	end
end

function GearService.Client:EquipTrail(player, trailName)
	PlayerDataHandler:SetEquippedTrail(player, trailName)
	self.TrailEquipped:Fire(player, trailName)
	return true, "Trail Successfully Equipped!" 
end

function GearService.Client:UnequipTrail(player)
	PlayerDataHandler:SetEquippedTrail(player, nil)
	self.TrailUnequipped:Fire(player)
	return true, "Trail Successfully Unequipped!"
end

function GearService.Client:GetEquippedTrail(player)
	return PlayerDataHandler:GetEquippedTrail(player)
end

--CRATES-----------------------------
function GearService.Client:PurchaseCrate()

end



function GearService:KnitStart()
	print("Gear service started.")
	HoverboardService = Knit.GetService("HoverboardService")
end

return GearService