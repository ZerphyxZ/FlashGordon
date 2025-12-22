local Global =
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
-- local Players = Global.Players
-- local player = Players.LocalPlayer
-- local RunService = Global.RunService
-- local UserInputService = Global.UserInputService
-- local TweenService = Global.TweenService
-- local workspace = Global.Workspace
-- local ReplicatedStorage = Global.ReplicatedStorage
-- local Configuration = ReplicatedStorage:WaitForChild("Configuration")
-- local HoverboardModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")

-- local HoverboardData = require(Configuration:WaitForChild("HoverboardData"))
-- local HoverboardMovement = require(HoverboardModules:WaitForChild("HoverboardMovement"))
-- local HoverboardJump = require(HoverboardModules:WaitForChild("HoverboardJump"))
-- local HoverboardPhysics = require(HoverboardModules:WaitForChild("HoverboardPhysics"))
-- local Speed = require(HoverboardModules:WaitForChild("HoverboardSpeed"))
-- local HoverboardUtils = require(HoverboardModules:WaitForChild("HoverboardUtils"))
-- local BoostAbility = require(HoverboardModules:WaitForChild("HoverboardBoost"))
-- local DashAbility = require(HoverboardModules:WaitForChild("HoverboardDash"))
-- local cameraFOV = require(HoverboardModules:WaitForChild("CameraFOV"))
-- local HoverboardBobbing = require(HoverboardModules:WaitForChild("HoverboardBobbing"))

-- -- UI References
-- local playerGUI = player:WaitForChild("PlayerGui")
-- local gameHUD = playerGUI:WaitForChild("GameHUD")
-- local mainGUI = playerGUI:WaitForChild("MainGui")

-- -- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
-- local HoverboardService

-- -- State
-- local character, humanoid, rootPart
-- local hoverboard, bodyVelocity, bodyGyro, bodyPosition
-- local runningConnection
-- local isOnHoverboard = false
-- local isHoverboardInitialized = false
-- local Jump = HoverboardJump.State

-- --Constants
-- local MAX_SPEED = 80
-- local ACCELERATION = 2
-- local DECELERATION = 2
-- local MOVEMENT_SMOOTHNESS = 1
-- local MIN_THROTTLING_THRESHOLD = 0.1
-- local MIN_SPEED_THRESHOLD = 20
-- local ROTATION_SPEED = 20
-- local ROTATION_SMOOTHNESS = 0.9
-- local LEAN_SMOOTH = 25
-- local MAX_LEAN = 1.5
-- local LEAN_MULTIPLIER = 70
-- local HOVER_HEIGHT = 3
-- local RAY_DISTANCE = 20
-- local MAX_BODY_FORCE = 100000
-- local HOVER_SMOOTHNESS = 8
-- local ORIENTATION_SMOOTHNESS = 6

-- -- Mutable refs so BoostModule can modify them
-- local currentAccelerationRef = { value = ACCELERATION }
-- local currentTopSpeedRef = { value = MAX_SPEED }

-- -- References to PlayerModule controls
-- local controls
-- local function GetControls()
-- 	if controls then
-- 		return controls
-- 	end
-- 	local playerScripts = player:WaitForChild("PlayerScripts")
-- 	controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
-- 	return controls
-- end

-- local State = {
-- 	lastMoveDir = Vector3.zero,
-- 	smoothedGroundNormal = Vector3.new(0, HOVER_HEIGHT, 0),
-- 	baseHoverHeight = HOVER_HEIGHT,
-- 	bobTime = 0,
-- }

-- --[[
--    	Hoverboard Setup
-- ]]
-- --

-- function HoverboardController:StartHoverboard(config)
-- 	if runningConnection then
-- 		runningConnection:Disconnect()
-- 	end

-- 	local acceleration = config.Acceleration or ACCELERATION
-- 	local topSpeed = config.TopSpeed or MAX_SPEED
-- 	currentAccelerationRef.value = acceleration
-- 	currentTopSpeedRef.value = topSpeed
-- 	HoverboardJump.SetMaxSpeed(topSpeed)
-- 	BoostAbility.BindBoost(character, humanoid, rootPart, function() return HoverboardMovement.CurrentSpeed end, currentAccelerationRef, currentTopSpeedRef)
-- 	DashAbility.BindDash(character, humanoid, rootPart, function() return HoverboardMovement.CurrentSpeed end, hoverboard, State)
-- 	HoverboardController:EnableHUD()
-- 	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)

