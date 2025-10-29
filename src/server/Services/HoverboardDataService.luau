local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))

local HoverboardDataService = Knit.CreateService {Name = "HoverboardDataService"}

local DataStoreService = game:GetService("DataStoreService")
local HoverboardStore = DataStoreService:GetDataStore("PlayerHoverboardData")

function HoverboardDataService:GetEquippedHoverboard(player, playerHoverboards, Hoverboards)
    -- Load hoverboard from datastore
	local success, data = pcall(function()
		return HoverboardStore:GetAsync(player.UserId)
	end)
	if success and data then
        local config = Hoverboards.GetConfig(data)
        if config then
            playerHoverboards[player.UserId] = {
                Name = data,
                Config = config
            }
            return
        end
	end
end

function HoverboardDataService:SetEquippedHoverboard(player, playerHoverboards, Hoverboards)
    local boardData = playerHoverboards[player.UserId]
	if boardData and boardData.Name then
		pcall(function()
			HoverboardStore:SetAsync(player.UserId, boardData.Name)
		end)
	end
	playerHoverboards[player.UserId] = nil
end

return HoverboardDataService