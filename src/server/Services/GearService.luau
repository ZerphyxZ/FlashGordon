local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local Hoverboards = require(ReplicatedStorage.Configuration.HoverboardData)
local RobuxProducts = require(ReplicatedStorage.Configuration.RobuxProducts)
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
    }
})

local RED_COLOR = Color3.fromRGB(255, 0, 0)
local GREEN_COLOR = Color3.fromRGB(0, 255, 0)

---------- Client Methods -----------
-- BOARDS-----------------------------
function GearService.Client:PurchaseRobuxHoverboard(player, boardName)
    local productId = RobuxProducts.Hoverboards[boardName]
    if not productId then
        return false, "Invalid Robux product!"
    end
    return true, productId -- client will prompt purchase
end

function GearService.Client:PurchaseCoinsHoverboard(player, boardName, price)
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

    if playerData.Coins < price then
        return false, "Insufficient coins!"
    end
    PlayerDataHandler:DeductCoins(player, price)

    -- Add to inventory
    local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
    if success then
        return true, "Purchase successful!"
    else
        -- Refund if failed to add to inventory
		PlayerDataHandler:IncrementCoins(player, price)
        return false, "Purchase failed!"
    end
end

function GearService.Client:PlayerOwnsHoverboard(player, boardName)
    if PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
        return true
    end
    return false
end

-- TRAILS-----------------------------
function GearService.Client:PlayerOwnsTrail(player, trailName)
    return PlayerDataHandler:PlayerOwnsTrail(player, trailName)
end

function GearService.Client:PurchaseRobuxTrail(player, trailName)
    local productId = RobuxProducts.Trails[trailName]
    if not productId then
        return false, "Invalid Robux product!"
    end
    return true, productId -- client will prompt purchase
end

function GearService.Client:PurchaseCoinsTrail(player, trailName, price)
    local data = PlayerDataHandler:GetData(player)
    if not data then
        return false, "Player Data Not Found!"
    end

    if PlayerDataHandler:PlayerOwnsTrail(player, trailName) then
        return false, "Player already owns this trail!"
    end

    if data.Coins < price then
        return false, "Insufficient coins to purchase trail"
    end
    PlayerDataHandler:DeductCoins(player, price)
    print("Deducted", price, "coins from", player.Name)

    local success = PlayerDataHandler:AddTrailToInventory(player, trailName)
    if success then
        return true, "Purchase Successful!"
    else
        PlayerDataHandler:IncrementCoins(player, price)
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

-- CRATES-----------------------------
function GearService.Client:PlayerOwnsCrate(player, crateName)
    return PlayerDataHandler:PlayerOwnsCrate(player, crateName)
end

function GearService.Client:PurchaseRobuxCrate(player, crateName)
    local productId = RobuxProducts.Crates[crateName]
    if not productId then
        return false, "Invalid Robux product!"
    end
    return true, productId -- client will prompt purchase
end

function GearService.Client:PurchaseCoinsCrate(player, crateName, price)
    local data = PlayerDataHandler:GetData(player)
    if not data then
        print("GearService: PurchaseCrate failed")
        return false, "Player Data Not Found!"
    end

    if data.Coins < price then
        print("Insufficient coins to purchase crate")
        return false, "Insufficient coins to purchase crate"
    end
    PlayerDataHandler:DeductCoins(player, price)
    print("Deducted", price, "coins from", player.Name)

    local success = PlayerDataHandler:AddCrateToInventory(player, crateName)
    if success then
        return true, "Purchase Successful!"
    else
        PlayerDataHandler:IncrementCoins(player, price)
        return false, "Failed to add crate to inventory!"
    end
end

function GearService.Client:EquipCrate(player, crateName)
    PlayerDataHandler:SetEquippedCrate(player, crateName)
    return true
end

function GearService.Client:UnequipCrate(player)
    PlayerDataHandler:SetEquippedCrate(player, nil)
    return true
end

function GearService.Client:GetEquippedCrate(player)
    return PlayerDataHandler:GetEquippedCrate(player)
end

function GearService.Client:GetOwnedCrates(player)
    return PlayerDataHandler:GetOwnedCrates(player)
end

function GearService:KnitStart()
    print("Gear service started.")
    HoverboardService = Knit.GetService("HoverboardService")
end

return GearService
