-- [Services]
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")
local CodesData: {} = require(Configuration:WaitForChild("CodesData"))

local DataHandler: {} = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local CodesService = Knit.CreateService({
	Name = "CodesService",
	Client = {},
})

-- [Functions]
local function GetClaimedCodesForPlayer(Player: Player)
	local playerData = DataHandler:GetData(Player)

	if playerData and typeof(playerData.Codes) == "table" then
		print("playerData Codes", playerData.Codes)
		return playerData.Codes
	end

	return {}
end

local function RedeemCodeForClient(Player: Player, CODE: string)
	if typeof(CODE) ~= "string" or CODE == "" then
		return false, "Invalid Code"
	end

	local codeInfo = CodesData[CODE]
	if not codeInfo then
		return false, "Code not found"
	end

	if codeInfo.expires and (os.time() > codeInfo.expires) then
		return false, "Code has expired"
	end

	local claimedCodes: {} = GetClaimedCodesForPlayer(Player)

	-- Get already claimed
	if table.find(claimedCodes, CODE) then
		return false, "Already Redeemed"
	end

	-- Apply rewards
	for rewardType, value in pairs(codeInfo.rewards) do
		if rewardType == "coins" then
			print("RedeemCoins", value)
			DataHandler:IncrementCoins(Player, value)
			-- elseif -- can check for multiple rewards
		end
	end

	-- Save that player has redeemed this code
	table.insert(claimedCodes, CODE)
	DataHandler:UpdateCodes(Player, claimedCodes)

	return true, "Reward Claimed"
end

function CodesService.Client:RedeemCode(Player, CODE)
	return RedeemCodeForClient(Player, CODE)
end

return CodesService
