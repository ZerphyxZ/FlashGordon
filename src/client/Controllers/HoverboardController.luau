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
local ContextActionService = Global.ContextActionService
local HoverboardFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")

local HoverboardData = require(HoverboardFolder:WaitForChild("Hoverboards"))
local HoverboardConstants = require(HoverboardFolder:WaitForChild("HoverboardConstants"))
local CollisionManager = require(HoverboardFolder:WaitForChild("CollisionManager"))
local AnimationManager = require(HoverboardFolder:WaitForChild("AnimationManager"))
local Utilities = require(HoverboardFolder:WaitForChild("Utilities"))
--local Physics = require(HoverboardFolder:WaitForChild("PhysicsConstraints"))

-- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- Module-level variables
local character, humanoid, humanoidRootPart
local hoverboard, bodyVelocity, bodyGyro, hoverBodyPosition
local inputVector = Vector3.zero
local currentSpeed = 0
local isOnHoverboard = false
local speedValue

-- Local references for better performance
local MOVEMENT = HoverboardConstants.Movement
local JUMPING = HoverboardConstants.Jumping
local HOVER = HoverboardConstants.Hover
local PHYSICS = HoverboardConstants.Physics
local INPUT = HoverboardConstants.Input

-- State management
local State = {
	canJump = false,
	isJumping = false,
	lastJumpTime = 0,
	lastMoveDir = Vector3.zero,
	braking = false,
	hoverOffset = 0,
	smoothedGroundNormal = nil,
	isCollidingWithWall = false,
	collisionNormal = Vector3.zero,
	collisionRecoveryTimer = 0,
	smoothedTilt = 0,
	lastForwardWanted = nil,
	bobTime = 0,
	baseHoverHeight = HOVER.HOVER_HEIGHT,
}

--[[
    GUI Management
]]
--
local GUIManager = {}

function GUIManager.SetupSpeedGUI()
	if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SpeedGUI") then
		speedValue = player.PlayerGui.SpeedGUI:FindFirstChildWhichIsA("TextLabel", true)
		return
	end

	local speedGui = Instance.new("ScreenGui")
	speedGui.Name = "SpeedGUI"
	speedGui.Parent = player:WaitForChild("PlayerGui")

	local speedFrame = Instance.new("Frame")
	speedFrame.Size = UDim2.new(0, 200, 0, 80)
	speedFrame.Position = UDim2.new(0, 20, 0, 20)
	speedFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	speedFrame.BackgroundTransparency = 0.3
	speedFrame.BorderSizePixel = 0
	speedFrame.Parent = speedGui

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(1, 0, 0.5, 0)
	speedLabel.Position = UDim2.new(0, 0, 0, 0)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "SPEED"
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.TextScaled = true
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.Parent = speedFrame
end

function GUIManager.UpdateSpeedDisplay()
	if speedValue then
		speedValue.Text = tostring(math.floor(currentSpeed))
	end
end

local Physics = {}
function Physics.CreatePhysicsConstraints()
	if not humanoidRootPart or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	-- BodyVelocity
	if not humanoidRootPart:FindFirstChild("HoverBodyVelocity") then
		bodyVelocity = Utilities.CreateConstraint(humanoidRootPart, "BodyVelocity", {
			Name = "HoverBodyVelocity",
			MaxForce = PHYSICS.BODY_VELOCITY_MAX_FORCE,
			Velocity = Vector3.new(0, 0, 0),
			P = PHYSICS.BODY_VELOCITY_P,
		})
	else
		bodyVelocity = humanoidRootPart:FindFirstChild("HoverBodyVelocity")
	end

	-- BodyGyro
	if not humanoidRootPart:FindFirstChild("HoverBodyGyro") then
		bodyGyro = Utilities.CreateConstraint(humanoidRootPart, "BodyGyro", {
			Name = "HoverBodyGyro",
			MaxTorque = PHYSICS.BODY_GYRO_MAX_TORQUE,
			P = HOVER.BODYGYRO_P,
			D = HOVER.BODYGYRO_D,
			CFrame = humanoidRootPart.CFrame,
		})
	else
		bodyGyro = humanoidRootPart:FindFirstChild("HoverBodyGyro")
	end

	-- BodyPosition for hoverboard
	local primary = hoverboard.PrimaryPart
	if primary and not primary:FindFirstChild("HoverPosition") then
		hoverBodyPosition = Utilities.CreateConstraint(primary, "BodyPosition", {
			Name = "HoverPosition",
			MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE,
			Position = primary.Position,
			P = PHYSICS.BODY_POSITION_P,
			D = PHYSICS.BODY_POSITION_D,
		})
	else
		hoverBodyPosition = primary and primary:FindFirstChild("HoverPosition")
	end
