local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local NewController = Knit.CreateController({ Name = "NewController" })

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local character
local humanoid
local Board
local rootPart
local bodyVelocity
local bodyGyro
local bodyPosition
local Camera = workspace.Camera
local Config

-- MODULES
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local HoverboardData = require(Configuration:WaitForChild("HoverboardData"))
local DashTrailModule = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("HoverboardVFX"):WaitForChild("ElectricDash")
local HoverboardService

-- MOVEMENT / HOVERING
local HoverStiffness = 5
local HoverHeight = 3

-- MOVEMENT / ORIENTATION
local OgBoardRotation
local ForwardLean = 0
local Rayvelocity = 0.2

-- Global variables for controller
local Normal
local PreviousMoveVector = Vector3.zero
local HorizontalTiltAngle = 0

-- CONSTANT VALUES
local ACCELERATION_FACTOR = 2 
local DECELERATION_FACTOR = .5
local ORIENTATION_FACTOR = 30
local MAX_HORIZONTAL_ROTATION = 15
local FOV_FACTOR = 1
local MAX_FORCE = 10000
local FLOATING_ERROR_MARGIN = 0.01
local JUMP_POWER = 70
local MAX_SPEED = 100
local ACCELERATION = 0.3
local DOWNHILL_SLOPE_ANGLE = 45

-- MOVEMENT / SPEED
local IsDecelerating = false
local Diff = 0.01
NewController.SpeedVar = 0
NewController.CurrentSpeed = 0
local acceleration
local topSpeed
local jumpPower

-- JUMP
local Jump = false
local LastJump = false
local CanJump = false
local spaceHeld = false
local WaitForLanding = true
local canDoubleJump = false
local hasDoubleJump = false
local hasFly = false
local MAX_AIR_JUMPS = 6
local AIR_JUMP_INTERVAL = 0.3
local AirJumps = 1
local JumpRequestTime = 0
local firstJumpTime = 0
local lastAirJumpTime = 0
local DOUBLE_JUMP_DELAY = 0.1
local JUMP_INTERVAL = 0.8 -- Time between jumps when space is held

-- FLY
local MAX_FLY_ENERGY = 1
local FLY_ENERGY_DEPLETION_RATE = 0.2 -- per second
local FLY_ENERGY_RECHARGE_TIME = 2
local FLY_ENERGY_RECHARGE_RATE = MAX_FLY_ENERGY / FLY_ENERGY_RECHARGE_TIME
local flyEnergy = MAX_FLY_ENERGY

-- GRAVITY
local hasGravityCoil = false
local DEFAULT_GRAVITY = workspace.Gravity
local gravityCoilModel = nil
local gravityCoilWeld = nil

-- CONNECTIONS
local runningConnection

-- State
local hoverboard
local runningConnection
local isHoverboardInitialized = false
local isBoosting = false
local boostReady = true
local isDashing = false
local dashReady = true
local isJumping = false
local isFalling = false

-- SPEED REFERENCES
local MAX_BARS = 10
local MAX_BAR_HEIGHT = 0.6
local MAX_BAR_WIDTH = 0.08
local BASE_TWEEN_DURATION = 1
local SMOOTHING_FACTOR = 0.18     -- how smooth the bar grows
local TWEEN_EASING = Enum.EasingStyle.Quad
local TWEEN_DIR = Enum.EasingDirection.Out
local MIN_FOV = 70
local MAX_FOV = 100

local speedBars = {}

-- Boost config
local BOOST_AMOUNT = 50
local BOOST_DURATION = 0.5
local BOOST_COOLDOWN = 3
local BOOSTED_ACCELERATION = 1
-- Dash config
local DASH_DISTANCE = 70
local DASH_DURATION = 0.25
local DASH_COOLDOWN = 3
local DASH_SPEED_MULTIPLIER = 3

-- UI References
local playerGUI = player:WaitForChild("PlayerGui")
local gameHUD = playerGUI:WaitForChild("GameHUD")
local mainGUI = playerGUI:WaitForChild("MainGui")
local speedGUI = gameHUD:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
--local energyLabel = speedGUI:WaitForChild("Energy")
local speedFrame = speedGUI:WaitForChild("Frame")

-- BOOST UI
local boostFrame = gameHUD:WaitForChild("BoostFrame")
local boostButton = boostFrame:WaitForChild("BoostButton")
local boostCooldownFiller = boostFrame:WaitForChild("CooldownFill")

-- FLASH UI
local flashFrame = gameHUD:WaitForChild("FlashFrame")
local flashButton = flashFrame:WaitForChild("FlashButton")
local flashCooldownFiller = flashFrame:WaitForChild("CooldownFill")

-- Gravity UI
local gravityFrame = gameHUD:WaitForChild("GravityCoil")
local gravityButton = gravityFrame:WaitForChild("GravityButton")

-- Double Jump UI
local doubleJumpFrame = gameHUD:WaitForChild("DoubleJumpFrame")
local doubleJumpButton = doubleJumpFrame:WaitForChild("DoubleJumpButton")

-- Fly UI
local flyFrame = gameHUD:WaitForChild("FlyFrame")
local flyButton = flyFrame:WaitForChild("FlyButton")

local controls
local RayParams

local function GetControls()
	if controls then
		return controls
	end
	local playerScripts = player:WaitForChild("PlayerScripts")
	controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
	return controls
