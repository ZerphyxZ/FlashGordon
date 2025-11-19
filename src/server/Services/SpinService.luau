-- [Services]				----
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]				-----
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local PrizeModule = require(ReplicatedStorage.Configuration.SpinPrizeConfig)
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local spinTimeSeconds = 10 -- 86400

local SpinService = Knit.CreateService({
	Name = "SpinService",
	Client = {},
})

local function UpdatePlayerSpinState(Player: Player)
	local playerData = PlayerDataHandler:GetData(Player)
	local availableSpin = 0

	if playerData then
		availableSpin = playerData.AvailableSpin

		if availableSpin == 0 then
			local requestTime = os.time()
			local timeLeft = spinTimeSeconds - (requestTime - playerData.LastSpinReward)

			if timeLeft <= 0 then
				PlayerDataHandler:IncrementSpins(Player, 1)
			end
		end
	end
end

local function GetUpdatedSpinsForPlayer(Player: Player)
	UpdatePlayerSpinState(Player)

	local playerData = PlayerDataHandler:GetData(Player)
	local availableSpin, timeLeft = 0, 0

	if playerData then
		availableSpin = playerData.AvailableSpin
		timeLeft = 0

		if availableSpin == 0 then
			local requestTime = os.time()
			timeLeft = math.max(0, spinTimeSeconds - (requestTime - playerData.LastSpinReward))
		end
	end

	return availableSpin, timeLeft
end

local function ProcessClientRequestForSpins(Player: Player)
	return GetUpdatedSpinsForPlayer(Player)
end

local function CalculateRewardForPlayer()
	local reward = math.random(1, 100)
	local cummulativeProbability = 0

	for prize, prizeTable in PrizeModule do
		cummulativeProbability += (prizeTable.probability * 100)
		if reward <= cummulativeProbability then
			return prize
		end
	end

	return "Prize1"
end

local function SpinWheelForClient(Player: Player)
	local availableSpin, timeLeft = GetUpdatedSpinsForPlayer(Player)

	if availableSpin > 0 then
		PlayerDataHandler:DeductSpins(Player, 1)
		PlayerDataHandler:SetLastSpinnerClaim(Player)

		local reward = CalculateRewardForPlayer()
		print("reward", reward)
		if PrizeModule[reward].prize == "Coins" then
			local amount = PrizeModule[reward].amount
			PlayerDataHandler:IncrementCoins(Player, amount)
		elseif PrizeModule[reward].prize == "UGC" then -- not using in this game rn
			--GrantAccessory:UGCPurchase(Player, ugcId["Hoodie"])
		end
		return true, reward == "" and "Prize1" or reward
	else
		return false, nil
	end
end

function SpinService.Client:GetSpinWheelForClient(player: Player)
	return SpinWheelForClient(player)
end

function SpinService.Client:GetAvailableSpins(player: Player)
	return ProcessClientRequestForSpins(player)
end

return SpinService