end

function Physics.CleanupConstraints()
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	if bodyGyro and bodyGyro.Parent then
		bodyGyro:Destroy()
	end
	if hoverBodyPosition and hoverBodyPosition.Parent then
		hoverBodyPosition:Destroy()
	end

	local localMotor = humanoidRootPart and humanoidRootPart:FindFirstChild("HoverboardMotorLocal")
	if localMotor then
		localMotor:Destroy()
	end

	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
end

--[[
    Ground Detection & Jumping
]]
--
local JumpManager = {}

function JumpManager.IsGrounded()
	if not hoverboard or not hoverboard.PrimaryPart then
		return false, nil, nil
	end

	local primary = hoverboard.PrimaryPart
	local rayOrigin = primary.Position
	local rayDir = Vector3.new(0, -HOVER.RAYCAST_DISTANCE, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		local distance = primary.Position.Y - result.Position.Y
		if distance <= (HOVER.HOVER_HEIGHT + 1.5) then
			return true, result.Position, result.Normal
		end
	end
	return false, nil, nil
end

function JumpManager.AttemptJump()
	print("Jump called")

	local now = tick()
	if now - State.lastJumpTime < JUMPING.JUMP_COOLDOWN then
		return
	end

	local grounded = JumpManager.IsGrounded()
	if not grounded or State.isJumping then
		return
	end

	State.lastJumpTime = now
	State.isJumping = true
	State.canJump = false

	local speedRatio = math.clamp(currentSpeed / MOVEMENT.MAX_SPEED, 0, 1)
	local jumpHeight = JUMPING.MIN_JUMP_HEIGHT
		+ (
			math.floor((JUMPING.MAX_JUMP_HEIGHT - JUMPING.MIN_JUMP_HEIGHT) * speedRatio / JUMPING.STEP_MULTIPLIER)
			* JUMPING.STEP_MULTIPLIER
		)
	
	local jumpVelocity = jumpHeight * (JUMPING.STUDS_MULTIPLIER or 5)

	local currentVelocity = humanoidRootPart.Velocity
	humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, jumpVelocity, currentVelocity.Z)

	if hoverBodyPosition then
		hoverBodyPosition.MaxForce = Vector3.zero
		task.delay(0.5, function()
			if hoverBodyPosition and hoverBodyPosition.Parent then
				hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
			end
		end)
	end

	-- local now = tick()
	-- if now - State.lastJumpTime < JUMPING.JUMP_COOLDOWN then
	-- 	return
	-- end

	-- local grounded = JumpManager.IsGrounded()
	-- if not grounded or State.isJumping then
	-- 	return
	-- end

	-- State.lastJumpTime = now
	-- State.isJumping = true
	-- State.canJump = false

	-- local cfg = HoverboardController.ActiveConfig or {}
	-- local speed = cfg.TopSpeed or MOVEMENT.MAX_SPEED
	-- local jumpPower = cfg.JumpPower or JUMPING.JUMP_POWER

	-- local speedRatio = math.clamp(currentSpeed / speed, 0, 1)
	-- local jumpHeight = JUMPING.MIN_JUMP_HEIGHT
	-- 	+ math.floor((JUMPING.MAX_JUMP_HEIGHT - JUMPING.MIN_JUMP_HEIGHT) * speedRatio / JUMPING.STEP_MULTIPLIER)
	-- 		* JUMPING.STEP_MULTIPLIER

	-- local currentVelocity = humanoidRootPart.Velocity
	-- humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, jumpHeight, currentVelocity.Z)

	-- if hoverBodyPosition then
	-- 	hoverBodyPosition.MaxForce = Vector3.zero
	-- 	task.delay(JUMPING.HOVER_DISABLE_TIME, function()
	-- 		if hoverBodyPosition and hoverBodyPosition.Parent then
	-- 			hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
	-- 		end
	-- 	end)
	-- end