end

local function InitBodyMovers()
	bodyVelocity = Instance.new("BodyVelocity")
	bodyGyro = Instance.new("BodyGyro")
	bodyPosition = Instance.new("BodyPosition")
	
	bodyPosition.MaxForce = Vector3.new(2e9, 2e9, 2e9)
	bodyPosition.Position = rootPart.Position

	bodyGyro.MaxTorque = Vector3.new(2e9, 2e9, 2e9)
	bodyGyro.Parent = Board

	bodyVelocity.MaxForce = Vector3.new(2e9, 0, 2e9)
	bodyVelocity.Parent = Board
end

local function CalculateJumpInterval(jumpPower)
	-- Scale linearly: interval = jumpPower / 70
	return jumpPower / 60
end

-- Add function to check if player is moving upward or downward
local function IsMovingDownward()
	if not rootPart or not Board then return false end
	local verticalVelocity = Board.AssemblyLinearVelocity.Y
	-- Negative Y velocity means moving downward (towards negative Y)
	return verticalVelocity < 20
end

------------------- UPDATE SPEED GUI -----------------------
local TWEEN_INFO = TweenInfo.new(
	BASE_TWEEN_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local function GetTweenInfo()
	local duration = BASE_TWEEN_DURATION * SMOOTHING_FACTOR
	return TweenInfo.new(duration, TWEEN_EASING, TWEEN_DIR)
end

local function LoadSpeedGUI()
	speedBars = {}
	for i = 1, MAX_BARS do
		local bar = bars:WaitForChild("Bar"..i)
		table.insert(speedBars, bar)
		bar.Visible = true
		bar.Size = UDim2.new(0, 0, MAX_BAR_HEIGHT, 0)
	end
end

local function AnimateFrame(frame, scale, visible)
	local tweenInfo = GetTweenInfo()
	TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(scale, 0, MAX_BAR_HEIGHT, 0)
	}):Play()
	frame.Visible = visible
end

function UpdateSpeedGUI(MaxSpeed)
	local value = bodyVelocity.Velocity.Magnitude or 0
	speedLabel.Text = string.format("Speed: %.0f", math.round(value))

	local xScale = 1
	if topSpeed then
		xScale = 1 - (value / topSpeed)
	end

	xScale = math.clamp(xScale, 0, 1)
	speedFrame.Size = UDim2.fromScale(xScale, speedFrame.Size.Y.Scale)
end
-----------------------------------------------------------

--------------------- BOOST MODULE ------------------------
local function RefreshBoostGUI()
	if boostCooldownFiller then
		boostCooldownFiller.Visible = false
		boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
	end
end

