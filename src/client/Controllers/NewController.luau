local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local NewController = Knit.CreateController({ Name = "NewController" })

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local player = Players.LocalPlayer
local character
local humanoid
local Board
local Trail
local rootPart
local bodyVelocity
local bodyGyro
local Camera = workspace.Camera
local Config

-- MODULES
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local HoverboardData = require(Configuration:WaitForChild("HoverboardData"))
local TrailsConfig = require(Configuration:WaitForChild("TrailsConfig"))
local DashTrailModule = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("HoverboardVFX"):WaitForChild("ElectricDash")
local HoverboardService

-- MOVEMENT / HOVERING
local HoverStiffness = 10
local HoverHeight = 0

-- MOVEMENT / ORIENTATION
local ForwardLean = 0
local Rayvelocity = 0.2
local RayDistance = 5
local HorizontalTiltAngle = 0

-- CONSTANT VALUES
local DECELERATION_FACTOR = 0.5
local ORIENTATION_FACTOR = 10
local MAX_HORIZONTAL_ROTATION = 10
local FOV_FACTOR = 1
local FLOATING_ERROR_MARGIN = 0.01
local JUMP_POWER = 70
local MAX_SPEED = 100
local ACCELERATION = 0.3
local DOWNHILL_SLOPE_ANGLE = 45
local RAY_PREFERENCE_DISTANCE = 2
local MIN_FOV = 70
local MAX_FOV = 100

-- MOVEMENT / SPEED
local IsDecelerating = false
local IsBraking = true
local Diff = 0.01
NewController.SpeedVar = 0
NewController.CurrentSpeed = 0
local acceleration
local topSpeed
local jumpPower

-- JUMP
local CanJump = false
local spaceHeld = false
local jumpConsumed = false
local jumpReady = false
local jumpQueued = false
local hasDoubleJump = false
local hasFly = false

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
local isBraking = false
local flipping = false
local flipAngle = 0

-- Boost config
local BOOST_DURATION = 1
local BOOST_AMOUNT = 2.5
local BOOST_COOLDOWN = 3

-- Dash config
local DASH_DURATION = 0.25
local DASH_DISTANCE = 50
local DASH_AMOUNT = 4000
local DASH_COOLDOWN = 3

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
local wallDetected

local motor
local BASE_C0
local BASE_C1
local FLIP_DURATION = 0.45          -- seconds
local FLIP_ANGLE = math.pi * 2      -- 360°
local FLIP_SPEED = FLIP_ANGLE / FLIP_DURATION



local function GetControls()
	if controls then
		return controls
	end
	local playerScripts = player:WaitForChild("PlayerScripts")
	controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
	return controls
end

local function InitBodyMovers()
	bodyVelocity = Board:WaitForChild("BodyVelocity")
	bodyGyro = Board:WaitForChild("BodyGyro")
	
	--bodyVelocity = rootPart:WaitForChild("BodyVelocity")
	--bodyGyro = rootPart:WaitForChild("BodyGyro")
end

local function CalculateJumpInterval(jumpPower)
	-- Scale linearly: interval = jumpPower / 70
	return jumpPower / 60
end

-- Add function to check if player is moving upward or downward
local function IsMovingDownward()
	if not rootPart or not Board then
		return false
	end

	--local verticalVelocity = rootPart.AssemblyLinearVelocity.Y 	--Added
	local verticalVelocity = Board.AssemblyLinearVelocity.Y
	-- Negative Y velocity means moving downward (towards negative Y)
	return verticalVelocity < 20
end