end

--[[
    Movement System
]]
--
local MovementManager = {}

function MovementManager.CalculateSpeed(Acceleration, Deceleration, targetSpeed, dt, isMoving)
	local rate = isMoving and Acceleration or Deceleration
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * rate * dt * MOVEMENT.MOVEMENT_SMOOTHNESS
	currentSpeed = math.clamp(currentSpeed, 0, MOVEMENT.MAX_SPEED)
end

function MovementManager.ApplyMovement(moveDir, dt)
	local cfg = HoverboardController.ActiveConfig or {}
	local MAX_SPEED = cfg.TopSpeed or MOVEMENT.MAX_SPEED
	local ACCELERATION = cfg.Acceleration or MOVEMENT.ACCELERATION
	local DECELERATION = cfg.Deceleration or MOVEMENT.DECELERATION
	local JUMP_POWER = cfg.JumpPower or MOVEMENT.JUMP_POWER

	-- Update last movement direction only if actually moving
	if moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
		State.lastMoveDir = moveDir.Unit
	end

	-- Calculate target speed with directional modifiers
	local isMoving = moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD
	local targetSpeed = isMoving and MAX_SPEED or 0

	-- Apply speed calculation
	MovementManager.CalculateSpeed(ACCELERATION, DECELERATION, targetSpeed, dt, isMoving)

	-- Handle wall collisions - pass the current move direction
	local probeDir = (moveDir.Magnitude > 0) and moveDir or State.lastMoveDir
	local wallHit, wallNormal, wallDistance = CollisionManager.DetectWallCollision(
		humanoidRootPart,
		character,
		hoverboard,
		probeDir,
		currentSpeed,
		MOVEMENT.MAX_SPEED
	)
	CollisionManager.HandleWallCollision(
		humanoidRootPart,
		wallNormal,
		wallDistance,
		moveDir,
		State,
		bodyVelocity,
		bodyGyro,
		currentSpeed,
		MOVEMENT,
		dt
	)

	-- Update collision state for auto-reset
	CollisionManager.UpdateCollisionState(State, dt)

	-- If input is blocked by collision, ensure speed is zero and skip movement application
	if State.inputBlocked then
		currentSpeed = 0
		-- Make sure velocity is fixed to zero horizontally in ApplyVelocity; we still call it so vertical physics remain
		MovementManager.ApplyVelocity(dt, Vector3.zero)
		-- Skip rotation while blocked
		-- Update prev speed for decel detection
		State.prevSpeed = currentSpeed
		return
	end

	-- Stop if speed is very low
	if currentSpeed < 0.3 then
		currentSpeed = 0
	end

	-- Apply velocity
	MovementManager.ApplyVelocity(dt, moveDir)

	-- Apply rotation
	if State.lastMoveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
		MovementManager.ApplyRotation(dt)
	end

	-- Update prevSpeed for next-frame deceleration detection (used by HoverManager.AlignHoverboard)
	State.prevSpeed = currentSpeed
end

