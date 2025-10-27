--[[
    CurrencyService.luau

    A Knit service dedicated to managing coins/currency for players.
    This service abstracts coin operations away from gameplay logic,
    making it easy to award coins from different modules (e.g.
    checkpoint rewards, purchases, quests).  It relies on
    PlayerDataHandler to increment the coin value stored in the
    player's profile.

    Coins are replicated to the client via both Player Attributes and
    a `leaderstats` folder.  When a player joins, `PlayerDataServer`
    creates a `leaderstats` folder containing an `IntValue` named
    `Coins`.  This pattern is widely used in Roblox to display
    leaderboard values.  Updating both the attribute and the
    leaderstats value ensures compatibility with existing UI scripts
    that read `leaderstats`, while also allowing other client code to
    listen for `AttributeChanged` without relying on a hierarchy.

    Functions:
      * AwardCoins(player, amount) – Adds the specified amount of
        coins to the player's persistent data and updates the
        player's `Coins` attribute.

    Client API:
      * GetCoins() – Returns the player's current coin balance.
]]

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages:WaitForChild("Knit"))

local PlayerDataHandler = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local CurrencyService = Knit.CreateService {
    Name = "CurrencyService";
    -- The Client table is intentionally left empty; Knit will expose
    -- server functions (such as GetCoins) for client calls automatically.
    Client = {};
}

-- Emit a debug message when the service module is required.
print("[CurrencyService] Service module loaded")

-- Award a number of coins to a player.  Does nothing if the player
-- does not have an active profile.
function CurrencyService:AwardCoins(player, amount)
    -- Debug: awarding coins
    print("[CurrencyService] AwardCoins: awarding", amount, "to", player.Name)
    if typeof(amount) ~= "number" or amount == 0 then return end
    PlayerDataHandler:IncrementCoins(player, amount)
    -- After updating the profile, update the player's Coins attribute
    local data = PlayerDataHandler:GetData(player)
    if data then
        print("[CurrencyService]", player.Name, "now has", data.Coins, "coins")
        -- Update both the player's attribute and leaderstats.  Creating
        -- or updating the Coins attribute makes the value available via
        -- GetAttributeChangedSignal on the client.  Setting the
        -- leaderstats value allows legacy UI scripts to read the coin
        -- count directly from the leaderboard.
        pcall(function()
            player:SetAttribute("Coins", data.Coins or 0)
        end)
        -- Ensure leaderstats folder and Coins value exist
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coinsVal = leaderstats:FindFirstChild("Coins")
            if coinsVal then
                coinsVal.Value = data.Coins or 0
            end
        end
    end
end

-- Client‑side method to get the player's current coin count.  Returns
-- an integer or 0 if no profile is loaded.
function CurrencyService.Client:GetCoins(player)
    -- Debug: client requested coin count
    print("[CurrencyService] Client.GetCoins called by", player.Name)
    -- Prefer the replicated attribute if present because it reflects
    -- the current value and avoids exposing internal data tables.
    local attr = player:GetAttribute("Coins")
    if attr ~= nil then
        return attr
    end
    -- Fallback: read from the profile if the attribute is not set yet
    local data = PlayerDataHandler:GetData(player)
    return (data and data.Coins) or 0
end

return CurrencyService