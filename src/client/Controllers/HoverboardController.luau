local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local RunService = Global.RunService
local UserInputService = Global.UserInputService
local TweenService = Global.TweenService
local workspace = Global.Workspace
local ReplicatedStorage = Global.ReplicatedStorage
local HoverboardModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")

local HoverboardData = require(HoverboardModules:WaitForChild("Hoverboards"))
local HoverboardMovement = require(HoverboardModules:WaitForChild("HoverboardMovement"))
local HoverboardJump = require(HoverboardModules:WaitForChild("HoverboardJump"))
local HoverboardPhysics = require(HoverboardModules:WaitForChild("HoverboardPhysics"))
local GameHUD = require(HoverboardModules:WaitForChild("GameHUD"))
local HoverboardUtils = require(HoverboardModules:WaitForChild("HoverboardUtils"))

-- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- State
local character, humanoid, rootPart
local hoverboard, bodyVelocity, bodyGyro, bodyPosition
local runningConnection
local inputVector = Vector3.zero
local isOnHoverboard = false
local isHoverboardInitialized = false
local HOVERBOARD_OFFSET = Vector3.new(0, 0, 0)

--UI References
local mainGUI = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local speedGUI = mainGUI:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
local boostLabel = speedGUI:WaitForChild("BoostVal")

--Constants
local MAX_SPEED = 80
local ACCELERATION = 2
local DECELERATION = 20
local MOVEMENT_SMOOTHNESS = 0.1
local MIN_MOVEMENT_THRESHOLD = 0.1
local ROTATION_SPEED = 500
local ROTATION_SMOOTHNESS = 0.006
local LEAN_SMOOTH = 10
local MAX_LEAN = 2
local HOVER_HEIGHT = 1.5
local RAY_DISTANCE = 20
local MAX_BODY_FORCE = 100000
local HOVER_SMOOTHNESS = 8
local ORIENTATION_SMOOTHNESS = 6

-- Boost System
local BOOST_VALUE = 20
local BOOST_DURATION = 0.5
local BOOST_COOLDOWN = 5
local isBoosting = false
local boostReady = true
local boostTimeLeft = 0

local State = {
	lastMoveDir = Vector3.zero,
	smoothedGroundNormal = Vector3.new(0, HOVER_HEIGHT, 0),
	baseHoverHeight = HOVER_HEIGHT,
	bobTime = 0,
}

--[[
   	Hoverboard Setup
]]
--

function HoverboardController:StartHoverboard(config)
	if runningConnection then
		runningConnection:Disconnect()
	end

	boostLabel.Text = "Boost Ready"
	local acceleration = config.Acceleration or ACCELERATION
	local topSpeed = config.TopSpeed or MAX_SPEED
	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)

	runningConnection = RunService.Heartbeat:Connect(function(dt)
		if not rootPart or not character or not hoverboard or not isOnHoverboard then
			return
		end
		local moveDir = HoverboardMovement.HandleMovement(
			humanoid,
			rootPart,
			hoverboard,
			bodyVelocity,
			topSpeed,
			acceleration,
			DECELERATION,
			MOVEMENT_SMOOTHNESS,
			MIN_MOVEMENT_THRESHOLD,
			State,
			dt
		)

		HoverboardMovement.UpdateOrientation(
			rootPart,
			bodyGyro,
			hoverboard,
			moveDir,
			HoverboardJump,
			ROTATION_SPEED,
			ROTATION_SMOOTHNESS,
			MAX_LEAN,
			LEAN_SMOOTH,
			State,
			dt
		)

		--HoverboardMovement.UpdateHoverboardOrientation(character, hoverboard, rootPart, RAY_DISTANCE, HOVER_SMOOTHNESS, State, dt)
		--HoverboardMovement.UpdateSurfaceAlignment(character, rootPart, bodyGyro, RAY_DISTANCE, ORIENTATION_SMOOTHNESS, State, HoverboardJump, hoverboard, dt)
		HoverboardJump.SetCurrentSpeed(HoverboardMovement.CurrentSpeed)
		HoverboardJump.UpdateLanding(dt) --Check for the ground detection
	end)
	GameHUD.UpdateSpeed(function()
		return HoverboardMovement.CurrentSpeed
	end)
end