function MovementManager.ApplyVelocity(dt, moveDir)
	if not bodyVelocity then
		return
	end

	-- If input is completely blocked, hold horizontal velocity to zero smoothly
	if State.inputBlocked then
		local currentVel = humanoidRootPart.AssemblyLinearVelocity
		local targetVel = Vector3.new(0, currentVel.Y, 0)
		local velT = math.clamp(dt * 5, 0, 1)
		bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVel, velT)
		return
	end

	local effectiveDir = (currentSpeed > 0) and State.lastMoveDir or Vector3.zero
	local velocity = effectiveDir * currentSpeed
	local currentVel = humanoidRootPart.AssemblyLinearVelocity

	-- Check if we can move in the desired direction
	local canMove = CollisionManager.CanMoveInDirection(moveDir, State)

	-- Only apply movement if allowed and we have input
	if canMove and moveDir.Magnitude > 0 then
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = math.clamp(dt * 12, 0, 1)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	elseif moveDir.Magnitude == 0 then
		-- Allow coasting if no input, regardless of collision state
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = math.clamp(dt * 12, 0, 1)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	else
		-- Only slow down when actively trying to move into a wall
		if not canMove then
			-- Gentle slowdown instead of hard stop
			local currentHorizVel = Vector3.new(currentVel.X, 0, currentVel.Z)
			local slowedHorizVel = currentHorizVel * (1 - dt * 5) -- Gradual slowdown
			bodyVelocity.Velocity = Vector3.new(slowedHorizVel.X, currentVel.Y, slowedHorizVel.Z)
		end
	end
end

function MovementManager.ApplyRotation(dt)
	-- Do not rotate while input is blocked (player is stopped against wall)
	if State.inputBlocked then
		return
	end
	if not bodyGyro or State.lastMoveDir.Magnitude == 0 then
		return
	end

	-- Player should FACE 90° relative to movement
	local moveDir = State.lastMoveDir
	local candidateNormal = State.smoothedGroundNormal or Vector3.new(0, 1, 0)
	local forwardProj = Utilities.ProjectVectorOnPlane(State.lastMoveDir, candidateNormal)

	-- 90-degree facing offset (right side)
	local rightVector = candidateNormal:Cross(moveDir).Unit
	local facingDir = rightVector -- facing sideways instead of forward

	if facingDir.Magnitude < 1e-5 then
		facingDir = Vector3.new(0, 0, -1)
	end

	local targetPlayerCFrame =
		CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + facingDir, candidateNormal)
	local rotSmooth = math.clamp(dt * MOVEMENT.ROTATION_SPEED * MOVEMENT.ROTATION_SMOOTHNESS, 0, 1)

	local currentCF = bodyGyro.CFrame
	local newRot = (currentCF - currentCF.Position):Lerp(targetPlayerCFrame - targetPlayerCFrame.Position, rotSmooth)
	bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot
end

--[[
    Hover & Surface Alignment
]]
--
local HoverManager = {}

function HoverManager.AlignToSurface(dt)
	if not humanoidRootPart or not hoverboard then
		return
	end

	local origin = humanoidRootPart.Position
	local direction = Vector3.new(0, -1, 0) * HOVER.RAYCAST_DISTANCE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return
	end

	local surfaceNormal = result.Normal
	local rootForward = humanoidRootPart.CFrame.LookVector
	local forwardProj = Utilities.ProjectVectorOnPlane(rootForward, surfaceNormal)

	if forwardProj.Magnitude < 1e-5 then
		forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
		if forwardProj.Magnitude < 1e-5 then
			forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
		end
	end

	local orientSmooth = math.clamp(dt * HOVER.ORIENTATION_SMOOTHNESS, 0, 1)
	State.smoothedGroundNormal = State.smoothedGroundNormal
			and State.smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)
		or surfaceNormal

	local finalNormal = State.smoothedGroundNormal.Unit
	local finalForward = Utilities.ProjectVectorOnPlane(forwardProj, finalNormal)

	if finalForward.Magnitude < 1e-5 then
		finalForward = Vector3.new(0, 0, -1)
	end

	local targetCFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + finalForward, finalNormal)

	if bodyGyro then
		local currentOrient = bodyGyro.CFrame
		local currentPos = humanoidRootPart.Position
		local lerpT = orientSmooth
		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	else
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, orientSmooth)
	end