function ApplyBoost()
	if not humanoid then
		print("Humanoid: ", humanoid)
		return
	end
	if not boostReady then
		print("boostReady: ", boostReady)
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		print("humanoid.MoveDirection.Magnitude ", humanoid.MoveDirection.Magnitude)
		return
	end
	if not NewController.SpeedVar or NewController.SpeedVar < 20 then
		return
	end

	-- Activate boost
	boostReady = false
	isBoosting = true

	print("Boost activated")

	local originalAcceleration = acceleration
	local originalTopSpeed = topSpeed

	-- Boosted values
	local boostedSpeed = NewController.SpeedVar + BOOST_AMOUNT
	NewController.SpeedVar = boostedSpeed

	-- mutate refs
	acceleration = BOOSTED_ACCELERATION
	topSpeed = boostedSpeed

	if boostCooldownFiller then
		boostCooldownFiller.Visible = true
		-- start full progress and will shrink
		boostCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end

	-- End boost after duration: restore accel/top speed
	task.delay(BOOST_DURATION, function()
		isBoosting = false
		if acceleration then
			acceleration = originalAcceleration
		end
		if topSpeed then
			topSpeed = originalTopSpeed
		end
	end)

	-- Start cooldown UI / timer
	task.spawn(function()
		local step = 0.05
		local timeLeft = BOOST_COOLDOWN

		while timeLeft > 0 do
			-- update UI filler: shrink from 1->0 vertically
			if boostCooldownFiller then
				local frac = timeLeft / BOOST_COOLDOWN
				boostCooldownFiller.Size = UDim2.new(1, 0, frac, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		-- cooldown end
		boostReady = true
		if boostCooldownFiller then
			boostCooldownFiller.Visible = false
			boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
		end
	end)
end
-----------------------------------------------------------

--------------------- FLASH MODULE ------------------------
-- VFX: attach electric trails to player body parts
local BODY_PARTS = {
	"Head",
	"LeftFoot",
	"LeftHand",
	"LeftLowerArm",
	"LeftLowerLeg",
	"LeftUpperArm",
	"LeftUpperLeg",
	"LowerTorso",
	"RightFoot",
	"RightHand",
	"RightLowerArm",
	"RightLowerLeg",
	"RightUpperArm",
	"RightUpperLeg",
	"UpperTorso",
}

local function RefreshFlashGUI()
	if flashCooldownFiller then
		flashCooldownFiller.Visible = false
		flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
	end
end

local function CloneVFX()
	NewController._activeVFX = {}
	for _, partName in ipairs(BODY_PARTS) do
		local part = character:FindFirstChild(partName)
		if part then
			-- Clone the whole folder
			local fxFolder = DashTrailModule:Clone()
			fxFolder.Name = "ElectricDash_VFX_" .. partName

			-- Extract the objects BEFORE re-parenting
			local attach = fxFolder:FindFirstChild("ParticleAttachment")
			local particleEmitter = fxFolder:FindFirstChild("ParticleEmitter")

			if attach then
				attach.Parent = part
			end
			if particleEmitter then
				particleEmitter.Parent = part
				particleEmitter.Enabled = false
			end

			-- store the trails ONLY (they are what we toggle)
			table.insert(NewController._activeVFX, {
				ParticleEmitter = particleEmitter,
			})

			-- destroy the empty folder now
			fxFolder:Destroy()
		end
	end
end

local function EnableDashVFX(enable)
	for _, fx in ipairs(NewController._activeVFX or {}) do
		if fx.ParticleEmitter then
			print("VFX Enabled")
			fx.ParticleEmitter.Enabled = enable
		end
	end
end

local function DashVelocityMethod(hoverboard, moveDir, distance, duration)
	if not hoverboard or moveDir.Magnitude == 0 then
		return
	end

	local bodyVelocity = hoverboard:FindFirstChildOfClass("BodyVelocity")
	if not bodyVelocity then
		warn("Dash failed: BodyVelocity not found")
		return
	end

	-- preserve existing velocity state
	local startVel = bodyVelocity.Velocity
	local dashSpeed = distance / math.max(duration, 0.0001) * DASH_SPEED_MULTIPLIER
	local dashVelXZ = moveDir.Unit * dashSpeed

	local t = 0
	local holdT = duration

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not bodyVelocity or not conn then
			if conn then conn:Disconnect() end
			return
		end

		t = t + dt

		if t <= holdT then
			-- Dash controls ONLY XZ, preserves Y (hover/jump safe)
			bodyVelocity.Velocity = Vector3.new(
				dashVelXZ.X,
				bodyVelocity.Velocity.Y,
				dashVelXZ.Z
			)
		else
			-- Smooth restore to previous movement velocity
			local restoreDur = 0.2
			local alpha = math.min((t - holdT) / restoreDur, 1)

			bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(
				Vector3.new(startVel.X, bodyVelocity.Velocity.Y, startVel.Z),
				alpha
			)

			if alpha >= 1 then
				conn:Disconnect()
			end
		end
	end)
	
	
	
	
	
	
	
	--if not hoverboard or moveDir.Magnitude == 0 then
	--	print("Returned from here.")
	--	return
	--end
	--local primary = hoverboard
	--local startVel = primary.AssemblyLinearVelocity
	
	--local bodyVelocity = hoverboard:FindFirstChildOfClass("BodyVelocity")
	--local oldMaxForce
	--if bodyVelocity then
	--	oldMaxForce = bodyVelocity.MaxForce
	--	bodyVelocity.MaxForce = Vector3.zero
	--end

	---- compute dash velocity required to traverse distance in duration
	--local dashSpeed = distance / math.max(duration, 0.0001) * DASH_SPEED_MULTIPLIER
	--print("Dash speed: ", dashSpeed)
	--local dashVel = moveDir.Unit * dashSpeed
	--print("dashing vel: ", dashVel)

	---- apply: ramp assembly velocity towards dashVel, hold, then restore
	--local t = 0
	--local holdT = duration
	--local lastTime = tick()
	---- create a short run-service loop for reliable timing
	--local conn
	--conn = RunService.Heartbeat:Connect(function(dt)
	--	if not primary or not conn then
	--		if conn then
	--			conn:Disconnect()
	--		end
	--		return
	--	end
	--	t = t + dt
	--	print("dashing : T ", t)
	--	if t <= holdT then
	--		-- lerp current assembly velocity towards dashVel (fast)
	--		local cur = primary.AssemblyLinearVelocity
	--		local lerpT = 1 - math.exp(-60 * dt)
	--		local new = cur:Lerp(Vector3.new(dashVel.X, cur.Y, dashVel.Z), lerpT)
	--		print("dashing : New : ", new)
	--		primary.AssemblyLinearVelocity = new
	--	else
	--		-- restore: lerp back to startVel over 0.2s
	--		local restoreDur = 0.2
	--		local restoreT = math.min((t - holdT) / restoreDur, 1)
	--		local cur = primary.AssemblyLinearVelocity
	--		local target = Vector3.new(startVel.X, cur.Y, startVel.Z)
	--		local new = cur:Lerp(target, restoreT)
	--		print("dashing : New 2 : ", new)
	--		primary.AssemblyLinearVelocity = new

	--		if restoreT >= 1 then
	--			print("Disconnecting")
	--			if bodyVelocity then
	--				bodyVelocity.MaxForce = oldMaxForce or Vector3.new(2e9, 2e9, 2e9)
	--			end
	--			conn:Disconnect()
	--		end
	--	end
	--end)
end

