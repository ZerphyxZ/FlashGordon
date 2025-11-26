--[Services]
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[Modules]
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")
local TimeRewardData: {} = require(Configuration:WaitForChild("TimeRewardData"))
local DataHandler: {} = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

--[Constants]
local PlayersJoinTime = {}
local PlayersClaimedRewards = {}

--[Service Intialization]
local TimeRewardServer = Knit.CreateService({
	Name = "TimeRewardServer",
	Client = {
		ProcessPlayerReward = Knit.CreateSignal(),
		RewardClaimed = Knit.CreateSignal(),
	},
})

local function LockRewardsForPlayer(player)
	PlayersClaimedRewards[player] = {}
	for index, RewardData in TimeRewardData do
		PlayersClaimedRewards[player][index] = false
	end
end

local function AreAllRewardsClaimed(player)
	for index, Claimed in PlayersClaimedRewards[player] do
		if not Claimed then
			return false
		end
	end

	return true
end

local function GetPlayerInGameTime(player)
	local PlayerJoinTime = PlayersJoinTime[player]
	if not PlayerJoinTime then
		return 0
	end
	local PlayerInGameTime = workspace:GetServerTimeNow() - PlayerJoinTime

	return PlayerInGameTime
end

local function RefreshPlayerJoinTime(player)
	if not PlayersJoinTime[player] then
		local JoinTime = workspace:GetServerTimeNow()
		PlayersJoinTime[player] = JoinTime
		LockRewardsForPlayer(player)
		return JoinTime
	end

	if not AreAllRewardsClaimed(player) then
		return PlayersJoinTime[player]
	end

	local JoinTime = workspace:GetServerTimeNow()
	PlayersJoinTime[player] = JoinTime
	LockRewardsForPlayer(player)

	return JoinTime
end

local function ProcessTimeReward(player, RewardIndex)
	if typeof(RewardIndex) ~= "number" then
		warn("Index Type Not Number")
	end

	if PlayersClaimedRewards[player][RewardIndex] then
		warn("Reward Already Claimed")
	end

	local RewardData = TimeRewardData[RewardIndex]
	if not RewardData then
		warn("Reward Not Found")
	end

	local PlayerInGameTime = GetPlayerInGameTime(player)
	local RewardTime = RewardData.RequiredTime

	if RewardTime <= PlayerInGameTime then
		PlayersClaimedRewards[player][RewardIndex] = true

		local RewardType = RewardData.RewardType
		if RewardType == "Coins" then
			local Amount = RewardData.Amount
			DataHandler:IncrementCoins(player, Amount)
			TimeRewardServer.Client.RewardClaimed:Fire(player, RewardIndex)
		end
	end
end

function TimeRewardServer:KnitStart()
	self.Client.ProcessPlayerReward:Connect(ProcessTimeReward)

	PlayerService.PlayerRemoving:Connect(function(player)
		PlayersJoinTime[player] = nil
		PlayersClaimedRewards[player] = nil
	end)
end

function TimeRewardServer.Client:RefreshAndGetJoinTime(player)
	return RefreshPlayerJoinTime(player)
end

return TimeRewardServer
