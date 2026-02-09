--[Services]
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--[Player reference]
local LocalPlayer = PlayerService.LocalPlayer

--[Folders]
local PackagesFolder = ReplicatedStorage:WaitForChild("Packages")
local Configuration = ReplicatedStorage:WaitForChild("Configuration")

--[Modules]
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local TimeRewardData: {} = require(Configuration:WaitForChild("TimeRewardData"))
local TroveModule = require(PackagesFolder:WaitForChild("trove"))
local Trove = TroveModule.new()

--[UI References]
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RewardsGUI = PlayerGui:WaitForChild("Rewards")
local Rewards = RewardsGUI:WaitForChild("Rewards")
local Contents = Rewards:WaitForChild("Contents")
local TimeFrame = Contents:WaitForChild("Time")
local CodesFrame = Contents:WaitForChild("Codes")
local DailyFrame = Contents:WaitForChild("Daily")
local ProductTemplate = TimeFrame:WaitForChild("Template")

local Sections = Rewards:WaitForChild("Sections")
local TimeButton = Sections:WaitForChild("Time")
local DailyRewardButton = Sections:WaitForChild("Daily")
local CodesButton = Sections:WaitForChild("Codes")

--[Constants]
local TweenInfo1 = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TweenInfo2 = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true)
local TweenInfo3 = TweenInfo.new(0.02, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true)
local Products = {}
local TimeRewardServer
local CoinsController

--[Controller Initialization]
local TimeRewardController = Knit.CreateController({
	Name = "TimeRewardController",
})

local function AnimateReward(RewardImage, RewardIndex)
	local UiScale = RewardImage:FindFirstChild("UIScale")

	if not UiScale then
		UiScale = Instance.new("UIScale")
		UiScale.Parent = RewardImage
		UiScale.Scale = 1
	end

	local HoverTween = TweenService:Create(UiScale, TweenInfo1, { Scale = 1.1 })
	local ReverseTween = TweenService:Create(UiScale, TweenInfo1, { Scale = 1 })
	local LeftRotateTween = TweenService:Create(RewardImage, TweenInfo2, { Rotation = 15 })
	local RightRotateTween = TweenService:Create(RewardImage, TweenInfo3, { Rotation = -10 })

	RewardImage.MouseEnter:Connect(function()
		local RewardData = Products[RewardIndex]
		if not RewardData.CanClaim then
			return
		end
		RewardImage.Rotation = 0
		HoverTween:Play()
		LeftRotateTween:Play()
		LeftRotateTween.Completed:Wait()
		RightRotateTween:Play()
	end)
	RewardImage.MouseLeave:Connect(function()
		ReverseTween:Play()
		RewardImage.Rotation = 0
	end)
end

local function DisableClaimReward()
	for RewardIndex, ProductData in Products do
		ProductData.Opened = false
		ProductData.CanClaim = false
		ProductData.RewardOpen.Visible = false
		ProductData.CheckMark.Visible = false
		ProductData.ClaimButton.Interactable = false
	end
end

local function AreAllRewardsClaimed()
	for RewardIndex, ProductData in Products do
		if not ProductData.Opened then
			return false
		end
	end

	return true
end

local function TryReset()
	if AreAllRewardsClaimed() then
		DisableClaimReward()
		StartAllRewardsTimer()
	end
end

local function EnableRewardClaimed(ProductData)
	ProductData.RewardOpen.Visible = true
	ProductData.CheckMark.Visible = true
	ProductData.TimeLeft.Text = "Claimed"
	ProductData.Opened = true
	ProductData.CanClaim = false
	ProductData.ClaimButton.Interactable = false

	local UiScale = ProductData.Reward:FindFirstChild("UIScale")

	if UiScale then
		UiScale.Scale = 1
	end
end

local function EnableClaimReward(ProductData)
	ProductData.TimeLeft.Text = "Claim"
	ProductData.CanClaim = true
	ProductData.ClaimButton.Interactable = true
end

local function RewardClaimedSuccessfully(RewardIndex)
	CoinsController:RefreshDisplay()

	local ProductData = Products[RewardIndex]
	if ProductData then
		EnableRewardClaimed(ProductData)
		TryReset()
	end
end

local function CreateProduct(RewardData, RewardIndex)
	local self = {}

	self.Frame = ProductTemplate:Clone()
	self.Name = RewardIndex
	self.Frame.Name = self.Name
	self.ClaimButton = self.Frame.Button
	self.Content = self.Frame.Content
	self.Title = self.Content.Title
	self.TimeLeft = self.Content.TimeLeft
	self.Reward = self.Content.Reward
	self.RewardOpen = self.Content.RewardOpen
	self.CheckMark = self.Content.CheckMark

	self.Opened = false
	self.CanClaim = false

	self.RequiredTime = RewardData.RequiredTime

	self.Title.Text = RewardData.Title
	self.TimeLeft.Text = self.RequiredTime
	self.Reward.Image = RewardData.ImageID

	self.Frame.Visible = true
	self.Frame.Parent = TimeFrame

	return self
end

local function EnableTime()
	DailyFrame.Visible = false
	DailyRewardButton:WaitForChild("Select").Visible = false
	CodesFrame.Visible = false
	CodesButton:WaitForChild("Select").Visible = false
	TimeFrame.Visible = true
	TimeButton:WaitForChild("Select").Visible = true
end

function StartAllRewardsTimer()
	TimeRewardServer:RefreshAndGetJoinTime():andThen(function(StartTime)
		if not StartTime then
			return
		end

		for Productindex, ProductData in pairs(Products) do
			task.spawn(function()
				while true do
					local TimeLeft = (StartTime + ProductData.RequiredTime) - workspace:GetServerTimeNow()
					if TimeLeft > 0 then
						ProductData.TimeLeft.Text =
							`{math.floor(TimeLeft / 60)}:{string.format("%02d", math.floor(TimeLeft % 60))}`
					else
						EnableClaimReward(ProductData)
						break
					end
					task.wait(1)
				end
			end)
		end
	end)
end

function TimeRewardController:Enable(enabled: boolean)
	RewardsGUI.Enabled = enabled

	if enabled then
		EnableTime()
	end
end

function TimeRewardController:KnitStart()
	TimeRewardServer = Knit.GetService("TimeRewardServer")
	CoinsController = Knit.GetController("CoinsController")

	for index, RewardData in ipairs(TimeRewardData) do
		local Product = CreateProduct(RewardData, index)

		Trove:Connect(Product.ClaimButton.MouseButton1Down, function()
			TimeRewardServer.ProcessPlayerReward:Fire(Product.Name)
		end)

		AnimateReward(Product.Reward, Product.Name)

		Products[Product.Name] = Product
	end

	TimeRewardServer.RewardClaimed:Connect(RewardClaimedSuccessfully)
	TimeButton.MouseButton1Click:Connect(EnableTime)

	StartAllRewardsTimer()
end

return TimeRewardController