function ApplyDash(currentSpeed, hoverboard)
	if not humanoid then
		warn("HoverboardDash: humanoid nil")
		return
	end
	if not dashReady then
		print("Dash not ready.")
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		print("Humanoid not moving")
		return
	end
	if not hoverboard then
		warn("HoverboardDash: invalid hoverboard")
		return
	end
	if currentSpeed < 20 then
		return
	end

	local bodyVelocity = hoverboard:FindFirstChildOfClass("BodyVelocity")
	if not bodyVelocity then
		warn("HoverboardDash: BodyVelocity missing")
		return
	end

	local vel = bodyVelocity.Velocity
	local moveDir = Vector3.new(vel.X, 0, vel.Z)

	if moveDir.Magnitude < 1 then
		-- Prevent dash when barely moving
		return
	end

	moveDir = moveDir.Unit

	print("Dash applied.")
	dashReady = false
	isDashing = true

	-- dash params
	local distance = math.max(DASH_DISTANCE, math.clamp(currentSpeed * 0.6, 8, 40))
	local duration = DASH_DURATION

	DashVelocityMethod(hoverboard, moveDir, distance, duration)
	--EnableDashVFX(true)

	if flashCooldownFiller then
		flashCooldownFiller.Visible = true
		flashCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end

	-- end dash
	task.delay(duration, function()
		isDashing = false
		EnableDashVFX(false)
	end)

	-- cooldown
	task.spawn(function()
		local step = 0.05
		local timeLeft = DASH_COOLDOWN

		while timeLeft > 0 do
			if flashCooldownFiller then
				local frac = timeLeft / DASH_COOLDOWN
				flashCooldownFiller.Size = UDim2.new(1, 0, frac, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		dashReady = true
		print("Dash ready")
	end)
	return true
end
-----------------------------------------------------------

----------------- GRAVITY METHODS -------------------------
function NewController:SetGravityCoil(enabled)
	hasGravityCoil = enabled
	print("Gravity coil enabled")
	if enabled then
		print("Gravity coil: enabled")
		-- Attach coil model to character's right arm
		self:AttachGravityCoilModel()
	else
		print("Gravity coil: disabled")
		-- Remove coil model
		self:RemoveGravityCoilModel()
		-- Reset gravity
		workspace.Gravity = DEFAULT_GRAVITY
	end
end

function NewController:AttachGravityCoilModel()
	-- Check if character exists
	if not character then
		warn("Cannot attach gravity coil: character not found")
		return
	end
	
	-- Find right arm
	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("RightArm")
	if not rightArm then
		warn("Cannot attach gravity coil: right arm not found")
		return
	end
	
	-- Remove existing coil if any
	self:RemoveGravityCoilModel()
	
	-- Find coil model in StarterPack
	local starterPack = player:WaitForChild("StarterPack")
	local coilTemplate = starterPack:FindFirstChild("Gravity coil")
	
	if not coilTemplate then
		warn("Gravity coil model not found in StarterPack")
		return
	end
	
	-- Clone and attach the model
	gravityCoilModel = coilTemplate:Clone()
	gravityCoilModel.Parent = workspace
	
	-- Position it on the right arm (adjust offset as needed)
	local offset = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)
	
	-- Create weld
	gravityCoilWeld = Instance.new("Weld")
	gravityCoilWeld.Name = "GravityCoilWeld"
	gravityCoilWeld.Part0 = rightArm
	gravityCoilWeld.Part1 = gravityCoilModel
	gravityCoilWeld.C0 = offset
	gravityCoilWeld.Parent = rightArm
	
	-- Parent to character
	gravityCoilModel.Parent = character
	
	print("Gravity coil model attached to character")
end

function NewController:RemoveGravityCoilModel()
	if gravityCoilModel then
		gravityCoilModel:Destroy()
		gravityCoilModel = nil
	end
	
	if gravityCoilWeld then
		gravityCoilWeld:Destroy()
		gravityCoilWeld = nil
	end
end

local function CheckGravityCoil()
	if hasGravityCoil and IsMovingDownward() then
		workspace.Gravity = DEFAULT_GRAVITY * 0.25
	else
		workspace.Gravity = DEFAULT_GRAVITY -- Always reset to default
	end
end
-----------------------------------------------------------

----------------- DOUBLE JUMP MODULE ----------------------
local function CanUseAirJump()
    if CanJump then return false end
    if hasFly and flyEnergy > 0 and AirJumps > 0 then return true end
    if hasDoubleJump and AirJumps > 0 then return true end
    return false
end


local function CheckForDoubleJump()
	if not hasDoubleJump then print("Has double jump returning") return false end
	if not canDoubleJump then print("Can double jump returning") return false end
	if CanJump then print("Can jump returning") return false end
	if AirJumps <= 0 then print("Air jumps returning") return false end
	if not spaceReleasedAfterJump then print("Space released returning") return false end
	if (tick() - firstJumpTime) < DOUBLE_JUMP_DELAY then print("Time returning") return false end
	
	return true
end

local function ExecuteDoubleJump(jumpPower)
	canDoubleJump = false  -- Use up the double jump
	AirJumps = 0
	spaceReleasedAfterJump = false  -- Reset for next time
	
	-- Apply double jump force
	bodyVelocity.MaxForce = Vector3.new(2e9, 2e9, 2e9)
	bodyVelocity.Velocity = Vector3.new(
		bodyVelocity.Velocity.X,
		jumpPower,
		bodyVelocity.Velocity.Z
	)
	
	isJumping = true
	isFalling = false
	LastJump = true
	WaitForLanding = true  -- Prevent immediate triple jumps
end
-----------------------------------------------------------

