-- [Services]			----
local PlayerService: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]			----
local Utility: Folder = ReplicatedStorage:WaitForChild("Utility")
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")
-- local EnumsAndConstants : Folder = ReplicatedStorage:WaitForChild("EnumsAndContants")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local TweenModule: {} = require(Utility:WaitForChild("TweenModule"))
local TimerModule: {} = require(Utility:WaitForChild("TimerModule"))
local PrizeModule: {} = require(Configuration:WaitForChild("SpinPrizeConfig"))

-- local Constants : {} = require(EnumsAndConstants:WaitForChild("Constants"))
-- local SoundModule: {} = require(Utility.SoundModule)

--[PlayerReferences]
local LocalPlayer = PlayerService.LocalPlayer

-- [Events]				----
-- local MarketPlaceEvent : RemoteEvent = SpinRewards:WaitForChild("MarketPlaceEvent")
-- local NotificationClientBE: BindableEvent = RemoteEvents:WaitForChild("NotificationClient")

-- [UI References]		----
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local DailySpin = PlayerGui:WaitForChild("DailySpin")

local MainFrame = DailySpin:WaitForChild("MainFrame")
local SecondaryFrame = MainFrame:WaitForChild("Frame")

local BtnsFrame = SecondaryFrame:WaitForChild("BtnsFrame")
local SpinImg = SecondaryFrame:WaitForChild("Frame"):WaitForChild("Wheel")
local Prizes = SpinImg:WaitForChild("Prizes")

local SpinButton = BtnsFrame:WaitForChild("SpinButton")
local SpinNumber = SpinButton:WaitForChild("Amount")

local SpinTimerText = MainFrame:WaitForChild("TimeLabel")
local CloseButton = DailySpin:WaitForChild("CloseButton")

-- local MainGui = PlayerGui:FindFirstChild("MainGui")
-- local CoinsFrame = MainGui:FindFirstChild("CoinsFrame")
-- local CoinsUI = CoinsFrame:FindFirstChild("CoinsTextLabel")

-- [Variables]			-----

-- handles debounce and insures minimal requests
local RequestTick = 0
local SpinRequestCooldown = 5

-- global spin and variable for a single update ui function
local Spins = 0
local TimeLeft = 0

-- ui open state manager
local TimerThread = nil

local SpinService = nil
local CoinsController = nil

local MarketPlaceSpinners: {} = nil

local SpinController = Knit.CreateController({
	Name = "SpinController",
})

local function OnCompleteTween(currentTween: Tween, rewardTable: {})
	local tweenCompleted = TweenModule.OnTweenCompleted(currentTween, function()
		task.delay(2, function()
			-- NotificationClientBE:Fire(rewardTable.amount .." Coins Claimed!")
			CoinsController:RefreshDisplay()
		end)
	end)
end

local function PlayWheelAnimation(WholeSpins, Delta, rewardTable)
	SpinImg.Rotation = 0
	local currentTween: Tween = TweenModule.Rotate(SpinImg, 5, WholeSpins + Delta, Enum.EasingStyle.Exponential)
	OnCompleteTween(currentTween, rewardTable)
end

local function UpdateUiState()
	local spinString = tostring(Spins)
	local timeLeftString = TimerModule.Timer(nil, TimeLeft)

	SpinNumber.Text = "x" .. spinString
	SpinTimerText.RichText = true

	if TimeLeft == 0 then
		SpinTimerText.Text = `Spin now! ( x{Spins} )`
	else
		SpinTimerText.Text = "Come back tomorrow for a new spin! (<font color='rgb(255,0,0)'>"
			.. timeLeftString
			.. "</font>)"
	end
end

local function CloseSpin()
	if TimerThread ~= nil then
		task.cancel(TimerThread)
	end
end

