local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local RobuxProducts = require(ReplicatedStorage.Configuration.RobuxProducts)
local Global = require(ReplicatedStorage.Shared.Modules.Global)
local Knit = Global.Knit

local RobuxReceiptService = Knit.CreateService({
    Name = "RobuxReceiptService",
    Client = {
        CratePurchased = Knit.CreateSignal(),
        BoardPurchased = Knit.CreateSignal(),
        TrailPurchased = Knit.CreateSignal()
    }
})

MarketplaceService.ProcessReceipt = function(receipt)
    local player = game.Players:GetPlayerByUserId(receipt.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productId = receipt.ProductId

    -- Crates
    for crateName, id in pairs(RobuxProducts.Crates) do
        if id == productId then
            local success = PlayerDataHandler:AddCrateToInventory(player, crateName)
            if success then
                RobuxReceiptService.Client.CratePurchased:Fire(player)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
    end

    -- Hoverboards
    for boardName, id in pairs(RobuxProducts.Hoverboards) do
        if id == productId then
            local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
            if success then
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
    end

    -- Trails
    for trailName, id in pairs(RobuxProducts.Trails) do
        if id == productId then
            local success = PlayerDataHandler:AddTrailToInventory(player, trailName)
            if success then
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

return RobuxReceiptService