--------------------- FLY MODULE --------------------------
local function ExecuteAirJump(jumpPower)
	if AirJumps <= 0 then return end
	if flyEnergy <= 0 then return end
	print("Executing air jump.")
	AirJumps = AirJumps - 1
	flyEnergy = math.max(0, flyEnergy - FLY_ENERGY_DEPLETION_RATE)
	lastAirJumpTime = tick()
	LastJump = true
	
	--print("Executing air jump. Remaining jumps: ", AirJumps, " Remaining energy: ", flyEnergy)
	--energyLabel.Text = "Energy: " .. flyEnergy
	bodyVelocity.MaxForce = Vector3.new(2e9, 2e9, 2e9)
	bodyVelocity.Velocity = Vector3.new(
		bodyVelocity.Velocity.X,
		jumpPower * .75,
		bodyVelocity.Velocity.Z
	)
end
-----------------------------------------------------------


---------------- CONTROLLER METHODS -----------------------

local function ReturnAngleBetweenVectors(VectorA: Vector3, VectorB: Vector3): number

	if VectorA.Magnitude <= FLOATING_ERROR_MARGIN or VectorB.Magnitude <= FLOATING_ERROR_MARGIN then
		return 0
	end

	local dotProduct = VectorA:Dot(VectorB)
	local normalizedDotProduct = math.clamp( dotProduct / (VectorA.Magnitude * VectorB.Magnitude), -1, 1)

	return math.deg(math.acos(normalizedDotProduct))
end

local function ReturnDirectionAndTiltAngle(ReferenceVector: Vector3, OtherVector: Vector3, NormalVector: Vector3 ?)
	NormalVector = NormalVector or Vector3.yAxis

	if ReferenceVector.Magnitude == 0 or OtherVector.Magnitude == 0 then
		return 1, 0
	end

	local crossProduct = ReferenceVector:Cross(OtherVector)
	local direction = crossProduct:Dot(NormalVector) >= 0 and 1 or -1

	ReferenceVector *= Vector3.new(1, 0, 1)
	OtherVector = OtherVector * Vector3.new(1, 0, 1)

	local dotProduct = ReferenceVector:Dot(OtherVector)
	local normalizedDotProduct = math.clamp( dotProduct / (ReferenceVector.Magnitude * OtherVector.Magnitude), -1, 1)



	local angle = math.deg(math.acos(normalizedDotProduct))
	-- warn(dotProduct, "|", normalizedDotProduct, "|", angle)

	return direction, angle
end

local function ExponentialDecay(InitialValue : number, FinalValue : number, DecayRate : number, TimeDelta : number)
	return FinalValue + (InitialValue - FinalValue) * math.exp(-DecayRate * TimeDelta)
end

local function HandleJump(jumpPower, dt)
	local currentInterval = CalculateJumpInterval(jumpPower)

	if spaceHeld and hasFly and not CanJump and AirJumps > 0 then
		if (tick() - lastAirJumpTime) >= AIR_JUMP_INTERVAL then
			ExecuteAirJump(jumpPower)
		end
	end
	if spaceHeld then
		print("Running")
		local currentTime = tick()
		if CanJump and not WaitForLanding and (currentTime - JumpRequestTime >= JUMP_INTERVAL) then
			Jump = true
			WaitForLanding = true
			canDoubleJump = true
			JumpRequestTime = currentTime
		end
	end

	if Jump then
		Jump = false
		LastJump = true
		isJumping = true
		isFalling = false
		firstJumpTime = tick()
		bodyVelocity.MaxForce = Vector3.new(2e9, 2e9, 2e9)
		bodyVelocity.Velocity = Vector3.new(
			bodyVelocity.Velocity.X,
			jumpPower,
			bodyVelocity.Velocity.Z
		)
	end
end

local function Hover(DeltaTime, JumpPower)
	if isDashing then return end
	
	local Origin = Board.Position
	local Direction = Vector3.new(0, -1, 0)
	local CheckingDistance = HoverHeight + 4
	local PotentialMap = workspace:FindFirstChild("CurrentMap")

	local RaycastResult = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)

	local SwaySpeed = 2.5
	local MaxSwayHeight = 0.1
	local HeightSway = math.sin(tick() * SwaySpeed) * MaxSwayHeight
	local Normal

	HandleJump(JumpPower, DeltaTime)
	CheckGravityCoil()

	if RaycastResult then
		CanJump = true
		WaitForLanding = false
		canDoubleJump = true

		if not spaceHeld then
			flyEnergy = flyEnergy + FLY_ENERGY_RECHARGE_RATE
			flyEnergy = math.clamp(flyEnergy, 0, MAX_FLY_ENERGY)
			--energyLabel.Text = "Energy: " .. flyEnergy
		end
		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
			local HoverPosition = RaycastResult.Position + Vector3.new(0, HoverHeight + HeightSway, 0)
			local VelocityY = ((HoverPosition - rootPart.Position).Y + HoverHeight) * HoverStiffness
			Normal = RaycastResult.Normal

			local BoardCF = Board.CFrame * CFrame.Angles(math.rad(-ForwardLean), 0, 0)
			local yoffset = (BoardCF.LookVector * NewController.SpeedVar * Vector3.new(0, 1, 0)).Y

			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, ExponentialDecay(Board.AssemblyLinearVelocity.Y, VelocityY + yoffset, 20, DeltaTime), bodyVelocity.Velocity.Z)
		end

		if not Jump then
			if hasFly then
				AirJumps = MAX_AIR_JUMPS
			elseif hasDoubleJump then
				AirJumps = 1
			else
				AirJumps = 0
			end
		end

	else
		CanJump = false
		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, 0, MAX_FORCE)
			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, -HoverHeight, bodyVelocity.Velocity.Z)
		end
		LastJump = false
	end
