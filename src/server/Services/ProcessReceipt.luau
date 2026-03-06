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
        CratePurchased  = Knit.CreateSignal(),
        BoardPurchased  = Knit.CreateSignal(),
        TrailPurchased  = Knit.CreateSignal(),
    }
})

-- Durations (seconds) for each timed product — must match ProductsService constants.
local PRODUCT_DURATIONS = {
    DoubleJump    = 60,
    FastRespawn   = 300,
    GravityCoil   = 60,
    DoubleLuck    = 300,
    DoubleCoins   = 300,
    DisablePopups = 3600,
    WorldPass     = 3600,
    InfFlyBar     = 300,
}

-- Maps each product name → { grantFn, clearFn, activatedSignalName, expiredSignalName }
-- Signals are fired via ProductsService.Client after grant so the client reacts.
local function getProductsService()
    return Knit.GetService("ProductsService")
end

local PRODUCT_HANDLERS = {
    DoubleJump = {
        grant = function(player) return PlayerDataHandler:GrantDoubleJump(player, PRODUCT_DURATIONS.DoubleJump) end,
        clear = function(player) PlayerDataHandler:ClearDoubleJump(player) end,
        activated = "DoubleJumpActivated",
        expired   = "DoubleJumpExpired",
    },
    FastRespawn = {
        grant = function(player) return PlayerDataHandler:GrantFastRespawn(player, PRODUCT_DURATIONS.FastRespawn) end,
        clear = function(player) PlayerDataHandler:ClearFastRespawn(player) end,
        activated = "FastRespawnActivated",
        expired   = "FastRespawnExpired",
    },
    GravityCoil = {
        grant = function(player) return PlayerDataHandler:GrantGravityCoil(player, PRODUCT_DURATIONS.GravityCoil) end,
        clear = function(player) PlayerDataHandler:ClearGravityCoil(player) end,
        activated = "GravityActivated",
        expired   = "GravityExpired",
    },
    DoubleLuck = {
        grant = function(player) return PlayerDataHandler:GrantDoubleLuck(player, PRODUCT_DURATIONS.DoubleLuck) end,
        clear = function(player) PlayerDataHandler:ClearDoubleLuck(player) end,
        activated = "DoubleLuckActivated",
        expired   = "DoubleLuckExpired",
    },
    DoubleCoins = {
        grant = function(player) return PlayerDataHandler:GrantDoubleCoins(player, PRODUCT_DURATIONS.DoubleCoins) end,
        clear = function(player) PlayerDataHandler:ClearDoubleCoins(player) end,
        activated = "DoubleCoinsActivated",
        expired   = "DoubleCoinsExpired",
    },
    DisablePopups = {
        grant = function(player) return PlayerDataHandler:GrantDisablePopups(player, PRODUCT_DURATIONS.DisablePopups) end,
        clear = function(player) PlayerDataHandler:ClearDisablePopups(player) end,
        activated = "DisablePopupsActivated",
        expired   = "DisablePopupsExpired",
    },
    WorldPass = {
        grant = function(player) return PlayerDataHandler:GrantWorldPass(player, PRODUCT_DURATIONS.WorldPass) end,
        clear = function(player) PlayerDataHandler:ClearWorldPass(player) end,
        activated = "WorldPassActivated",
        expired   = "WorldPassExpired",
    },
    InfFlyBar = {
        grant = function(player) return PlayerDataHandler:GrantInfFlyBar(player, PRODUCT_DURATIONS.InfFlyBar) end,
        clear = function(player) PlayerDataHandler:ClearInfFlyBar(player) end,
        activated = "InfFlyBarActivated",
        expired   = "InfFlyBarExpired",
    },
}

