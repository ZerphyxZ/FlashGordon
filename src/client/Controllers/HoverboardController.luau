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
local Speed = require(HoverboardModules:WaitForChild("HoverboardSpeed"))
local HoverboardUtils = require(HoverboardModules:WaitForChild("HoverboardUtils"))
local BoostAbility = require(HoverboardModules:WaitForChild("HoverboardBoost"))
local DashAbility = require(HoverboardModules:WaitForChild("DashAbility"))

-- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- State
local character, humanoid, rootPart
local hoverboard, bodyVelocity, bodyGyro, bodyPosition
local runningConnection, abilityConnection
local inputVector = Vector3.zero
local isOnHoverboard = false
local isHoverboardInitialized = false
local HOVERBOARD_OFFSET = Vector3.new(0, 0, 0)

--UI References
local mainGUI = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local speedGUI = mainGUI:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")

--Constants
local MAX_SPEED = 80
local ACCELERATION = 2
local DECELERATION = 20
local MOVEMENT_SMOOTHNESS = 0.1
local MIN_MOVEMENT_THRESHOLD = 0.1
local ROTATION_SPEED = 60
local ROTATION_SMOOTHNESS = 0.05
local LEAN_SMOOTH = 30
local MAX_LEAN = 2.2
local LEAN_MULTIPLIER = 120
local HOVER_HEIGHT = 1.5
local RAY_DISTANCE = 20
local MAX_BODY_FORCE = 100000
local HOVER_SMOOTHNESS = 8
local ORIENTATION_SMOOTHNESS = 6

-- Mutable refs so BoostModule can modify them
local currentAccelerationRef = { value = ACCELERATION }
local currentTopSpeedRef = { value = MAX_SPEED }

-- References to PlayerModule controls
local controls
local function GetControls()
	if controls then return controls end
	local playerScripts = player:WaitForChild("PlayerScripts")
	controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
	return controls
end

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

	local acceleration = config.Acceleration or ACCELERATION
	local topSpeed = config.TopSpeed or MAX_SPEED
	currentAccelerationRef.value = acceleration
	currentTopSpeedRef.value = topSpeed
	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)

	runningConnection = RunService.Heartbeat:Connect(function(dt)
		if not rootPart or not character or not hoverboard or not isOnHoverboard then
			return
		end
		local moveDir = HoverboardMovement.HandleMovement(humanoid, rootPart, hoverboard, bodyVelocity, topSpeed, acceleration, DECELERATION,
			MOVEMENT_SMOOTHNESS, MIN_MOVEMENT_THRESHOLD, State, BoostAbility.isBoosting, dt)

		HoverboardMovement.UpdateOrientation(rootPart, bodyGyro, hoverboard, moveDir, HoverboardJump, ROTATION_SPEED, ROTATION_SMOOTHNESS,
			MAX_LEAN, LEAN_SMOOTH, LEAN_MULTIPLIER, State, dt)

		HoverboardMovement.UpdateSurfaceAlignment(character, rootPart, bodyGyro, RAY_DISTANCE, ORIENTATION_SMOOTHNESS, State, HoverboardJump, hoverboard, dt)
		HoverboardJump.SetCurrentSpeed(HoverboardMovement.CurrentSpeed)
		HoverboardJump.UpdateLanding(humanoid, dt) --Check for the ground detection
	end)
	Speed.UpdateSpeed(function() return HoverboardMovement.CurrentSpeed end, function() return topSpeed end)
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
		HoverboardController:DisableAnimations(character)
		HoverboardController:StartHoverboard(config)
	end
end

function HoverboardController:ApplyBoost()
	BoostAbility.ApplyBoost(HoverboardMovement.CurrentSpeed, currentAccelerationRef, currentTopSpeedRef)
end

function HoverboardController:ApplyDash()
	if not HoverboardMovement then print("No hoverboard movement found!") return end
	if not DashAbility.CanDash(HoverboardMovement.CurrentSpeed) then 
		return 
	end

	print("Dash called.")
	local moveDir = State.lastMoveDir
	if moveDir.Magnitude == 0 then
		moveDir = rootPart.CFrame.LookVector
	end

	DashAbility.PerformDash(hoverboard, HoverboardMovement.CurrentSpeed, moveDir, bodyVelocity)
end

--[[
    State Management
]]
--
local function ResetStates()
	HoverboardMovement.CurrentSpeed = 0
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	bodyPosition = nil
	isHoverboardInitialized = false
	isOnHoverboard = false
	State.lastMoveDir = Vector3.zero
	State.smoothedGroundNormal = Vector3.new(0, HOVER_HEIGHT, 0)
	State.baseHoverHeight = HOVER_HEIGHT
	HoverboardJump.ResetJumpStates()
end

local function CleanupHoverboard()
	print("Hoverboard: Clean up hoverboard called")
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
	hum:ChangeState(Enum.HumanoidStateType.Physics)
end

function HoverboardController:SetFieldOfView(dt)
	-- Camera FOV control
	local camera = workspace.CurrentCamera
	local targetFOV = 60

	-- Increase FOV when moving
	if HoverboardMovement.CurrentSpeed > 1 then
		targetFOV = 70
	else
		targetFOV = 60
	end

	-- Smooth FOV transition (exponential smoothing)
	local FOV_SMOOTHNESS = 8 -- tweak for faster/slower transition
	local smooth = 1 - math.exp(-FOV_SMOOTHNESS * dt)
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * smooth
end

local function OnCharacterAdded(char)
	ResetStates()
	
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	HoverboardUtils.BindJump(HoverboardJump)
	BoostAbility.CharAdded(character, humanoid, rootPart)
	Speed.RefreshSpeedGUI()
	
	if abilityConnection then
		abilityConnection:Disconnect()
	end
	abilityConnection = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			print("Hoverboard: Boost requested.")
			HoverboardController:ApplyBoost()
		elseif input.KeyCode == Enum.KeyCode.F then
			print("Hoverboard: Dash requested.")
			HoverboardController:ApplyDash()
		end
	end)
end

local function OnCharacterRemoving()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	if abilityConnection then
		abilityConnection:Disconnect()
		abilityConnection = nil
	end
	CleanupHoverboard()
	ResetStates()
	HoverboardUtils.UnBindJump()
	Speed.Cleanup()
	BoostAbility.CharRemoving()
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
	HoverboardService.ControlSignal:Connect(function(action)
		local ctrl = GetControls()

		if action == "Disable" then
			ctrl:Disable()
		elseif action == "Enable" then
			ctrl:Enable()
		end
	end)
	OnPlayerAdded(player)
	BoostAbility.Init(player)
end

return HoverboardController