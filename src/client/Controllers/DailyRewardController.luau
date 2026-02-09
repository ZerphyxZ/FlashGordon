-- [Services]			----
local PlayerService: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]			----
-- local Utility: Folder = ReplicatedStorage:WaitForChild("Utility")
-- local EnumsAndConstants: Folder = ReplicatedStorage:WaitForChild("EnumsAndContants")
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local DailyRewardConfig: {} = require(Configuration:WaitForChild("DailyRewardData"))
-- local Constants : {} = require(EnumsAndConstants:WaitForChild("Constants"))
-- local SoundModule: {} = require(Utility.SoundModule)

-- [Remotes]			----
-- local NotificationClientBE: BindableEvent = Remotes:WaitForChild("NotificationClient")

-- [UI References]		----
local PlayerGui = PlayerService.LocalPlayer:WaitForChild("PlayerGui")
local RewardsGUI = PlayerGui:WaitForChild("Rewards")
local Rewards = RewardsGUI:WaitForChild("Rewards")
local Contents = Rewards:WaitForChild("Contents")

local Codes = Contents:WaitForChild("Codes")
local Daily = Contents:WaitForChild("Daily")
local Time = Contents:WaitForChild("Time")

local Sections = Rewards:WaitForChild("Sections")
local DailyRewardButton = Sections:WaitForChild("Daily")
local CodesButton = Sections:WaitForChild("Codes")
local TimeButton = Sections:WaitForChild("Time")

local CloseButton = Rewards:WaitForChild("Close")

local NormalTemplate = Daily:WaitForChild("NormalTemplate")
local DaySevenTemplate = Daily:WaitForChild("DaySevenTemplate")

-- [Variables]		----
local streak = 0
local currentDay = 1
local nextClaimAt = nil
local MAX_DAYS = 7

local connection = nil

local Frames = {}
local days = {}

local DailyRewardService = nil
local CoinsController = nil

local DailyRewardController = Knit.CreateController({
	Name = "DailyRewardController",
})

local function FormatHHMMSS(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function StopCountdown()
	--print("StopCountdown")
	if connection then
		connection:Disconnect()
		connection = nil
	end
	nextClaimAt = nil
end

local function StartCountdown(tNext: number, timeLabel, button)
	--print("StartCountdown")
	StopCountdown()
	nextClaimAt = tNext

	connection = RunService.RenderStepped:Connect(function()
		if not nextClaimAt then
			return
		end

		local left = nextClaimAt - os.time()
		if left <= 0 then
			StopCountdown()
			button.Text = "Claim"
			button.Visible = true
			timeLabel.Visible = false
		else
			timeLabel.TextLabel.Text = FormatHHMMSS(left)
		end
	end)
end

local function EnableDailyReward()
	Time.Visible = false
	TimeButton:WaitForChild("Select").Visible = false
	Codes.Visible = false
	CodesButton:WaitForChild("Select").Visible = false
	Daily.Visible = true
	DailyRewardButton:WaitForChild("Select").Visible = true
	DailyRewardController:UpdateRewards()
end

function Initialize()
	for day in pairs(DailyRewardConfig) do
		table.insert(days, day)
	end
	table.sort(days, function(a, b)
		return tonumber(a) < tonumber(b)
	end)

	NormalTemplate.Visible = false
	DaySevenTemplate.Visible = false

	for _, day in ipairs(days) do
		local reward = DailyRewardConfig[day]
		local item

		if day == "7" then
			item = DaySevenTemplate:Clone()
		else
			item = NormalTemplate:Clone()
		end

		item.Name = day
		item.LayoutOrder = tonumber(day)
		item.Visible = true
		item.Parent = Daily

		local icon = item:FindFirstChild("Icon") :: ImageLabel?
		local prize = item:FindFirstChild("Prize") :: ImageLabel?
		local title = item:FindFirstChild("Day") :: TextLabel?
		local button = item:FindFirstChild("Action") :: TextButton | ImageButton?
		local check = item:FindFirstChild("Checkmark")
		local timer = item:FindFirstChild("Timer") :: TextLabel?

		title.Text = "Day 0" .. tonumber(day) --"Day " .. day
		icon.Image = reward.Image
		prize.Text = reward.Amount --"+" .. reward.Amount

		icon.Visible = true
		check.Visible = false
		timer.Visible = false

		if button then
			button.Text = ("Day %d"):format(day)
			button.Visible = true

			button.MouseButton1Click:Connect(function()
				local index = tonumber(button.Parent.Name)
				if typeof(index) ~= "number" or index ~= currentDay then
					--warn("Index is not equal to current day")
					return
				end

				button.Visible = false

				-- Attempt claim
				DailyRewardService:ProcessRequest("Claim"):andThen(function(okServer, payload)
					if okServer then
						currentDay = payload.currentDay
						streak = payload.streak
						UpdateState(payload)
						CoinsController:RefreshDisplay()
					else
						warn("No okServer")
					end
				end)
			end)
		end

		Frames[day] = item
	end
end

function UpdateState(state: { [string]: any })
	-- state = { streak, currentDay, claimReady, timeLeft, nextClaimAt }
	streak = state.streak or 0
	currentDay = state.currentDay or 1

	local claimedDays = (streak % MAX_DAYS)

	for _, day in ipairs(days) do
		local item = Frames[day]
		if not item then
			continue
		end

		local icon = item:FindFirstChild("Icon")
		local button = item:FindFirstChild("Action")
		local check = item:FindFirstChild("Checkmark")
		local timer = item:FindFirstChild("Timer")

		button.Visible = false
		check.Visible = false
		timer.Visible = false

		icon.Visible = true

		local day = tonumber(day)
		if day <= claimedDays and streak > 0 then -- already claimed
			check.Visible = true
			check.TextLabel.Text = "Claimed"

			button.Visible = false
			timer.Visible = false
		elseif day == currentDay then -- Today
			if state.claimReady then
				StopCountdown()

				button.Visible = true
				button.Text = "Claim"

				timer.Visible = false
			else
				timer.Visible = true

				button.Visible = false
				if state.nextClaimAt then
					StartCountdown(state.nextClaimAt, timer, button)
				end
			end
		else -- Future days
			check.Visible = true
			check.TextLabel.Text = "Day " .. day

			button.Visible = false
			timer.Visible = false
		end
	end
end

function DailyRewardController:UpdateRewards()
	DailyRewardService:ProcessRequest("GetState"):andThen(function(okServer, payload)
		if not okServer then
			warn("DailyRewards: server responded error: ", payload)
			return
		end
		UpdateState(payload)
	end)
end

function DailyRewardController:Enable(enabled: boolean)
	RewardsGUI.Enabled = enabled

	if enabled then
		EnableDailyReward()
	else
		StopCountdown()
	end
end

-- Open button already handled in Lobbyhud
CloseButton.MouseButton1Click:Connect(function()
	-- DailyRewardController.LobbyHUD:OpenContainer("MainGui")
	RewardsGUI.Enabled = false
end)

function DailyRewardController:KnitStart()
	DailyRewardService = Knit.GetService("DailyRewardService")
	CoinsController = Knit.GetController("CoinsController")

	DailyRewardButton.MouseButton1Click:Connect(EnableDailyReward)
	Initialize()
end

return DailyRewardController