end
-----------------------------------------------------------

----------------- MOVEMENT METHODS ------------------------
function CalculateMoveDirection()
	local controls = GetControls()
	local inputVector = controls:GetMoveVector()

	-- translate input vector with respect to camera
	-- this will give the world vector to apply force on player
	local cameraCFrame = Camera.CFrame
	local cameraLookVector = cameraCFrame.LookVector
	local cameraRightVector = cameraCFrame.RightVector

	local factor = 1000

	local goal
	if inputVector.Magnitude > 0 then
		local goalCFrame = Camera.CFrame * CFrame.new(inputVector.X * factor, 0, inputVector.Z * factor)
		local goalMoveVector = (goalCFrame.Position - Camera.CFrame.Position)

		NewController.MoveVector = (goalMoveVector * Vector3.new(1, 0, 1)).Unit
	else
		NewController.MoveVector = Vector3.zero
	end
end

function Lerp(Start, Target, Alpha) :number
	return Start + (Target - Start) * Alpha
end

function CalculateSpeed(acceleration, topSpeed, deltaTimeRender)
	local newTargetSpeed = NewController.MoveVector.Magnitude == 0 and 0 or topSpeed

	if NewController.CurrentSpeed ~= newTargetSpeed then
		IsDecelerating = newTargetSpeed == 0
	end


	-- acceleration = IsDecelerating and .000001 or acceleration
	-- local factor = IsDecelerating and .000001 or 2
	-- warn(acceleration)
	NewController.CurrentSpeed = newTargetSpeed

	-- if IsDecelerating then
	-- 	NewController.SpeedVar = math.max(0, NewController.SpeedVar - (0 * deltaTimeRender))
	-- 	-- warn("V", NewController.SpeedVar)
	-- else
	-- 	-- warn("^")
	-- 	NewController.SpeedVar = Lerp(NewController.SpeedVar, NewController.CurrentSpeed, acceleration * deltaTimeRender * 2)
	-- end
end

function ReturnDownhillVector(SurfaceNormal: Vector3?): Vector3
	if SurfaceNormal then
		local horizontalVector = SurfaceNormal:Cross(Vector3.yAxis)
		local downhillVector = SurfaceNormal:Cross(horizontalVector)

		if downhillVector.Magnitude >= FLOATING_ERROR_MARGIN then
			return downhillVector.Unit
		end
	end

	return Vector3.zero
end

function ApplyVelocity(jumpPower, deltaTimeRender)
	local Origin = Board.Position
	local Direction = Vector3.new(0, -1, 0)
	local CheckingDistance = HoverHeight + 4
	local Size = Board.Size.Z / 2
	
	local frontRaycast: RaycastResult = workspace:Raycast(Origin + Board.CFrame.LookVector * 3.5, Direction * CheckingDistance, RayParams)
	local middleRaycast: RaycastResult  = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)
	local backRaycast: RaycastResult = workspace:Raycast(Origin - Board.CFrame.LookVector * 3.5, Direction * CheckingDistance, RayParams)
	
	local RaycastResult = middleRaycast

	if frontRaycast and (not RaycastResult or frontRaycast.Distance < RaycastResult.Distance) then
		RaycastResult = frontRaycast
	end

	if backRaycast and (not RaycastResult or backRaycast.Distance < RaycastResult.Distance) then
		RaycastResult = backRaycast
	end


	local SwaySpeed = 2.5
	local MaxSwayHeight = 0.1
	local HeightSway = math.sin(tick() * SwaySpeed) * MaxSwayHeight

	HandleJump(jumpPower, deltaTimeRender)
	CheckGravityCoil()

	local yVelocityComponent = 0

	if RaycastResult then
		CanJump = true
		WaitForLanding = false
		canDoubleJump = true

		if not spaceHeld then
			flyEnergy = flyEnergy + FLY_ENERGY_RECHARGE_RATE
			flyEnergy = math.clamp(flyEnergy, 0, MAX_FLY_ENERGY)
		end

		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
			local HoverPosition = RaycastResult.Position + Vector3.new(0, HoverHeight + HeightSway, 0)
			local VelocityY = ((HoverPosition - rootPart.Position).Y + HoverHeight) * HoverStiffness
			Normal = RaycastResult.Normal

			local BoardCF = Board.CFrame * CFrame.Angles(math.rad(-ForwardLean), 0, 0)
			local yoffset = (BoardCF.LookVector * NewController.SpeedVar * Vector3.new(0, 1, 0)).Y

			yVelocityComponent = ExponentialDecay(Board.AssemblyLinearVelocity.Y, VelocityY + yoffset, 20, deltaTimeRender)
			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, ExponentialDecay(Board.AssemblyLinearVelocity.Y, VelocityY + yoffset, 20, deltaTimeRender), bodyVelocity.Velocity.Z)
		end

		if not Jump then
			if hasFly then
				AirJumps = MAX_AIR_JUMPS
			elseif hasDoubleJump then
				AirJumps = 1
			else
				AirJumps = 0
			end
		end

	else
		CanJump = false
		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, 0, MAX_FORCE)
			yVelocityComponent = -HoverHeight
			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, -HoverHeight, bodyVelocity.Velocity.Z)
		end
		LastJump = false
	end

	local velocityFactor = ACCELERATION_FACTOR
	if IsDecelerating then
		velocityFactor = CanJump and ACCELERATION_FACTOR * 2 or DECELERATION_FACTOR
	end
	
	local downhillVector = Vector3.zero
	local downhillAngle = 0

	if RaycastResult then
		downhillVector = ReturnDownhillVector(RaycastResult.Normal)
		downhillAngle = ReturnAngleBetweenVectors(RaycastResult.Normal, Vector3.yAxis)
	end

	downhillAngle = math.clamp(math.abs(downhillAngle), 0, 45)

	local finalVelocity = Vector3.new(NewController.MoveVector.X * NewController.CurrentSpeed, yVelocityComponent, NewController.MoveVector.Z * NewController.CurrentSpeed) + downhillVector * (workspace.Gravity / 10) * (downhillAngle / DOWNHILL_SLOPE_ANGLE)
	local direction, tiltAngle = ReturnDirectionAndTiltAngle(finalVelocity * Vector3.new(1, 0, 1), bodyVelocity.Velocity * Vector3.new(1, 0, 1))
	HorizontalTiltAngle = - direction * tiltAngle
	bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(finalVelocity, deltaTimeRender * velocityFactor)