end

function HoverManager.UpdateHover(dt)
	if not hoverboard or not hoverboard.PrimaryPart or State.isJumping then
		return
	end

	local primary = hoverboard.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local size = primary.Size
	local rayLength = HOVER.RAYCAST_DISTANCE
	local rayOffsets = {
		Vector3.new(size.X / 2, 0, size.Z / 2),
		Vector3.new(-size.X / 2, 0, size.Z / 2),
		Vector3.new(size.X / 2, 0, -size.Z / 2),
		Vector3.new(-size.X / 2, 0, -size.Z / 2),
	}

	local hitPositions, hitNormals = {}, {}

	for _, offset in ipairs(rayOffsets) do
		local origin = primary.CFrame:PointToWorldSpace(offset + Vector3.new(0, 0.2, 0))
		local direction = Vector3.new(0, -rayLength, 0)
		local result = workspace:Raycast(origin, direction, params)
		if result then
			table.insert(hitPositions, result.Position)
			table.insert(hitNormals, result.Normal)
		end
	end

	if #hitPositions > 0 then
		local avgPos, avgNormal = Vector3.zero, Vector3.zero
		for i = 1, #hitPositions do
			avgPos = avgPos + hitPositions[i]
			avgNormal = avgNormal + hitNormals[i]
		end
		avgPos = avgPos / #hitPositions
		avgNormal = avgNormal.Unit

		local hoverT = math.clamp(1 - math.exp(-HOVER.HOVER_SMOOTHNESS * dt * 10), 0, 1)
		State.smoothedGroundNormal = State.smoothedGroundNormal and State.smoothedGroundNormal:Lerp(avgNormal, hoverT)
			or avgNormal

		local finalNormal = State.smoothedGroundNormal.Unit

		-- ========== UPDATED BOBBING EFFECT CODE ==========
		-- Update bobbing time (very slow - 0.5 seconds per full cycle)
		State.bobTime = State.bobTime + (dt * 2)

		-- Calculate bobbing offset using sine wave
		-- Very subtle bobbing: 0.1 studs amplitude, slow frequency
		local bobOffset = math.sin(State.bobTime * math.pi * 2) * 0.1

		-- Apply bobbing to hover height
		local targetY = avgPos.Y + State.baseHoverHeight + bobOffset
		-- ========== END UPDATED CODE ==========

		if hoverBodyPosition then
			local currentBP = hoverBodyPosition.Position
			local targetBP = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
			local posT = math.clamp(dt * 10, 0, 1)
			hoverBodyPosition.Position = currentBP:Lerp(targetBP, posT)
		end

		HoverManager.AlignHoverboard(primary, finalNormal, dt)
	else
		if hoverBodyPosition then
			hoverBodyPosition.MaxForce = Vector3.zero
		end
	end
end

