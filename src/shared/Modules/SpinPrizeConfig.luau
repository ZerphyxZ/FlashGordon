-- ReplicatedStorage/Shared/Modules/SpinPrizeConfig.luau
-- Prize wedges + probabilities + UI wedge angle ranges (degrees).
-- The client tween will rotate WheelInnter_SpinWheel to wholeSpins*360 + delta,
-- where delta is a random angle inside NumberRange.

export type PrizeInfo = {
    prize: "Coins" | "UGC",
    amount: number?,
    reward: ((Player) -> ())?,
    location: NumberRange,
    probability: number, -- 0..1
}

-- Optional: implement GrantAccessory if you later enable UGC prizes.
-- local GrantAccessory
-- local Utility = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
-- GrantAccessory = Utility and require(Utility:WaitForChild("GrantAccessory"))

local Prizes: {[string]: PrizeInfo} = {
    RedPrize = {
        prize = "UGC",
        reward = function(player)
            -- If GrantAccessory is defined, call it; otherwise no-op.
            -- if GrantAccessory then
            --     GrantAccessory:AddItem(player, "Hoodie")
            -- end
        end,
        location = NumberRange.new(-51, 0),
        probability = 0, -- set >0 when using UGC
    },

    OrangePrize = { prize = "Coins", amount = 5000, location = NumberRange.new(-102, -52), probability = 0.10 },
    YellowPrize = { prize = "Coins", amount = 2000, location = NumberRange.new(-153, -102), probability = 0.10 },
    GreenPrize  = { prize = "Coins", amount = 200,  location = NumberRange.new(-204, -154), probability = 0.20 },
    BluePrize   = { prize = "Coins", amount = 50,   location = NumberRange.new(-257, -205), probability = 0.40 },
    DarkPurplePrize  = { prize = "Coins", amount = 1000,  location = NumberRange.new(-307, -257), probability = 0.10 },
    LightPurplePrize = { prize = "Coins", amount = 10000, location = NumberRange.new(-360, -308), probability = 0.10 },
}

return Prizes