MarketplaceService.ProcessReceipt = function(receipt)
    local player = game.Players:GetPlayerByUserId(receipt.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productId = receipt.ProductId

    -- ── Crates ───────────────────────────────────────────────────────────
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

    -- ── Hoverboards ───────────────────────────────────────────────────────
    for boardName, id in pairs(RobuxProducts.Hoverboards) do
        if id == productId then
            local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
            if success then
                RobuxReceiptService.Client.BoardPurchased:Fire(player)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
    end

    -- ── Trails ───────────────────────────────────────────────────────────
    for trailName, id in pairs(RobuxProducts.Trails) do
        if id == productId then
            local success = PlayerDataHandler:AddTrailToInventory(player, trailName)
            if success then
                RobuxReceiptService.Client.TrailPurchased:Fire(player)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        end
    end

    -- ── Timed Products ───────────────────────────────────────────────────
    for productName, id in pairs(RobuxProducts.Products) do
        if id == productId then
            local handler = PRODUCT_HANDLERS[productName]
            if not handler then
                warn("[ProcessReceipt] No handler for product:", productName)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            local endTime = handler.grant(player)
            if not endTime then
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            -- Fire activated signal to client with remaining seconds
            local remaining = math.max(0, endTime - os.time())
            local ps = getProductsService()
            if ps and ps.Client[handler.activated] then
                ps.Client[handler.activated]:Fire(player, remaining)
            end

            -- Schedule expiry
            task.delay(remaining, function()
                if ps and ps.Client[handler.expired] then
                    ps.Client[handler.expired]:Fire(player)
                end
                handler.clear(player)
            end)

            print(("[ProcessReceipt] Granted %s to %s for %ds"):format(productName, player.Name, remaining))
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end

    warn("[ProcessReceipt] Unknown productId:", productId)
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

function RobuxReceiptService:KnitStart()
    print("RobuxReceiptService started")
end

return RobuxReceiptService











-- local MarketplaceService = game:GetService("MarketplaceService")
-- local ServerStorage = game:GetService("ServerStorage")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
-- local RobuxProducts = require(ReplicatedStorage.Configuration.RobuxProducts)
-- local Global = require(ReplicatedStorage.Shared.Modules.Global)
-- local Knit = Global.Knit

-- local RobuxReceiptService = Knit.CreateService({
--     Name = "RobuxReceiptService",
--     Client = {
--         CratePurchased = Knit.CreateSignal(),
--         BoardPurchased = Knit.CreateSignal(),
--         TrailPurchased = Knit.CreateSignal()
--     }
-- })

-- MarketplaceService.ProcessReceipt = function(receipt)
--     local player = game.Players:GetPlayerByUserId(receipt.PlayerId)
--     if not player then
--         return Enum.ProductPurchaseDecision.NotProcessedYet
--     end

--     local productId = receipt.ProductId

--     -- Crates
--     for crateName, id in pairs(RobuxProducts.Crates) do
--         if id == productId then
--             local success = PlayerDataHandler:AddCrateToInventory(player, crateName)
--             if success then
--                 RobuxReceiptService.Client.CratePurchased:Fire(player)
--                 return Enum.ProductPurchaseDecision.PurchaseGranted
--             else
--                 return Enum.ProductPurchaseDecision.NotProcessedYet
--             end
--         end
--     end

--     -- Hoverboards
--     for boardName, id in pairs(RobuxProducts.Hoverboards) do
--         if id == productId then
--             local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
--             if success then
--                 return Enum.ProductPurchaseDecision.PurchaseGranted
--             else
--                 return Enum.ProductPurchaseDecision.NotProcessedYet
--             end
--         end
--     end

--     -- Trails
--     for trailName, id in pairs(RobuxProducts.Trails) do
--         if id == productId then
--             local success = PlayerDataHandler:AddTrailToInventory(player, trailName)
--             if success then
--                 return Enum.ProductPurchaseDecision.PurchaseGranted
--             else
--                 return Enum.ProductPurchaseDecision.NotProcessedYet
--             end
--         end
--     end

--     return Enum.ProductPurchaseDecision.NotProcessedYet
-- end

-- return RobuxReceiptService