-- 	runningConnection = RunService.Heartbeat:Connect(function(dt)
-- 		if
-- 			not rootPart
-- 			or not character
-- 			or not hoverboard
-- 			or not isOnHoverboard
-- 			or not bodyVelocity
-- 			or not bodyGyro
-- 			or not bodyPosition
-- 		then
-- 			print("physics not attached yet")
-- 			return
-- 		end

-- 		local moveDir = HoverboardMovement.HandleMovement(
-- 			humanoid,
-- 			rootPart,
-- 			hoverboard,
-- 			bodyVelocity,
-- 			topSpeed,
-- 			acceleration,
-- 			DECELERATION,
-- 			MOVEMENT_SMOOTHNESS,
-- 			MIN_THROTTLING_THRESHOLD,
-- 			State,
-- 			BoostAbility.isBoosting,
-- 			dt
-- 		)

-- 		HoverboardJump.State.moveDir = moveDir

-- 		HoverboardMovement.UpdateOrientation(rootPart, bodyGyro, hoverboard, moveDir, HoverboardJump, MIN_SPEED_THRESHOLD, ROTATION_SPEED, ROTATION_SMOOTHNESS,
-- 			MAX_LEAN, LEAN_SMOOTH, LEAN_MULTIPLIER, State, dt)

-- 		HoverboardMovement.UpdateSurfaceAlignment1(
-- 			character,
-- 			rootPart,
-- 			bodyGyro,
-- 			RAY_DISTANCE,
-- 			ORIENTATION_SMOOTHNESS,
-- 			State,
-- 			HoverboardJump,
-- 			hoverboard,
-- 			HOVER_HEIGHT,
-- 			dt
-- 		)

-- 		--HoverboardMovement.UpdateHoverboardOrientation(character, hoverboard, rootPart, RAY_DISTANCE, HOVER_SMOOTHNESS, State, dt)
-- 		HoverboardJump.SetCurrentSpeed(HoverboardMovement.CurrentSpeed)
-- 		HoverboardJump.UpdateLanding(humanoid, dt) --Check for the ground detection
-- 		--cameraFOV.Update(dt, moveDir, BoostAbility.isBoosting, HoverboardJump.State.isJumping, HoverboardJump.State.isFalling)
-- 	end)
-- 	Speed.UpdateSpeed(function()
-- 		return HoverboardMovement.CurrentSpeed
-- 	end, function()
-- 		return topSpeed
-- 	end)
-- end

-- function HoverboardController:SetActiveConfig(boardName)
-- 	if isHoverboardInitialized then
-- 		print("Hoverboard: Hoverboard already initialized, skipping SetActiveHoverboard")
-- 		return
-- 	end
-- 	local config = HoverboardData.GetConfig(boardName)
-- 	if not config then
-- 		warn("Hoverboard: Could not find hoverboard config for " .. tostring(boardName))
-- 		return
-- 	end
-- 	self.ActiveConfig = config
-- 	print("Hoverboard: Active config: ", self.ActiveConfig)
-- 	self:WaitForHoverboard(self.ActiveConfig)
-- end

-- function HoverboardController:WaitForHoverboard(config)
-- 	if not character then
-- 		return
-- 	end

-- 	if isHoverboardInitialized then
-- 		print("Hoverboard: Hoverboard already initialized, skipping WaitForHoverboard")
-- 		return
-- 	end

-- 	-- Check if we already have a hoverboard and are set up
-- 	if hoverboard then
-- 		print("Hoverboard: Hoverboard already existed")
-- 		return
-- 	end

-- 	local hb = character:WaitForChild("Hoverboard", 5)
-- 	if hb then
-- 		print("Hoverboard: Hoverboard is assigned.")
-- 		hoverboard = hb
-- 		isOnHoverboard = true
-- 		isHoverboardInitialized = true
-- 		local primary = hoverboard:WaitForChild("PrimaryPart")
-- 		bodyVelocity = primary:WaitForChild("BodyVelocity")
-- 		bodyGyro = primary:WaitForChild("BodyGyro")
-- 		bodyPosition = primary:WaitForChild("BodyPosition")
-- 		if bodyVelocity and bodyGyro and bodyPosition then
-- 			HoverboardJump.SetReferences(hoverboard, character, rootPart, bodyPosition, humanoid)
-- 			HoverboardJump.SetHoverHeight(HOVER_HEIGHT)
-- 			HoverboardController:DisableAnimations(character)
-- 			HoverboardController:StartHoverboard(config)
-- 		else
-- 			warn("Hoverboard: Physics objects not ready, retrying...")
-- 			-- Retry after a brief moment
-- 			task.spawn(function()
-- 				task.wait(0.1)
-- 				if character and character.Parent then
-- 					self:WaitForHoverboard(config)
-- 				end
-- 			end)
-- 		end
-- 	end
-- end

