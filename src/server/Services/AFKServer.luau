-- AFKServer.luau (Knit Service)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local AFK_INTERVAL = 20      -- seconds
local AFK_REWARD = 20        -- coins per interval

local AFKService = Knit.CreateService {
    Name = "AFKService",
    Client = {},
}

AFKService._afkStates = {}   -- [Player] = true/nil


-- Use central data handler (profilestore + attributes), and keep leaderstats in sync
function AFKService:_GiveAFKCoins(player: Player)
    if not player or not player.Parent then
        return
    end

    -- 1) Update profile + player attribute via your existing system
    PlayerDataHandler:IncrementCoins(player, AFK_REWARD)

    -- 2) Mirror to leaderstats.Coins so CoinsController sees a Value change
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coinsVal = leaderstats:FindFirstChild("Coins")
        if coinsVal then
            local newTotal = player:GetAttribute("Coins")
            if typeof(newTotal) == "number" then
                coinsVal.Value = newTotal  -- triggers HUD update via CoinsController
            else
                -- Fallback: still increment visually if attribute is missing for some reason
                coinsVal.Value += AFK_REWARD
            end
        end
    end
end


function AFKService:_StartAFKLoop(player: Player)
    task.spawn(function()
        while self._afkStates[player] and player.Parent do
            task.wait(AFK_INTERVAL)

            if not self._afkStates[player] or not player.Parent then
                break
            end

            self:_GiveAFKCoins(player)
        end
    end)
end


function AFKService:SetAFK(player: Player, isAFK: boolean)
    if typeof(isAFK) ~= "boolean" then
        return
    end

    if isAFK then
        -- already AFK?
        if self._afkStates[player] then
            return
        end

        self._afkStates[player] = true
        self:_StartAFKLoop(player)
    else
        self._afkStates[player] = nil
    end
end


-- Client → Server (Knit remoting, no RemoteEvent objects)
function AFKService.Client:SetAFK(player: Player, isAFK: boolean)
    self.Server:SetAFK(player, isAFK)
end


function AFKService:KnitStart()
    Players.PlayerRemoving:Connect(function(player)
        self._afkStates[player] = nil
    end)
end


return AFKService