local function InitiateSpin()
	SpinService:GetAvailableSpins():andThen(function(UpdatedSpins, UpdatedTimeLeft)
		Spins = UpdatedSpins
		TimeLeft = UpdatedTimeLeft

		if not DailySpin.Enabled then
			return
		end

		if Spins == 0 and TimeLeft > 0 then
			TimerThread = task.spawn(function()
				while TimeLeft > 0 do
					if not DailySpin.Enabled then
						CloseSpin()
						break
					end

					UpdateUiState()
					TimeLeft -= 1
					task.wait(1)
				end

				InitiateSpin()
			end)
		elseif Spins == 0 and TimeLeft == 0 then
			task.wait(1)
			SpinService:GetAvailableSpins():andThen(function(UpdatedSpins, UpdatedTimeLeft)
				Spins = UpdatedSpins
				TimeLeft = UpdatedTimeLeft
				UpdateUiState()
			end)
		else
			UpdateUiState()
		end
	end)
end

local function UpdateTouchControls()
	local PlayerGui = PlayerService.LocalPlayer:FindFirstChild("PlayerGui")
	local touchControlFrame = PlayerGui:FindFirstChild("TouchGui")
	if touchControlFrame then
		touchControlFrame:FindFirstChild("TouchControlFrame").Visible = not DailySpin.Enabled
	end
end

local function OnMarketPlacePurchase(noOfSpin)
	if not MarketPlaceSpinners then
		MarketPlaceSpinners = {}
	end
	for i = 1, noOfSpin do
		table.insert(MarketPlaceSpinners, true)
	end
end

local function SpinWheel()
	local tickNow = tick()
	if tickNow - RequestTick < SpinRequestCooldown then
		-- NotificationClientBE:Fire("Spin request is being processed", "Error")
		return
	end
	RequestTick = tickNow

	SpinService:GetSpinWheelForClient():andThen(function(UpdatedcanSpin, Updatedreward)
		local canSpin = UpdatedcanSpin
		local reward = Updatedreward
		if canSpin then
			local rewardTable: {} = PrizeModule[reward]
			if rewardTable then
				local rewardLocations: NumberRange = rewardTable.location
				local wholeSpins: number = 5 * 360 -- math.random(5, 9) * 360
				local delta = math.random(rewardLocations.Min, rewardLocations.Max)
				PlayWheelAnimation(wholeSpins, delta, rewardTable)
				--SoundModule.PlayTouchSound(Constants.Sounds.SPIN_SOUND,1, 0.8)

				InitiateSpin()
			else
				warn("No reward table")
			end
		else
			-- NotificationClientBE:Fire("Daily spin not available for now.", "Error")
		end
	end)
end

local function HandleSpinFrame()
	-- handle spin information
	local uiState = DailySpin.Enabled
	if uiState then
		InitiateSpin()
	else
		CloseSpin()
	end

	-- disable/enable touch controls
	UpdateTouchControls()
end

-- local function AttributeChanged()
-- 	local Coins = LocalPlayer:GetAttribute("Coins")
-- 	CoinsUI.Text = Coins
-- end

function Initialize()
	-- InitializePrizesUI
	for prizeName, prizeData in pairs(PrizeModule) do
		local prizeFrame = Prizes:FindFirstChild(prizeName)

		if prizeFrame then
			-- Set Amount text
			local amountLabel = prizeFrame:FindFirstChild("Amount")
			if amountLabel then
				if prizeData.prize == "Coins" then
					amountLabel.Text = prizeData.amount
				end
			end
		else
			warn("No UI frame found for:", prizeName)
		end
	end
end

SpinButton.MouseButton1Click:Connect(SpinWheel)

function SpinController:Enable(Enabled: boolean)
	DailySpin.Enabled = Enabled
	HandleSpinFrame()
end

function SpinController:KnitStart()
	SpinService = Knit.GetService("SpinService")
	CoinsController = Knit.GetController("CoinsController")

	-- LocalPlayer:GetAttributeChangedSignal("Coins"):Connect(AttributeChanged)

	Initialize()
	HandleSpinFrame()
end

-- Open button already handle in Lobbyhud
-- CloseButton.MouseButton1Click:Connect(function()
-- 	SpinController:SetEnabled(false)
-- 	SpinController.LobbyHUD:OpenContainer("MainGui")
-- end)

-- function SpinController:SetEnabled(enabled: boolean)
-- 	DailySpin.Enabled = enabled
--  HandleSpinFrame()
-- end

--MarketPlaceEvent.OnClientEvent:Connect(OnMarketPlacePurchase)

return SpinController