-- --[[
--     State Management
-- ]]
-- --
-- local function ResetStates()
-- 	HoverboardMovement.CurrentSpeed = 0
-- 	hoverboard = nil
-- 	bodyVelocity = nil
-- 	bodyGyro = nil
-- 	bodyPosition = nil
-- 	isHoverboardInitialized = false
-- 	isOnHoverboard = false
-- 	State.lastMoveDir = Vector3.zero
-- 	State.smoothedGroundNormal = Vector3.new(0, HOVER_HEIGHT, 0)
-- 	State.baseHoverHeight = HOVER_HEIGHT
-- 	HoverboardJump.ResetJumpStates()
-- end

-- local function CleanupHoverboard()
-- 	print("Hoverboard: Clean up hoverboard called")
-- 	HoverboardPhysics.Cleanup(hoverboard, bodyGyro, bodyVelocity, bodyPosition)
-- end

-- --[[
--     Character Setup
-- ]]
-- --

-- function HoverboardController:EnableHUD()
-- 	gameHUD.Enabled = true
-- end

-- function HoverboardController:DisableAnimations(char)
-- 	local hum = char:FindFirstChildOfClass("Humanoid")
-- 	if not hum then
-- 		return
-- 	end
-- 	for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
-- 		track:Stop()
-- 	end
-- 	local animate = char:FindFirstChild("Animate")
-- 	if animate then
-- 		animate.Disabled = true
-- 	end

-- 	if bodyVelocity and bodyGyro and bodyPosition then
-- 		--hum:ChangeState(Enum.HumanoidStateType.Physics)
-- 	end
-- end

-- local function HumanoidSetup()
-- 	humanoid.MaxSlopeAngle = 0
-- 	humanoid.AutoRotate = false
-- 	humanoid.UseJumpPower = true
-- 	humanoid.JumpPower = 70
-- end

-- local function OnCharacterAdded(char)
-- 	ResetStates()

-- 	character = char
-- 	humanoid = char:WaitForChild("Humanoid")
-- 	rootPart = char:WaitForChild("HumanoidRootPart")
-- 	HumanoidSetup()
-- 	HoverboardUtils.BindJump(HoverboardJump)
-- 	Speed.RefreshSpeedGUI()
-- end

-- local function OnCharacterRemoving()
-- 	print("Character removed successfully!")
-- 	if runningConnection then
-- 		runningConnection:Disconnect()
-- 		runningConnection = nil
-- 	end
-- 	CleanupHoverboard()
-- 	ResetStates()
-- 	HoverboardUtils.UnBindJump()
-- 	Speed.Cleanup()
-- 	BoostAbility.CharRemoving()
-- 	DashAbility.CharRemoving()
-- end

-- local function OnPlayerAdded(plr)
-- 	if plr ~= player then
-- 		return
-- 	end
-- 	plr.CharacterAdded:Connect(OnCharacterAdded)
-- 	plr.CharacterRemoving:Connect(OnCharacterRemoving)
-- 	if plr.Character then
-- 		OnCharacterAdded(plr.Character)
-- 	end
-- end

-- --[[
--     Knit Lifecycle
-- ]]
-- --

-- function HoverboardController:KnitInit()
-- 	print("HoverboardController initialized")
-- end

-- function HoverboardController:KnitStart()
-- 	HoverboardService = Knit.GetService("HoverboardService")
-- 	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
-- 		if owner ~= player then
-- 			return
-- 		end
-- 		if isHoverboardInitialized then
-- 			print("Hoverboard: Hoverboard already initialized, ignoring spawn event")
-- 			return
-- 		end
-- 		HoverboardController:SetActiveConfig(boardName)
-- 	end)
-- 	HoverboardService.HoverboardRemoved:Connect(function()
-- 		ResetStates()
-- 		CleanupHoverboard()
-- 	end)
-- 	HoverboardService.ControlSignal:Connect(function(action)
-- 		local ctrl = GetControls()

-- 		if action == "Disable" then
-- 			ctrl:Disable()
-- 		elseif action == "Enable" then
-- 			ctrl:Enable()
-- 		end
-- 	end)
-- 	OnPlayerAdded(player)
-- 	BoostAbility.Init(player)
-- 	DashAbility.Init(player)
-- end

return HoverboardController