function HoverboardController:SetActiveConfig(boardName)
	if isHoverboardInitialized then
		print("Hoverboard: Hoverboard already initialized, skipping SetActiveHoverboard")
		return
	end
	local config = HoverboardData.GetConfig(boardName)
	if not config then
		warn("Hoverboard: Could not find hoverboard config for " .. tostring(boardName))
		return
	end
	self.ActiveConfig = config
	print("Hoverboard: Active config: ", self.ActiveConfig)
	self:WaitForHoverboard(self.ActiveConfig)
end

function HoverboardController:WaitForHoverboard(config)
	if not character then
		return
	end

	if isHoverboardInitialized then
		print("Hoverboard: Hoverboard already initialized, skipping WaitForHoverboard")
		return
	end

	-- Check if we already have a hoverboard and are set up
	if hoverboard then
		print("Hoverboard: Hoverboard already existed")
		return
	end

	local hb = character:WaitForChild("Hoverboard", 5)
	if hb then
		print("Hoverboard: Hoverboard is assigned.")
		hoverboard = hb
		isOnHoverboard = true
		isHoverboardInitialized = true
		local primary = hoverboard:WaitForChild("PrimaryPart")
		bodyVelocity = primary:WaitForChild("BodyVelocity")
		bodyGyro = primary:WaitForChild("BodyGyro")
		bodyPosition = primary:WaitForChild("BodyPosition")
		HoverboardJump.SetReferences(hoverboard, character, rootPart, bodyPosition)
		HoverboardJump.SetHoverHeight(HOVER_HEIGHT)
		HoverboardController:StartHoverboard(config)
	end
end

function HoverboardController:ApplyBoost()
	if not boostReady then
		return
	end
	if HoverboardMovement.CurrentSpeed < 20 then
		return
	end
	print("Boost called.")
	isBoosting = true
	boostReady = false
	boostTimeLeft = BOOST_COOLDOWN

	-- Apply speed boost immediately
	HoverboardMovement.CurrentSpeed = HoverboardMovement.CurrentSpeed + BOOST_VALUE

	-- Temp acceleration boost
	local originalAcceleration = ACCELERATION
	ACCELERATION = 20

	task.delay(BOOST_DURATION, function()
		isBoosting = false
		ACCELERATION = originalAcceleration
	end)

	-- Cooldown management
	task.spawn(function()
		while boostTimeLeft > 0 do
			boostLabel.Text = "Boost CD: " .. string.format("%.1f", boostTimeLeft)
			boostTimeLeft = boostTimeLeft - 0.1
			task.wait(0.1)
		end
		boostReady = true
		boostLabel.Text = "Boost Ready"
	end)
	print("Boost completed.")
end

--[[
    State Management
]]
--
local function ResetStates()
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	bodyPosition = nil
end

local function CleanupHoverboard()
	print("Hoverboard: Clean up hoverboard called")
	isOnHoverboard = false
	HoverboardPhysics.Cleanup(hoverboard, bodyGyro, bodyVelocity, bodyPosition)
end

--[[
    Character Setup
]]
--
function HoverboardController:DisableAnimations(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
		track:Stop()
	end
	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end
	--hum:ChangeState(Enum.HumanoidStateType.Physics)
end

local function OnCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	HoverboardController:DisableAnimations(character)
	HoverboardUtils.BindInput(player)
end

local function OnCharacterRemoving()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	CleanupHoverboard()
	ResetStates()
	GameHUD.Cleanup()
end

local function OnPlayerAdded(plr)
	if plr ~= player then
		return
	end
	plr.CharacterAdded:Connect(OnCharacterAdded)
	plr.CharacterRemoving:Connect(OnCharacterRemoving)
	if plr.Character then
		OnCharacterAdded(plr.Character)
	end
end

--[[
    Knit Lifecycle
]]
--

function HoverboardController:KnitInit()
	print("HoverboardController initialized")
end

function HoverboardController:KnitStart()
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner ~= player then
			return
		end
		if isHoverboardInitialized then
			print("Hoverboard: Hoverboard already initialized, ignoring spawn event")
			return
		end
		HoverboardController:SetActiveConfig(boardName)
	end)
	HoverboardService.HoverboardRemoved:Connect(function()
		ResetStates()
		CleanupHoverboard()
	end)
	OnPlayerAdded(player)
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Q then
			print("Hoverboard: Boost requested.")
			HoverboardController:ApplyBoost()
		end
	end)
end

return HoverboardController