function HoverManager.AlignHoverboard(primary, finalNormal, dt)
	-- Ensure state fields exist
	State.smoothedLean = State.smoothedLean or 0
	State.prevSpeed = State.prevSpeed or 0
	State.smoothedTilt = State.smoothedTilt or 0 -- X-axis tilt state

	-- Compute forward on plane (what the board should look along)
	local playerForward = humanoidRootPart.CFrame.LookVector
	local forwardOnPlane = Utilities.ProjectVectorOnPlane(playerForward, finalNormal)

	if forwardOnPlane.Magnitude < 1e-5 then
		forwardOnPlane = State.lastMoveDir.Magnitude > 0
				and Utilities.ProjectVectorOnPlane(State.lastMoveDir, finalNormal)
			or Vector3.new(0, 0, -1)
	end
	forwardOnPlane = forwardOnPlane.Unit

	-- ---------- 1) Calculate X-axis tilt based on rotation ----------
	-- Track rotation direction and speed for tilt calculation
	local currentForward = Utilities.ProjectVectorOnPlane(primary.CFrame.LookVector, finalNormal)
	if currentForward.Magnitude < 1e-5 then
		currentForward = forwardOnPlane
	end
	currentForward = currentForward.Unit

	-- Calculate angular velocity for responsive tilt
	local angularVelocity = 0
	if State.lastForwardWanted then
		local dot = math.clamp(State.lastForwardWanted:Dot(forwardOnPlane), -1, 1)
		local angleDelta = math.acos(dot)
		local cross = State.lastForwardWanted:Cross(forwardOnPlane)
		local sign = (cross:Dot(finalNormal) >= 0) and 1 or -1
		angularVelocity = angleDelta * sign / math.max(1e-6, dt)
	end
	State.lastForwardWanted = forwardOnPlane

	-- Calculate target tilt based on angular velocity (plane-like banking)
	local maxTilt = math.rad(45) -- 30 degrees maximum tilt
	local tiltSensitivity = 0.8 -- How responsive the tilt is to rotation
	local targetTilt = -angularVelocity * tiltSensitivity -- Negative for natural banking
	targetTilt = math.clamp(targetTilt, -maxTilt, maxTilt)

	-- Smooth the tilt
	local tiltSmooth = math.clamp(dt * 8, 0, 1) -- Smoothing factor for tilt
	State.smoothedTilt = State.smoothedTilt + (targetTilt - State.smoothedTilt) * tiltSmooth

	-- ---------- 2) Build target hover CFrame with tilt ----------
	local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, finalNormal)

	-- Apply X-axis tilt (rotation around local X axis)
	if math.abs(State.smoothedTilt) > 1e-5 then
		local rightVector = finalNormal:Cross(forwardOnPlane)
		if rightVector.Magnitude > 1e-5 then
			rightVector = rightVector.Unit
			local tiltCF = CFrame.fromAxisAngle(rightVector, State.smoothedTilt)
			targetHoverCF = targetHoverCF * tiltCF
		end
	end

	-- ---------- 3) Apply player tilt to match hoverboard ----------
	-- This makes the player lean with the hoverboard for a more natural feel
	if bodyGyro and bodyGyro.Parent then
		local currentPlayerCF = bodyGyro.CFrame
		local playerTargetCF =
			CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + forwardOnPlane, finalNormal)

		-- Apply the same tilt to the player
		if math.abs(State.smoothedTilt) > 1e-5 then
			local rightVector = finalNormal:Cross(forwardOnPlane)
			if rightVector.Magnitude > 1e-5 then
				rightVector = rightVector.Unit
				local playerTiltCF = CFrame.fromAxisAngle(rightVector, State.smoothedTilt * 0.7) -- Slightly less tilt for player
				playerTargetCF = playerTargetCF * playerTiltCF
			end
		end

		-- Smoothly apply the tilted orientation to the player
		local playerSmooth = math.clamp(dt * 6, 0, 1)
		local newPlayerRot = (currentPlayerCF - currentPlayerCF.Position):Lerp(
			playerTargetCF - playerTargetCF.Position,
			playerSmooth
		)
		bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newPlayerRot
	end

	-- ---------- 4) Smoothly lerp hoverboard CFrame to target ----------
	local primaryT = math.clamp(dt * HOVER.HOVER_SMOOTHNESS, 0, 1)
	primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)
end

--[[
    Main Controller Functions
]]
--
function HoverboardController:SetActiveHoverboard(boardName)
	local config = HoverboardData.GetConfig(boardName)
	if not config then
		warn("[HoverboardController] Could not find hoverboard config for " .. tostring(boardName))
		return
	end
	self.ActiveConfig = config