function WallDetection(dt)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = { character, Board }

	-- Use board velocity direction (NOT look vector)
	local velocity = Board.AssemblyLinearVelocity
	local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z)

	if horizontalVel.Magnitude < 0.1 then
		return
	end

	local moveDir = horizontalVel.Unit

	-- Ray origin: front of the board (covers whole board width implicitly)
	local halfSize = Board.Size.Z * 0.5
	local origin = Board.Position + moveDir * halfSize

	-- Dynamic ray length (prevents tunneling)
	local rayLength = math.max(1, horizontalVel.Magnitude * dt + 1)
	local direction = moveDir * rayLength

	local hit = workspace:Raycast(origin, direction, rayParams)
	if not hit then return end

	-- Wall normal (flattened to horizontal)
	local wallNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	if wallNormal.Magnitude < 0.01 then return end
	wallNormal = wallNormal.Unit

	-- Check if actually moving INTO the wall
	local intoWall = horizontalVel:Dot(wallNormal)
	if intoWall >= 0 then return end

	----------------------------------------------------------------
	-- SMOOTH SLIDE: project velocity onto wall plane
	----------------------------------------------------------------
	local slideVel = horizontalVel - wallNormal * intoWall

	-- Preserve vertical velocity (hover / gravity)
	local finalVelocity = Vector3.new(
		slideVel.X * 0,
		velocity.Y,
		slideVel.Z * 0
	)

	-- Smooth application (no snapping)
	local SMOOTHNESS = 0.15
	bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(finalVelocity, SMOOTHNESS)























	-- local rayParams = RaycastParams.new()
	-- rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- rayParams.IgnoreWater = true
	-- rayParams.FilterDescendantsInstances = { character, Board }

	-- local lookDir = rootPart.CFrame.LookVector
	-- local speed = Board.AssemblyLinearVelocity.Magnitude
	-- --local speed = bodyVelocity.Velocity.Magnitude

	-- -- Dynamic ray length (prevents tunneling)
	-- local rayLength = math.max(5, speed * deltaTimeRender + 1)

	-- local origin = rootPart.Position
	-- local direction = lookDir * rayLength

	-- local hit = workspace:Raycast(origin, direction, rayParams)

	-- if hit then
	-- 	print("Wall detected!")
	-- 	local normal = hit.Normal
	-- 	local currentVel = Board.AssemblyLinearVelocity
	-- 	--local currentVel = bodyVelocity.Velocity

	-- 	-- Slide with the wall
	-- 	local intoWall = currentVel:Dot(normal)
	-- 	local slideVelocity = currentVel - normal * intoWall
	-- 	--local maxSlideSpeed = currentVel.Magnitude
	-- 	--slideVelocity = slideVelocity.Unit * math.min(slideVelocity.Magnitude, maxSlideSpeed)
	-- 	if intoWall < 0 then
	-- 		--Board.AssemblyLinearVelocity = Vector3.new(slideVelocity.X * 0, currentVel.Y, slideVelocity.Z * 0)
	-- 		bodyVelocity.Velocity = Vector3.new(slideVelocity.X * 0.95, 0, slideVelocity.Z * 0.95)
	-- 	end
	-- 	return
	-- end
end

