-- [Services]				----
local PlayerService: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

-- [Modules]				-----
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")
local DailyRewardData: {} = require(Configuration:WaitForChild("DailyRewardData"))
local DataHandler: {} = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local ClaimTimeSeconds = 24 * 60 * 60
local StreakGraceSeconds = 48 * 60 * 60
local MAX_DAYS = 7 -- Right now its HardCode

local DailyRewardService = Knit.CreateService({
	Name = "DailyRewardService",
	Client = {},
})

-- [Functions]		-----

local function ComputeCurrentDay(streak: number): number
	return (streak % MAX_DAYS) + 1
end

local function GetUpdatedRewardsForPlayer(Player: Player)
	local playerData = DataHandler:GetData(Player) or {}
	local dailyStreak = tonumber(playerData.DailyStreak) or 0
	local lastDailyReward = tonumber(playerData.LastDailyReward) or 0
	return dailyStreak, lastDailyReward
end

local function CalculateStateForPlayer(player: Player)
	local dailyStreak, lastDailyReward = GetUpdatedRewardsForPlayer(player)

	local requestTime = os.time()
	local elapsed = (lastDailyReward > 0) and (requestTime - lastDailyReward) or math.huge

	-- reset streak
	if lastDailyReward > 0 and elapsed >= StreakGraceSeconds and dailyStreak ~= 0 then
		DataHandler:ResetStreak(player)
		dailyStreak = 0
	end

	local currentDay = ComputeCurrentDay(dailyStreak)
	local claimReady = (lastDailyReward == 0) or (elapsed >= ClaimTimeSeconds)
	local timeLeft = claimReady and 0 or math.max(0, ClaimTimeSeconds - elapsed)
	local nextClaimAt = claimReady and requestTime or (lastDailyReward + ClaimTimeSeconds)

	return {
		streak = dailyStreak,
		lastClaimAt = lastDailyReward,
		currentDay = currentDay,
		claimReady = claimReady,
		timeLeft = timeLeft,
		nextClaimAt = nextClaimAt,
	}
end

function ProcessClientRequest(player: Player, State: string)
	if State == "GetState" then
		local state = CalculateStateForPlayer(player)
		return true, state
	elseif State == "Claim" then
		local state = CalculateStateForPlayer(player)

		-- Grant Today's Reward
		local day = state.currentDay
		local entry = DailyRewardData[tostring(day)]
		if entry and entry.Currency == "Coins" and typeof(entry.Amount) == "number" then
			DataHandler:IncrementCoins(player, entry.Amount)
		end

		-- Increment streak and stamp time
		DataHandler:IncrementStreak(player, 1)
		DataHandler:SetLastDailyClaim(player)

		-- Return fresh state for UI
		local state = CalculateStateForPlayer(player)
		return true, state
	end
end

function DailyRewardService.Client:ProcessRequest(player, State)
	return ProcessClientRequest(player, State)
end

return DailyRewardService