end

function HoverboardController:WaitForHoverboard()
	if not character then
		return
	end

	local hb = character:WaitForChild("Hoverboard", 5)
	if hb then
		hoverboard = hb

		-- Extract hover offset from server Motor6D
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local motor6D = hrp and hrp:FindFirstChild("HoverboardMotor")
		if motor6D and motor6D:IsA("Motor6D") then
			local c0Pos = motor6D.C0.Position
			State.hoverOffset = -c0Pos.Y
		else
			State.hoverOffset = 0
		end

		Physics.CreatePhysicsConstraints(humanoidRootPart, hoverboard, bodyVelocity, bodyGyro, hoverBodyPosition)
		isOnHoverboard = true
		GUIManager.SetupSpeedGUI()
		--InputManager.SetContext(true, State, JumpManager, INPUT.KEYBOARD_MOVE_SPEED)
	end
end

--[[
    State Management
]]
--
local function ResetStates()
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
	--inputVector = Vector3.zero
	currentSpeed = 0
	isOnHoverboard = false

	State.canJump = false
	State.isJumping = false
	State.lastJumpTime = 0
	State.lastMoveDir = Vector3.zero
	State.braking = false
	State.hoverOffset = 0
	State.smoothedGroundNormal = nil
	State.isCollidingWithWall = false -- Ensure this resets
	State.collisionNormal = Vector3.zero
	State.collisionRecoveryTimer = 0

	State.smoothedTilt = 0
	State.lastForwardWanted = nil
	State.bobTime = 0
	State.baseHoverHeight = HOVER.HOVER_HEIGHT
end

local function CleanupHoverboard()
	isOnHoverboard = false
	Physics.CleanupConstraints(humanoidRootPart, bodyVelocity, bodyGyro, hoverBodyPosition)
	ContextActionService:UnbindAction("HoverboardJump")
	hoverboard = nil
end

--[[
    Character Setup
]]
--
local function SetupCharacter(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	task.defer(function()
		AnimationManager.DisableMovementAnimations(humanoid, character)
	end)

	humanoid.Died:Connect(function()
		CleanupHoverboard()
		ResetStates()
		--AnimationManager.RestoreAnimations()
	end)

	task.defer(function()
		HoverboardController:WaitForHoverboard()
	end)
end

--[[
    Input Handling
]]
--
local InputManager = {}
function InputManager.HandleJumpAction(inputState)
	print("this function is called")
	if not isOnHoverboard then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		JumpManager.AttemptJump()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

--[[
    Main Update Loop
]]
--

local function UpdateMovement(dt)
	if not isOnHoverboard then
		return
	end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude > 0 then
		inputVector = moveDir.Unit * INPUT.KEYBOARD_MOVE_SPEED
	else
		inputVector = Vector3.zero
	end

	MovementManager.ApplyMovement(moveDir, dt)
	HoverManager.UpdateHover(dt)
	GUIManager.UpdateSpeedDisplay()
end

local function UpdateLanding(dt)
	if State.isJumping then
		local grounded = JumpManager.IsGrounded()
		if grounded then
			State.isJumping = false
			State.canJump = true
		end
	end
	HoverManager.AlignToSurface(dt)
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

	-- Event connections
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner == player then
			self:SetActiveHoverboard(boardName)
			task.defer(function()
				self:WaitForHoverboard()
			end)
		end
	end)

	-- Character setup
	if player.Character then
		SetupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(SetupCharacter)
	player.CharacterRemoving:Connect(function()
		ResetStates()
		CleanupHoverboard()
	end)

	-- Update loops
	RunService.Heartbeat:Connect(function(dt)
		if isOnHoverboard then
			UpdateLanding(dt)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if isOnHoverboard then
			UpdateMovement(dt)
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		JumpManager:AttemptJump()
	end)
end

return HoverboardController