end

function ApplyOrientation(deltaTimeRender)
	local BoardCF = Board.CFrame
	local Origin = Board.Position + BoardCF.LookVector + Board.AssemblyLinearVelocity * Rayvelocity
	local Direction = Vector3.new(0, -1, 0)
	local CheckingDistance = HoverHeight + 4

	local SwaySpeed = 0 --2
	local MaxSwayAngle = 0 --1.5
	local TiltAngle = math.sin(tick() * SwaySpeed) * MaxSwayAngle
	local newNormal
	local LerpFactor = 0.8

	if NewController.MoveVector then

		local RaycastResult = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)

		if ForwardLean ~= 0 then
			TiltAngle = ForwardLean
		end

		if RaycastResult then
			newNormal = RaycastResult.Normal
		else
			newNormal = Vector3.yAxis
		end

		if newNormal then
			local velocity = bodyVelocity.Velocity * Vector3.new(1, 0, 1)
			local LookVector = rootPart.CFrame.LookVector

			if velocity.Magnitude >= FLOATING_ERROR_MARGIN then
				LookVector = velocity.Unit
			end

			local RightVector = LookVector:Cross(newNormal).Unit
			local UpVector = newNormal
			local AlignedCFrame = CFrame.fromMatrix(rootPart.Position, RightVector, UpVector) 
			
			local normalizedTilt = math.clamp(HorizontalTiltAngle, -MAX_HORIZONTAL_ROTATION, MAX_HORIZONTAL_ROTATION)

			bodyGyro.CFrame = bodyGyro.CFrame:Lerp(AlignedCFrame * CFrame.Angles(0, 0, math.rad(normalizedTilt)), deltaTimeRender * ORIENTATION_FACTOR)
			-- bodyGyro.CFrame = bodyGyro.CFrame:Lerp(AlignedCFrame, deltaTimeRender * ORIENTATION_FACTOR)
		end

	end
end

function UpdateFOV(topSpeed, deltaTimeRender)
	local diff = MAX_FOV - MIN_FOV
	-- Camera.FieldOfView = Lerp(Camera.FieldOfView, math.clamp(MIN_FOV + diff * (bodyVelocity.Velocity.Magnitude / topSpeed), MIN_FOV, MAX_FOV), .5)
	Camera.FieldOfView = Lerp(Camera.FieldOfView, math.clamp(MIN_FOV + diff * (bodyVelocity.Velocity.Magnitude / topSpeed), MIN_FOV, MAX_FOV), deltaTimeRender * FOV_FACTOR)
end
-----------------------------------------------------------

-- PLAYER LIFECYCLE

local function ResetStates()
	print("Reset states called")
	character = nil
	humanoid = nil
	rootPart = nil
	Board = nil
	bodyVelocity = nil
	bodyGyro = nil
	bodyPosition = nil
	controls = nil
	OgBoardRotation = 0
	BoardRotation = 0
	SmoothBoardRotation = 0
	acceleration = 0
	topSpeed = 0
	jumpPower = 0
	ForwardLean = 0
	NewController.SpeedVar = 0
	NewController.CurrentSpeed = 0
	AirJumps = 1
	flyEnergy = MAX_FLY_ENERGY
	Jump = false
	LastJump = false
	CanJump = false
	isHoverboardInitialized = false
	isOnHoverboard = false
	CameraHeld = false
	boostReady = true
	dashReady = true
	isDashing = false
	spaceHeld = false
	hasGravityCoil = false
	hasDoubleJump = false
	hasFly = false
	JumpRequestTime = 0
	JUMP_INTERVAL = 0.8
	NewController:SetGravityCoil(false)
	workspace.Gravity = DEFAULT_GRAVITY
end