------------------- UPDATE SPEED GUI -----------------------
function UpdateSpeedGUI(MaxSpeed)
	--local value = (bodyVelocity.Velocity * Vector3.new(1, 0, 1)).Magnitude or 0
	local value = (Board.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude or 0
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

function ApplyBoost(boostDuration, boostAmount)
	if not humanoid or not Board or not bodyVelocity then
		return
	end
	if not boostReady or isBoosting then
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end

	-- Current horizontal speed
	local currentVel = bodyVelocity.Velocity
	local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)

	if horizontalVel.Magnitude < 20 then
		return
	end

	boostButton.Interactable = false
	boostReady = false
	isBoosting = true

	local boostDir = horizontalVel.Magnitude > 0 and horizontalVel.Unit or humanoid.MoveDirection
	local boostStartTime = tick()
	local boostEndTime = boostStartTime + boostDuration

	local boostConnection
	boostConnection = RunService.Heartbeat:Connect(function(dt)
		if not Board or not isBoosting then
			if boostConnection then
				boostConnection:Disconnect()
			end
			return
		end

		if tick() >= boostEndTime then
			isBoosting = false
			boostConnection:Disconnect()

			-- Clamp back to topSpeed after boost ends
			local v = bodyVelocity.Velocity
			local flat = Vector3.new(v.X, 0, v.Z)

			if flat.Magnitude > topSpeed then
				local clamped = flat.Unit * topSpeed
				bodyVelocity.Velocity = Vector3.new(clamped.X, v.Y, clamped.Z)
			end
			return
		end

		-- Inject boost velocity (preserve Y)
		bodyVelocity.Velocity = bodyVelocity.Velocity
			+ Vector3.new(boostDir.X * boostAmount * dt * 60, 0, boostDir.Z * boostAmount * dt * 60)
	end)

	-- Cooldown
	if boostCooldownFiller then
		boostCooldownFiller.Visible = true
		boostCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end
	task.spawn(function()
		local step = 0.05
		local timeLeft = BOOST_COOLDOWN

		while timeLeft > 0 do
			if boostCooldownFiller then
				boostCooldownFiller.Size = UDim2.new(1, 0, timeLeft / BOOST_COOLDOWN, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		boostReady = true
		if boostCooldownFiller then
			boostCooldownFiller.Visible = false
			boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
		end
		boostButton.Interactable = true
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

local function EnableFlashVFX(enable)
	for _, fx in ipairs(NewController._activeVFX or {}) do
		if fx.ParticleEmitter then
			print("VFX Enabled")
			fx.ParticleEmitter.Enabled = enable
		end
	end
end

local function SetCollisionGroup(model, groupName)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.CollisionGroup = groupName
		end
	end
end

local function MakePlayerInvincible(state)
	character:SetAttribute("Invincible", state)
	local groupName = state and "PlayerInvincible" or "Player"

	SetCollisionGroup(character, groupName)
	if Board and Board.Parent then
		SetCollisionGroup(Board.Parent, groupName)
	end
end

function ApplyDash(dashAmount, dashDuration, dashDistance)
	if not humanoid or not Board or not bodyVelocity then
		return
	end

	if not dashReady or isDashing then
		return
	end

	if humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end

	-- Store the current direction BEFORE applying dash
	local currentVel = Board.AssemblyLinearVelocity
	local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)

	-- CRITICAL: Store dash direction ONCE at the start
	local initialDashDir = humanoid.MoveDirection --or horizontalVel.Magnitude > 0 and horizontalVel.Unit
	initialDashDir = Vector3.new(initialDashDir.X, 0, initialDashDir.Z).Unit

	if horizontalVel.Magnitude < 20 then
		print("Not enough speed.")
		return
	end

	print("Dash applied.")
	dashReady = false
	isDashing = true
	flashButton.Interactable = false
	EnableFlashVFX(true)

	-- Calculate required speed for distance-based dash
	local requiredSpeed = dashDistance / dashDuration
	local dashStartTime = tick()
	local dashEndTime = dashStartTime + dashDuration

	local originalTopSpeed = topSpeed
	local lockedDashDir = initialDashDir

	-- Disable humanoid control during dash (optional but recommended)
	local wasAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local dashConnection
	dashConnection = RunService.Heartbeat:Connect(function(dt)
		if not Board or not isDashing then
			if dashConnection then
				dashConnection:Disconnect()
			end
			-- Restore humanoid control
			humanoid.AutoRotate = wasAutoRotate
			MakePlayerInvincible(false)
			EnableFlashVFX(false)
			return
		end

		local currentTime = tick()
		local elapsed = currentTime - dashStartTime

		--Stop dash after duration
		if currentTime >= dashEndTime then
			isDashing = false
			MakePlayerInvincible(false)
			EnableFlashVFX(false)

			-- Restore original settings
			topSpeed = originalTopSpeed
			humanoid.AutoRotate = wasAutoRotate

			-- Apply post-dash velocity (keep momentum but prevent excessive speed)
			local v = Board.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)

			-- Calculate velocity decay
			local currentSpeed = flat.Magnitude

			if currentSpeed > originalTopSpeed then
				-- Smooth deceleration to normal speed
				local deceleration = (currentSpeed - originalTopSpeed) * 0.8
				local newSpeed = math.max(currentSpeed - deceleration * dt, originalTopSpeed)
				local newVel = flat.Unit * newSpeed
				Board.AssemblyLinearVelocity = Vector3.new(newVel.X, v.Y, newVel.Z)
			end

			if dashConnection then
				dashConnection:Disconnect()
			end

			return
		end
		-- Make the player invicible
		MakePlayerInvincible(true)
		local progress = elapsed / dashDuration

		-- Apply easing for better feel (ease-out quad)
		local easeFactor = 1 - (1 - progress) * (1 - progress)
		local currentDashSpeed = requiredSpeed * (0.9 + 0.2 * easeFactor)

		local vel = Board.AssemblyLinearVelocity
		Board.AssemblyLinearVelocity = Vector3.new(
			lockedDashDir.X * currentDashSpeed, -- Always use locked direction
			vel.Y, -- Preserve vertical velocity
			lockedDashDir.Z * currentDashSpeed -- Always use locked direction
		)
	end)

	-- Cooldown management
	if flashCooldownFiller then
		flashCooldownFiller.Visible = true
		flashCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end
	task.spawn(function()
		local step = 0.05
		local timeLeft = DASH_COOLDOWN

		while timeLeft > 0 do
			if flashCooldownFiller then
				local progress = 1 - (timeLeft / DASH_COOLDOWN)
				local sizeProgress = progress * progress
				flashCooldownFiller.Size = UDim2.new(1, 0, 1 - sizeProgress, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		dashReady = true
		if flashCooldownFiller then
			flashCooldownFiller.Visible = false
			flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
		end
		flashButton.Interactable = true
	end)
end

function Dash(dashPower)
	if not Board or not humanoid then
		return
	end

	-- Cooldown / state checks
	if not dashReady or isDashing then
		return
	end

	local velocity = bodyVelocity.Velocity	--Board.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

	if horizontal.Magnitude < 0.1 then
		return
	end

	-- ===== DASH START =====
	dashReady = false
	isDashing = true
	flashButton.Interactable = false
	EnableFlashVFX(true)
	MakePlayerInvincible(true)

	-- APPLY DASH
	local dashDir = horizontal.Unit
	Board:ApplyImpulse(dashDir * dashPower)

	task.delay(DASH_DURATION, function()
		isDashing = false
		MakePlayerInvincible(false)
		EnableFlashVFX(false)
	end)

	-- ===== COOLDOWN UI (same as ApplyDash) =====
	if flashCooldownFiller then
		flashCooldownFiller.Visible = true
		flashCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end

	task.spawn(function()
		local step = 0.05
		local timeLeft = DASH_COOLDOWN

		while timeLeft > 0 do
			if flashCooldownFiller then
				local progress = 1 - (timeLeft / DASH_COOLDOWN)
				local sizeProgress = progress * progress
				flashCooldownFiller.Size = UDim2.new(1, 0, 1 - sizeProgress, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		dashReady = true
		if flashCooldownFiller then
			flashCooldownFiller.Visible = false
			flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
		end
		flashButton.Interactable = true
	end)
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

----------------- MOVEMENT METHODS ------------------------

local function ReturnAngleBetweenVectors(VectorA, VectorB)
	if VectorA.Magnitude <= FLOATING_ERROR_MARGIN or VectorB.Magnitude <= FLOATING_ERROR_MARGIN then
		return 0
	end

	local dotProduct = VectorA:Dot(VectorB)
	local normalizedDotProduct = math.clamp(dotProduct / (VectorA.Magnitude * VectorB.Magnitude), -1, 1)

	return math.deg(math.acos(normalizedDotProduct))
end

local function ReturnDirectionAndTiltAngle(ReferenceVector, OtherVector, NormalVector)
	NormalVector = NormalVector or Vector3.yAxis

	if ReferenceVector.Magnitude == 0 or OtherVector.Magnitude == 0 then
		return 1, 0
	end

	local crossProduct = ReferenceVector:Cross(OtherVector)
	local direction = crossProduct:Dot(NormalVector) >= 0 and 1 or -1

	ReferenceVector = ReferenceVector * Vector3.new(1, 0, 1)
	OtherVector = OtherVector * Vector3.new(1, 0, 1)

	local dotProduct = ReferenceVector:Dot(OtherVector)
	local normalizedDotProduct = math.clamp(dotProduct / (ReferenceVector.Magnitude * OtherVector.Magnitude), -1, 1)

	local angle = math.deg(math.acos(normalizedDotProduct))

	return direction, angle
end

function CalculateMoveDirection()
	local controls = GetControls()
	local inputVector = controls:GetMoveVector()
	if inputVector.Magnitude > 0.1 then
		local goalCFrame = Camera.CFrame * CFrame.new(inputVector.X, 0, inputVector.Z)
		local goalMoveVector = (goalCFrame.Position - Camera.CFrame.Position)
		NewController.MoveVector = (goalMoveVector * Vector3.new(1, 0, 1)).Unit
	else
		NewController.MoveVector = Vector3.zero
		isBraking = false
	end
end

function Lerp(Start, Target, Alpha)
	return Start + (Target - Start) * Alpha
end

function CalculateSpeed(topSpeed)
	local newTargetSpeed = NewController.MoveVector.Magnitude == 0 and 0 or topSpeed

	if NewController.CurrentSpeed ~= newTargetSpeed then
		IsDecelerating = newTargetSpeed == 0
	end
	NewController.CurrentSpeed = newTargetSpeed
end

function ReturnDownhillVector(SurfaceNormal)
	if SurfaceNormal then
		local horizontalVector = SurfaceNormal:Cross(Vector3.yAxis)
		local downhillVector = SurfaceNormal:Cross(horizontalVector)

		if downhillVector.Magnitude >= FLOATING_ERROR_MARGIN then
			return downhillVector.Unit
		end
	end

	return Vector3.zero
end

function GetRaycastResult()
	local boardSize = Board.Size.Y
	-- Start ray from bottom of board
	local origin = Board.Position - Vector3.new(0, boardSize/2, 0)
	local direction = Vector3.new(0, -1, 0)

	-- Dynamic ray distance based on expected fall distance
	local rayDistance = 10  -- Adjust based on your needs

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { Board, character }

	return workspace:Raycast(origin, direction * rayDistance, rayParams)
	
	
	
	
	--local Origin = Board.Position
	--local Direction = Vector3.new(0, -1, 0)
	--local CheckingDistance = HoverHeight + RayDistance
	--local Size = Board.Size.Y / 2

	--local RayParams = RaycastParams.new()
	--RayParams.FilterType = Enum.RaycastFilterType.Exclude
	--RayParams.FilterDescendantsInstances = { Board, character }
	
	--local offsetY = (Direction * CheckingDistance)

	--local frontRaycast =
	--	workspace:Raycast(Origin + Board.CFrame.LookVector * 3.5, offsetY, RayParams)
	--local middleRaycast = workspace:Raycast(Origin, offsetY, RayParams)
	--local backRaycast =
	--	workspace:Raycast(Origin - Board.CFrame.LookVector * 3.5, offsetY, RayParams)

	--local RaycastResult = middleRaycast
	
	--if
	--	RaycastResult == nil
	--	or (backRaycast and backRaycast.Distance < RaycastResult.Distance - RAY_PREFERENCE_DISTANCE)
	--then
	--	RaycastResult = backRaycast
	--end

	--if
	--	RaycastResult == nil
	--	or (frontRaycast and frontRaycast.Distance < RaycastResult.Distance - RAY_PREFERENCE_DISTANCE)
	--then
	--	RaycastResult = frontRaycast
	--end
	
	--return RaycastResult
end

function ApplyVelocity(Acceleration, deltaTimeRender)
	local RaycastResult = GetRaycastResult()
	local velocityFactor = Acceleration
	if IsDecelerating then
		velocityFactor = CanJump and Acceleration * 1.5 or DECELERATION_FACTOR
	end

	local downhillVector = Vector3.zero
	local downhillAngle = 0

	if RaycastResult then
		local distanceToGround = RaycastResult.Distance
		if distanceToGround < 1.2 then
			CanJump = true
			downhillVector = ReturnDownhillVector(RaycastResult.Normal)
			downhillAngle = ReturnAngleBetweenVectors(RaycastResult.Normal, Vector3.yAxis)
		else
			CanJump = false
		end
	end
		
	downhillAngle = math.clamp(math.abs(downhillAngle), 0, 45)

	local finalVelocity = Vector3.new(
		NewController.MoveVector.X * NewController.CurrentSpeed,
		bodyVelocity.Velocity.Y,
		NewController.MoveVector.Z * NewController.CurrentSpeed
	) + downhillVector * (workspace.Gravity / 2) * (downhillAngle / DOWNHILL_SLOPE_ANGLE)

	local direction, tiltAngle =
		ReturnDirectionAndTiltAngle(finalVelocity * Vector3.new(1, 0, 1), bodyVelocity.Velocity * Vector3.new(1, 0, 1))
	HorizontalTiltAngle = -direction * tiltAngle

	bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(finalVelocity, deltaTimeRender * velocityFactor)
end

function ApplyOrientation(deltaTimeRender)
	local RaycastResult = GetRaycastResult()
	local BoardCF = Board.CFrame

	local newNormal = RaycastResult and RaycastResult.Normal or Vector3.yAxis
	if newNormal then
		local velocity = Board.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local LookVector = BoardCF.LookVector

		if velocity.Magnitude < 0.1 then
			return
		end
		LookVector = velocity.Unit

		local RightVector = LookVector:Cross(newNormal)
		if RightVector.Magnitude < 0.1 then
			return
		end
		RightVector = RightVector.Unit
		local UpVector = newNormal
		local AlignedCFrame = CFrame.fromMatrix(Board.Position, RightVector, UpVector)

		--local normalizedTilt = 0
		--if CanJump and NewController.MoveVector.Magnitude > FLOATING_ERROR_MARGIN then
		--end
		local normalizedTilt = math.clamp(HorizontalTiltAngle, -MAX_HORIZONTAL_ROTATION, MAX_HORIZONTAL_ROTATION)

		local alpha = 1 - math.exp(-ORIENTATION_FACTOR * 0.8 * deltaTimeRender)
		local targetCFrame = AlignedCFrame * CFrame.Angles(0, 0, math.rad(normalizedTilt))
		bodyGyro.CFrame = bodyGyro.CFrame:Lerp(targetCFrame, alpha)
	end
end

function UpdateFOV(topSpeed, deltaTimeRender)
	local diff = MAX_FOV - MIN_FOV
	local speedBasedFOV =
		math.clamp(MIN_FOV + diff * (Board.AssemblyLinearVelocity.Magnitude / topSpeed), MIN_FOV, MAX_FOV)
	if isBoosting or isDashing then
		speedBasedFOV = math.min(speedBasedFOV + 10, MAX_FOV + 10)
	end
	
	Camera.FieldOfView = Lerp(Camera.FieldOfView, speedBasedFOV, deltaTimeRender * FOV_FACTOR)
end

function JumpAnimation(dt)
	if not flipping then return end

	flipAngle = flipAngle + FLIP_SPEED * dt

	if flipAngle >= FLIP_ANGLE then
		flipAngle = FLIP_ANGLE
		flipping = false
	end

	local flipCF = CFrame.Angles(flipAngle, 0, 0)

	-- APPLY VIA MOTOR6D ONLY
	motor.C0 = BASE_C0 * flipCF
	motor.C1 = BASE_C1 * flipCF
end

-----------------------------------------------------------

-- PLAYER LIFECYCLE
local function HideCharacter(char)
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 1
			obj.CastShadow = false
		elseif obj:IsA("Decal") then
			obj.Transparency = 1
		end
	end
end

local function SetTrail(trailColor)
	if Trail then
		Trail.Color = ColorSequence.new(trailColor)
	end
end

local function ApplyEquippedTrail()
	HoverboardService:GetEquippedTrail():andThen(function(trailName)
		if not Trail then
			return
		end

		if not trailName then
			print("No trail equipped.")
			Trail.Enabled = false
			return
		end

		local config = TrailsConfig.GetConfig(trailName)
		if not config then
			warn("Invalid trail config:", trailName)
			Trail.Enabled = false
			return
		end
		Trail.Enabled = true
		Trail.Color = ColorSequence.new(config.Color)
		print("Trail applied:", trailName)
	end)
end

local function ResetStates()
	print("Reset states called")
	character = nil
	humanoid = nil
	rootPart = nil
	Board = nil
	bodyGyro = nil
	controls = nil
	acceleration = 0
	topSpeed = 0
	jumpPower = 0
	ForwardLean = 0
	NewController.SpeedVar = 0
	NewController.CurrentSpeed = 0
	flyEnergy = MAX_FLY_ENERGY
	CanJump = false
	isHoverboardInitialized = false
	boostReady = true
	dashReady = true
	isDashing = false
	spaceHeld = false
	hasGravityCoil = false
	hasDoubleJump = false
	hasFly = false
	NewController:SetGravityCoil(false)
	workspace.Gravity = DEFAULT_GRAVITY
end

local function InputListeners()
	UserInputService.InputBegan:Connect(function(Input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Q then
				print("Hoverboard: Boost requested.")
				ApplyBoost(BOOST_DURATION, BOOST_AMOUNT)
			end
			if Input.KeyCode == Enum.KeyCode.F then
				print("Hoverboard: Flash requested.")
				--ApplyDash(DASH_AMOUNT, DASH_DURATION, DASH_DISTANCE)
				Dash(DASH_AMOUNT)
			end
			if Input.KeyCode == Enum.KeyCode.Space then
				spaceHeld = true
			end
		end
		if
			Input.UserInputType == Enum.UserInputType.MouseButton2
			or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		then
			
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		if CanJump then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	UserInputService.InputEnded:Connect(function(Input, GameProcessed)
		if GameProcessed then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Space then
				spaceHeld = false
			end
		end

		if
			Input.UserInputType == Enum.UserInputType.MouseButton2
			and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
		then
			
		end
	end)
	boostButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Boost requested.")
		ApplyBoost(BOOST_DURATION, BOOST_AMOUNT)
	end)
	flashButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Flash requested.")
		--ApplyDash(DASH_AMOUNT, DASH_DURATION, DASH_DISTANCE)
		Dash(DASH_AMOUNT)
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
	Board = character:WaitForChild("Hoverboard"):WaitForChild("PrimaryPart")
	Trail = Board:WaitForChild("Trail")
	Trail.Enabled = false
	--ApplyEquippedTrail()
	isHoverboardInitialized = true

	self:StartHoverboard(config, HoverboardService)
end

function NewController:StartHoverboard(config, HoverboardService)
	print("StartHoverboard called")
	acceleration = config.Acceleration or ACCELERATION
	topSpeed = config.TopSpeed or MAX_SPEED
	jumpPower = config.JumpPower or JUMP_POWER
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jumpPower
	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)

	InitBodyMovers()
	RefreshBoostGUI()
	RefreshFlashGUI()
	CloneVFX()

	if runningConnection then
		runningConnection:Disconnect()
	end
	runningConnection = RunService.PreRender:Connect(function(dt)
		CalculateMoveDirection()
		CalculateSpeed(topSpeed)
		ApplyVelocity(acceleration, dt)
		ApplyOrientation(dt)
		UpdateFOV(topSpeed, dt)
		if CanJump and spaceHeld then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		
		if speedGUI and speedLabel and speedFrame then
			UpdateSpeedGUI(topSpeed)
		end
	end)
end

local function InitializeHoverboard()
	if character then
		print("Initializing hoverboard for character.")
		local hoverboardPart = character:FindFirstChild("Hoverboard")
		if hoverboardPart then
			-- Get hoverboard data from server
			HoverboardService:GetHoverboardData()
				:andThen(function(data)
					if data then
						print("Initializing hoverboard:", data.Name)
						NewController:SetActiveConfig(data.Name)
					else
						-- Fallback to default
						print("No hoverboard data, using default")
						NewController:SetActiveConfig("Hoverboard1")
					end
				end)
				:catch(function(err)
					warn("Failed to get hoverboard data:", err)
					NewController:SetActiveConfig("Hoverboard1")
				end)
		end
	end
end

function HandleHumanoidStates()
	humanoid.StateChanged:Connect(function(oldState, newState)
		if oldState == Enum.HumanoidStateType.Physics
			and newState == Enum.HumanoidStateType.Jumping then
			
		end
	
		if oldState == Enum.HumanoidStateType.Jumping then
			if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall 
				or newState == Enum.HumanoidStateType.Running then
					humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end
		end
	end)
end

function OnCharacterAdded(char)
	HoverboardService = Knit.GetService("HoverboardService")
	character = char
	humanoid = char:WaitForChild("Humanoid")
	humanoid.AutoRotate = false
	HandleHumanoidStates()
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Disable all humanoid animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	-- Also remove Animate script if present (extra safety)
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end
	rootPart = char:WaitForChild("HumanoidRootPart")
	rootPart.CastShadow = false
	motor = rootPart:WaitForChild("HoverboardMotor")
	BASE_C0 = motor.C0
	BASE_C1 = motor.C1
	InputListeners()
	InitializeHoverboard()
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

-- [External Modifier Functions]		------
function NewController:ApplyAssist(ForceVector)
	bodyVelocity.Velocity = bodyVelocity.Velocity + ForceVector
	--rootPart.AssemblyLinearVelocity += ForceVector	--Added
end

function NewController:ApplyJump(JumpPower)
	local v = Board.AssemblyLinearVelocity
	Board.AssemblyLinearVelocity = Vector3.new(v.X, JumpPower, v.Z)
end

function NewController:Slow()
	bodyVelocity.Velocity = Vector3.zero
	local originalAcceleration = acceleration

	acceleration = acceleration * 0.1
	task.delay(0.2, function()
		acceleration = originalAcceleration
	end)
end

------------------------------------------------

function NewController:KnitStart()
	print("NewController started")
	OnPlayerAdded(player)
	HoverboardService.HoverboardChanged:Connect(function(boardName)
		print("HoverboardChanged event received:", boardName)
		InitializeHoverboard()
	end)
	HoverboardService.HoverboardSpawned:Connect(function()
		print("HoverboardSpawned event received")
		InitializeHoverboard()
	end)
	HoverboardService.HoverboardRemoved:Connect(function()
		isHoverboardInitialized = false
	end)
	HoverboardService.TrailEquipped:Connect(function(owner, trailName)
		print("EquipTrail event received")
		if owner ~= player then
			return
		end
		local trailConfig = TrailsConfig.GetConfig(trailName)
		if trailConfig then
			Trail.Enabled = true
			SetTrail(trailConfig.Color)
		end
	end)
	HoverboardService.TrailUnequipped:Connect(function()
		Trail.Enabled = false
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