local function InputListeners(HoverboardService, JumpPower)
	UserInputService.InputBegan:Connect(function(Input : InputObject, gameProcessedEvent)
		if gameProcessedEvent then return end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Space then
				
			end
			if Input.KeyCode == Enum.KeyCode.Q then
				print("Hoverboard: Boost requested.")
				ApplyBoost(acceleration, topSpeed)
			end
			if Input.KeyCode == Enum.KeyCode.F then
				print("Hoverboard: Flash requested.")
				ApplyDash(NewController.SpeedVar, Board)
			end
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton2 or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			CameraHeld = true
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		spaceHeld = true
		JumpRequestTime = tick()
		WaitForLanding = false

		-- GROUND JUMP
		if CanJump then
			Jump = true
			LastJump = true
			return
		end

    	-- AIR JUMPS (ONLY if module exists)
		if CanUseAirJump() then
			if hasFly then
				ExecuteAirJump(jumpPower)
			else
				ExecuteDoubleJump(jumpPower)
			end
		end

		-- if CanJump then
		-- 	Jump = true
		-- elseif hasFly and flyEnergy > 0 then
			
		-- end

		-- if CheckForDoubleJump() and not hasFly then
		-- 	ExecuteDoubleJump(JumpPower)
		-- elseif hasFly and flyEnergy > 0 and AirJumps > 1 then
		-- 	print("Here")
		-- 	ExecuteAirJump(JumpPower)
		-- else
		-- 	Jump = true
		-- end
		-- if not LastJump then
		-- 	AirJumps -= 1
		-- end
	end)
	UserInputService.InputEnded:Connect(function(Input : InputObject, GameProcessed : boolean)
		if GameProcessed then return end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Space then
				spaceHeld = false
				isFlying = false
				spaceReleasedAfterJump = true
			end
		end

		if Input.UserInputType == Enum.UserInputType.MouseButton2 and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			CameraHeld = false
		end
	end)

	boostButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Boost requested.")
		ApplyBoost(acceleration, topSpeed)
	end)
	flashButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Flash requested.")
		ApplyDash(NewController.SpeedVar, Board)
	end)
	gravityButton.MouseButton1Click:Connect(function()
		print("Hovrboard: Gravity Coil requested.")
		hasGravityCoil = true
		--HoverboardService:RequestGravityCoil()
	end)
	doubleJumpButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Double Jump requested.")
		hasDoubleJump = true
	end)
	flyButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Fly requested.")
		hasFly = true
	end)
end

function NewController:DisableAnimations(char)
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
end

function NewController:HumanoidSetup()
	humanoid.MaxSlopeAngle = 0
	humanoid.AutoRotate = true
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 70
end

function NewController:SetActiveConfig(boardName)
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
	isOnHoverboard = true
	isHoverboardInitialized = true
	self:StartHoverboard(config, HoverboardService)
end

function NewController:StartHoverboard(config, HoverboardService)
	print("StartHoverboard called")
	if runningConnection then
		runningConnection:Disconnect()
	end
	
	acceleration = config.Acceleration or ACCELERATION
	topSpeed = config.TopSpeed or MAX_SPEED
	jumpPower = config.JumpPower or JUMP_POWER
	
	-- LoadSpeedGUI()
	RefreshBoostGUI()
	RefreshFlashGUI()
	CloneVFX()
	InputListeners(HoverboardService, jumpPower)

	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)
	runningConnection = RunService.PreRender:Connect(function(dt)
		CalculateMoveDirection()
		CalculateSpeed(acceleration, topSpeed, dt)
		ApplyVelocity(jumpPower, dt)
		ApplyOrientation(dt)
		UpdateFOV(topSpeed, dt)


		-- Hover(dt, jumpPower)
		-- SetSpeed(dt, acceleration, topSpeed)
		-- ManageMoveDirection(dt, topSpeed)
		-- cameraFOV.Update(dt, humanoid, isBoosting, isDashing, isJumping, isFalling, jumpPower)
		
		if speedGUI and speedLabel and speedFrame then
			UpdateSpeedGUI(topSpeed)
		end
	end)
end

function OnCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	rootPart = char:WaitForChild("HumanoidRootPart")
	
	-- Wait for board
	local hb = char:WaitForChild("Hoverboard")
	Board = hb:WaitForChild("PrimaryPart")
	InitBodyMovers()
	
	OgBoardRotation = Board.CFrame.Rotation.Y
	BoardRotation = OgBoardRotation
	SmoothBoardRotation = OgBoardRotation
end

local function OnCharacterRemoving()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	ResetStates()
end

local function OnPlayerAdded(plr)
	if plr ~= player then
		return
	end
	plr.CharacterAdded:Connect(function() 
		OnCharacterAdded(plr.Character)
	end)
	plr.CharacterRemoving:Connect(OnCharacterRemoving)
	if plr.Character then
		OnCharacterAdded(plr.Character)
	end
end

function NewController:KnitStart()
	print("NewController started")
	OnPlayerAdded(player)
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner ~= player then
			return
		end
		if isHoverboardInitialized then
			print("Hoverboard: Hoverboard already initialized, ignoring spawn event")
			return
		end
		NewController:SetActiveConfig(boardName)
	end)
	HoverboardService.HoverboardRemoved:Connect(function()
		ResetStates()
	end)
	HoverboardService.ControlSignal:Connect(function(action)
		local ctrl = GetControls()

		if action == "Disable" then
			ctrl:Disable()
		elseif action == "Enable" then
			ctrl:Enable()
		end
	end)
end

return NewController