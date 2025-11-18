--// HoverboardMovement.lua

local HoverboardMovement = {}

local MAX_SPEED = 45
local ACCELERATION = 8
local DECELERATION = 20
local MOVEMENT_SMOOTHNESS = 0.1
local MIN_MOVEMENT_THRESHOLD = 0.1
local ROTATION_SPEED = 3500
local ROTATION_SMOOTHNESS = 0.00225
local LEAN_SMOOTH = 5
local MAX_LEAN = 2
local HOVER_HEIGHT = 10
local RAY_DISTANCE = 20
local MAX_BODY_FORCE = 100000
local HOVER_SMOOTHNESS = 8
local ORIENTATION_SMOOTHNESS = 6

local currentVelocity = Vector3.zero
local smoothedLean = 0
local prevYaw = 0

HoverboardMovement.CurrentSpeed = 0

local State = {
	lastMoveDir = Vector3.zero,
	smoothedGroundNormal = Vector3.new(0, 1, 0),
	baseHoverHeight = HOVER_HEIGHT,
	bobTime = 0
}

function HoverboardMovement.CalculateSpeed(Acceleration, Deceleration, targetSpeed, dt, isMoving)
	local rate = isMoving and Acceleration or Deceleration
	local smooth = 1 - math.exp(-rate * MOVEMENT_SMOOTHNESS * dt)
	HoverboardMovement.CurrentSpeed = HoverboardMovement.CurrentSpeed + (targetSpeed - HoverboardMovement.CurrentSpeed) * smooth
	HoverboardMovement.CurrentSpeed = math.clamp(HoverboardMovement.CurrentSpeed, 0, MAX_SPEED)
end

function HoverboardMovement.ApplyVelocity(dt, moveDir, bodyVelocity, humanoidRootPart, currentSpeed)
	if not bodyVelocity then
		return
	end

	local effectiveDir = (currentSpeed > 0) and State.lastMoveDir or Vector3.zero
	local velocity = effectiveDir * currentSpeed
	local currentVel = humanoidRootPart.AssemblyLinearVelocity

	-- Only apply movement if allowed and we have input
	if moveDir.Magnitude > 0 then
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = 1 - math.exp(-20 * dt)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	elseif moveDir.Magnitude == 0 then
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = 1 - math.exp(-20 * dt)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	else
		local currentHorizVel = Vector3.new(currentVel.X, 0, currentVel.Z)
		local slowedHorizVel = currentHorizVel * math.exp(-10 * dt) -- Gradual slowdown
		bodyVelocity.Velocity = Vector3.new(slowedHorizVel.X, currentVel.Y, slowedHorizVel.Z)
	end
end

function HoverboardMovement.HandleMovement(humanoid, rootPart, bodyVelocity, dt)
	if not humanoid then return Vector3.zero end

	local moveDir = humanoid.MoveDirection
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)

	-- Update last movement direction only if actually moving
	if moveDir.Magnitude > MIN_MOVEMENT_THRESHOLD then
		State.lastMoveDir = moveDir.Unit
	end

	-- Calculate target speed with directional modifiers
	local isMoving = moveDir.Magnitude > MIN_MOVEMENT_THRESHOLD
	local targetSpeed = isMoving and MAX_SPEED or 0

	-- Apply speed calculation
	HoverboardMovement.CalculateSpeed(ACCELERATION, DECELERATION, targetSpeed, dt, isMoving)

	-- Stop if speed is very low
	if HoverboardMovement.CurrentSpeed < 0.3 then
		HoverboardMovement.CurrentSpeed = 0
	end

	HoverboardMovement.ApplyVelocity(dt, moveDir, bodyVelocity, rootPart, HoverboardMovement.CurrentSpeed)

	return moveDir
end

function HoverboardMovement.HandleRotation(rootPart, bodyGyro, moveDir, dt)
	if not bodyGyro or not State.lastMoveDir then return end
	if State.lastMoveDir.Magnitude == 0 then return end

	moveDir = State.lastMoveDir
	local candidateNormal = State.smoothedGroundNormal or Vector3.new(0, 1, 0)

	-- 90-degree facing offset (right side)
	local rightVector = candidateNormal:Cross(moveDir).Unit
	local facingDir = rightVector -- facing sideways instead of forward

	if facingDir.Magnitude < 1e-5 then
		facingDir = Vector3.new(0, 0, -1)
	end

	local targetPlayerCFrame =
		CFrame.lookAt(rootPart.Position, rootPart.Position + facingDir, candidateNormal)

	local rotSmooth = 1 - math.exp(-ROTATION_SPEED * ROTATION_SMOOTHNESS * dt) -- exponential smoothing
	local currentCF = bodyGyro.CFrame
	local newRot = (currentCF - currentCF.Position):Lerp(targetPlayerCFrame - targetPlayerCFrame.Position, rotSmooth)
	bodyGyro.CFrame = CFrame.new(rootPart.Position) * newRot
end

local currentLean = 0
function HoverboardMovement.ApplyLeaning(rootPart, hoverboard, moveDir, dt, hoverboardOffset)
	if not hoverboard or not rootPart then return end

	-- Determine turn direction using dot product with right vector
	local right = rootPart.CFrame.RightVector
	local turnAmount = right:Dot(moveDir) -- +1 = turning right, -1 = left

	-- Convert turn amount into a lean angle
	local targetLean = turnAmount * MAX_LEAN

	-- Smooth the lean (spring/exp smoothing)
	local a = 1 - math.exp(-LEAN_SMOOTH * dt)
	smoothedLean = smoothedLean + (targetLean - smoothedLean) * a

	-- Apply leaning (Z-axis rotation)
	local leanCF = CFrame.Angles(-math.rad(smoothedLean), 0, 0)

	-- Apply lean to board
	hoverboard.PrimaryPart.CFrame =
		rootPart.CFrame * leanCF * CFrame.new(hoverboardOffset)

	-- Apply lean visually to player (optional)
	rootPart.CFrame = rootPart.CFrame * leanCF
end

function HoverboardMovement.HandleLeaning(rootPart, hoverboard, dt, hoverboardOffset)
	if not hoverboard or not rootPart then return end

	-- Get angular velocity for smooth lean calculation
	local angularVelocity = rootPart.AssemblyAngularVelocity
	-- Use the Y component (yaw rotation) for leaning
	local yawAngularVelocity = angularVelocity.Y

	-- Convert angular velocity to lean angle (scaled appropriately)
	local targetLean = math.clamp(yawAngularVelocity * 5, -0.5, 0.5)

	-- Very strong smoothing for velocity-based leaning
	local smoothFactor = 1 - math.exp(-LEAN_SMOOTH * 20 * dt)
	smoothedLean = smoothedLean + (targetLean - smoothedLean) * smoothFactor

	-- Apply lean
	--rootPart.CFrame = rootPart.CFrame * CFrame.Angles(-math.rad(smoothedLean), 0, 0)
	hoverboard.PrimaryPart.CFrame = rootPart.CFrame * CFrame.Angles(-math.rad(smoothedLean), 0, 0) * CFrame.new(hoverboardOffset)
	



	





	--if not hoverboard or not rootPart then return end

	--local _, currentYaw, _ = rootPart.CFrame:ToOrientation()
	--local yawDelta = currentYaw - prevYaw
	--prevYaw = currentYaw

	--local targetLean = math.clamp(yawDelta * 500, -MAX_LEAN, MAX_LEAN)
	--smoothedLean = smoothedLean + (targetLean - smoothedLean) * math.clamp(dt * LEAN_SMOOTH, 0, 1)

	--hoverboard.PrimaryPart.CFrame = rootPart.CFrame
	--	* CFrame.new(hoverboardOffset)
	--	* CFrame.Angles(-math.rad(smoothedLean), 0, 0)
end

function HoverboardMovement.UpdateSurfaceAlignment(character, rootPart, bodyGyro, dt)
	if not rootPart then return end

	local origin = rootPart.Position
	local direction = Vector3.new(0, -1, 0) * RAY_DISTANCE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(origin, direction, params)
	if not result then return end

	local surfaceNormal = result.Normal
	local rootForward = rootPart.CFrame.LookVector
	local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, surfaceNormal)

	if forwardProj.Magnitude < 1e-5 then
		forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
		if forwardProj.Magnitude < 1e-5 then
			forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
		end
	end

	local orientSmooth = math.clamp(dt * ORIENTATION_SMOOTHNESS, 0, 1)
	State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)

	local finalNormal = State.smoothedGroundNormal.Unit
	local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)

	if finalForward.Magnitude < 1e-5 then
		finalForward = Vector3.new(0, 0, -1)
	end

	local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + finalForward, finalNormal)

	if bodyGyro then
		local currentOrient = bodyGyro.CFrame
		local currentPos = rootPart.Position
		local lerpT = orientSmooth
		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	end
end

function HoverboardMovement.ProjectVectorOnPlane(vector, planeNormal)
	return vector - planeNormal * vector:Dot(planeNormal)
end

function HoverboardMovement.UpdateHoverboardOrientation(character, hoverboard, rootPart, dt)
	if not hoverboard then return end

	local primary = hoverboard.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local size = primary.Size
	local rayLength = RAY_DISTANCE
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

		local hoverT = math.clamp(1 - math.exp(-HOVER_SMOOTHNESS * dt * 10), 0, 1)
		State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(avgNormal, hoverT)

		HoverboardMovement.AlignHoverboardToSurface(primary, State.smoothedGroundNormal, rootPart, dt)
	end
end

function HoverboardMovement.AlignHoverboardToSurface(primary, surfaceNormal, rootPart, dt)
	local playerForward = rootPart.CFrame.LookVector
	local forwardOnPlane = HoverboardMovement.ProjectVectorOnPlane(playerForward, surfaceNormal)

	if forwardOnPlane.Magnitude < 1e-5 then
		forwardOnPlane = State.lastMoveDir.Magnitude > 0 
			and HoverboardMovement.ProjectVectorOnPlane(State.lastMoveDir, surfaceNormal)
			or Vector3.new(0, 0, -1)
	end
	forwardOnPlane = forwardOnPlane.Unit

	local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, surfaceNormal)
	local primaryT = math.clamp(dt * HOVER_SMOOTHNESS, 0, 1)
	primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)
end

function HoverboardMovement.HandleHovering(character, rootPart, bodyPosition, dt)
	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(rayOrigin, rayDirection, params)

	if result then
		-- Add bobbing effect
		--State.bobTime = State.bobTime + (dt * 1.5)
		--local bobOffset = math.sin(State.bobTime * math.pi * 0.5) * 0.2 -- Subtle bobbing

		-- Normal hover mode
		local targetPos = result.Position + Vector3.new(0, HOVER_HEIGHT, 0)
		--local targetPos = result.Position + Vector3.new(0, State.baseHoverHeight + bobOffset, 0)
		bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
		bodyPosition.Position = targetPos
	else
		-- FALLING / JUMPING → disable hover force
		bodyPosition.MaxForce = Vector3.new(0, 0, 0)
	end
end

-- Turning + Leaning State
local currentRoll = 0
local currentYawOffset = 0

local maxRoll = 4              -- replaces MAX_LEAN
local rollFollowPerSec = 6
local rollReturnPerSec = 8
local turnSpeed = 1.0          -- yaw torque multiplier

-- Smooth side leaning
function HoverboardMovement.UpdateRoll(currentSteer, dt)
	local targetRoll = (currentSteer ~= 0)
		and (-currentSteer * maxRoll)
		or 0

	local rate = (currentSteer ~= 0)
		and rollFollowPerSec
		or rollReturnPerSec

	currentRoll = currentRoll + (targetRoll - currentRoll) * rate * dt
end

-- Smooth yaw turning
function HoverboardMovement.UpdateYaw(currentSteer, dt)
	if currentSteer == 0 then return end

	local yawRate = -math.rad(1.5) * turnSpeed * currentSteer
	currentYawOffset = currentYawOffset + yawRate * dt * 60
end

function HoverboardMovement.HandleHoverboardRotation(rootPart, moveDir, hoverboard, dt, hoverboardOffset)
	-- Determine steer direction using Dot with RIGHT vector
	local right = rootPart.CFrame.RightVector
	local steer = right:Dot(moveDir)    -- +1 = steer right, -1 = steer left

	-- Update roll + yaw
	HoverboardMovement.UpdateRoll(steer, dt)
	HoverboardMovement.UpdateYaw(steer, dt)

	-- Apply 90-degree sideways facing
	local move = (moveDir.Magnitude > 0) and moveDir.Unit or rootPart.CFrame.LookVector
	local up = rootPart.CFrame.UpVector
	local sideways = up:Cross(move).Unit -- always 90 degrees sideways
	local baseCF = CFrame.lookAt(rootPart.Position, rootPart.Position + sideways, up)
	-- Apply yaw + roll
	local yawCF = CFrame.Angles(0, math.rad(currentYawOffset), 0)
	local rollCF = CFrame.Angles(0, 0, math.rad(currentRoll))

	-- Final orientation
	local finalCF = baseCF * yawCF * rollCF

	-- Apply to player
	rootPart.CFrame = finalCF

	-- Apply to hoverboard position + roll
	if hoverboard and hoverboard.PrimaryPart then
		hoverboard.PrimaryPart.CFrame = finalCF * CFrame.new(hoverboardOffset)
	end
end

return HoverboardMovement












----// WORKING HoverboardMovement.lua
--local HoverboardMovement = {}

--local MAX_SPEED = 45
--local ACCELERATION = 8
--local DECELERATION = 20
--local MOVEMENT_SMOOTHNESS = 0.1
--local MIN_MOVEMENT_THRESHOLD = 0.1
--local ROTATION_SPEED = 3500
--local ROTATION_SMOOTHNESS = 0.00225
--local LEAN_SMOOTH = 5
--local MAX_LEAN = 4
--local LEAN_AMOUNT = 2
--local HOVER_HEIGHT = 10
--local RAY_DISTANCE = 20
--local MAX_BODY_FORCE = 100000
--local HOVER_SMOOTHNESS = 8
--local ORIENTATION_SMOOTHNESS = 6
--local MOVE_SPEED = 60

--local currentVelocity = Vector3.zero
--local smoothedLean = 0
--local prevYaw = 0

--HoverboardMovement.CurrentSpeed = 0 

--function HoverboardMovement.HandleMovement(humanoid, rootPart, bodyVelocity, dt)
--	--local camera = workspace.CurrentCamera
--	--local camCF = camera.CFrame
--	--local moveDir = camCF:VectorToWorldSpace(moveVector)
--	--moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)

--	---- Keep the last non-zero move direction for smoother transitions
--	--if moveDir.Magnitude > 0.01 then
--	--	moveDir = moveDir.Unit
--	--	lastMoveDir = moveDir
--	--else
--	--	moveDir = lastMoveDir
--	--end

--	---- Compute target velocity
--	--local hasInput = moveVector.Magnitude > 0.01
--	--local targetVelocity = hasInput and (moveDir * MOVE_SPEED) or Vector3.zero

--	---- Smoothly interpolate between current and target velocities
--	--currentVelocity = currentVelocity:Lerp(
--	--	targetVelocity,
--	--	math.clamp(dt * (hasInput and ACCELERATION or DECELERATION), 0, 1)
--	--)

--	--if bodyVelocity then
--	--	bodyVelocity.Velocity = currentVelocity
--	--end

--	--HoverboardMovement.CurrentSpeed = currentVelocity.Magnitude

--	--return moveDir




--	local moveDir = humanoid.MoveDirection
--	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)

--	local targetVelocity = Vector3.zero
--	if moveDir.Magnitude > 0 then
--		moveDir = moveDir.Unit
--		targetVelocity = moveDir * MOVE_SPEED
--	end

--	currentVelocity = currentVelocity:Lerp(
--		targetVelocity,
--		math.clamp(dt * (moveDir.Magnitude > 0 and ACCELERATION or DECELERATION), 0, 1)
--	)

--	if bodyVelocity then
--		bodyVelocity.Velocity = currentVelocity
--	end

--	HoverboardMovement.CurrentSpeed = currentVelocity.Magnitude

--	return moveDir
--end


--local State = {
--	lastMoveDir = Vector3.zero,
--	smoothedGroundNormal = Vector3.new(0, 1, 0),
--	baseHoverHeight = HOVER_HEIGHT,
--	bobTime = 0
--}


--function HoverboardMovement.HandleRotation(rootPart, bodyGyro, moveDir, dt)
--	if not bodyGyro or moveDir.Magnitude < 0.01 then return end

--	local moveCF = CFrame.lookAt(rootPart.Position, rootPart.Position + moveDir)
--	local targetCF = moveCF * CFrame.Angles(0, math.rad(90), 0)
--	bodyGyro.CFrame = bodyGyro.CFrame:Lerp(targetCF, math.clamp(dt * ROTATION_SMOOTHNESS, 0, 1))
--end

--function HoverboardMovement.HandleLeaning(rootPart, hoverboard, dt, hoverboardOffset)
--	if not hoverboard then return end

--	local _, currentYaw, _ = rootPart.CFrame:ToOrientation()
--	local yawDelta = currentYaw - prevYaw
--	prevYaw = currentYaw

--	local targetLean = math.clamp(yawDelta * 150, -LEAN_AMOUNT, LEAN_AMOUNT)
--	smoothedLean = smoothedLean + (targetLean - smoothedLean) * math.clamp(dt * LEAN_SMOOTH, 0, 1)

--	hoverboard.PrimaryPart.CFrame = rootPart.CFrame
--		* CFrame.new(hoverboardOffset)
--		* CFrame.Angles(-math.rad(smoothedLean), 0, 0)
--end

--function HoverboardMovement.UpdateSurfaceAlignment(character, rootPart, bodyGyro, dt)
--	if not rootPart then return end

--	local origin = rootPart.Position
--	local direction = Vector3.new(0, -1, 0) * RAY_DISTANCE

--	local params = RaycastParams.new()
--	params.FilterType = Enum.RaycastFilterType.Exclude
--	params.FilterDescendantsInstances = {character}

--	local result = workspace:Raycast(origin, direction, params)
--	if not result then return end

--	local surfaceNormal = result.Normal
--	local rootForward = rootPart.CFrame.LookVector
--	local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, surfaceNormal)

--	if forwardProj.Magnitude < 1e-5 then
--		forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
--		if forwardProj.Magnitude < 1e-5 then
--			forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
--		end
--	end

--	local orientSmooth = math.clamp(dt * ORIENTATION_SMOOTHNESS, 0, 1)
--	State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)

--	local finalNormal = State.smoothedGroundNormal.Unit
--	local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)

--	if finalForward.Magnitude < 1e-5 then
--		finalForward = Vector3.new(0, 0, -1)
--	end

--	local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + finalForward, finalNormal)

--	if bodyGyro then
--		local currentOrient = bodyGyro.CFrame
--		local currentPos = rootPart.Position
--		local lerpT = orientSmooth
--		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
--		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
--	end
--end

--function HoverboardMovement.ProjectVectorOnPlane(vector, planeNormal)
--	return vector - planeNormal * vector:Dot(planeNormal)
--end

--function HoverboardMovement.UpdateHoverboardOrientation(character, hoverboard, rootPart, dt)
--	if not hoverboard then return end

--	local primary = hoverboard.PrimaryPart
--	local params = RaycastParams.new()
--	params.FilterType = Enum.RaycastFilterType.Exclude
--	params.FilterDescendantsInstances = {character}

--	local size = primary.Size
--	local rayLength = RAY_DISTANCE
--	local rayOffsets = {
--		Vector3.new(size.X / 2, 0, size.Z / 2),
--		Vector3.new(-size.X / 2, 0, size.Z / 2),
--		Vector3.new(size.X / 2, 0, -size.Z / 2),
--		Vector3.new(-size.X / 2, 0, -size.Z / 2),
--	}

--	local hitPositions, hitNormals = {}, {}

--	for _, offset in ipairs(rayOffsets) do
--		local origin = primary.CFrame:PointToWorldSpace(offset + Vector3.new(0, 0.2, 0))
--		local direction = Vector3.new(0, -rayLength, 0)
--		local result = workspace:Raycast(origin, direction, params)
--		if result then
--			table.insert(hitPositions, result.Position)
--			table.insert(hitNormals, result.Normal)
--		end
--	end

--	if #hitPositions > 0 then
--		local avgPos, avgNormal = Vector3.zero, Vector3.zero
--		for i = 1, #hitPositions do
--			avgPos = avgPos + hitPositions[i]
--			avgNormal = avgNormal + hitNormals[i]
--		end
--		avgPos = avgPos / #hitPositions
--		avgNormal = avgNormal.Unit

--		local hoverT = math.clamp(1 - math.exp(-HOVER_SMOOTHNESS * dt * 10), 0, 1)
--		State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(avgNormal, hoverT)

--		HoverboardMovement.AlignHoverboardToSurface(primary, State.smoothedGroundNormal, rootPart, dt)
--	end
--end

--function HoverboardMovement.AlignHoverboardToSurface(primary, surfaceNormal, rootPart, dt)
--	local playerForward = rootPart.CFrame.LookVector
--	local forwardOnPlane = HoverboardMovement.ProjectVectorOnPlane(playerForward, surfaceNormal)

--	if forwardOnPlane.Magnitude < 1e-5 then
--		forwardOnPlane = State.lastMoveDir.Magnitude > 0 
--			and HoverboardMovement.ProjectVectorOnPlane(State.lastMoveDir, surfaceNormal)
--			or Vector3.new(0, 0, -1)
--	end
--	forwardOnPlane = forwardOnPlane.Unit

--	local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, surfaceNormal)
--	local primaryT = math.clamp(dt * HOVER_SMOOTHNESS, 0, 1)
--	primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)
--end

--function HoverboardMovement.HandleHovering(character, rootPart, bodyPosition, dt)
--	local rayOrigin = rootPart.Position
--	local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0)

--	local params = RaycastParams.new()
--	params.FilterType = Enum.RaycastFilterType.Exclude
--	params.FilterDescendantsInstances = {character}

--	local result = workspace:Raycast(rayOrigin, rayDirection, params)

--	if result then
--		-- Add bobbing effect
--		--State.bobTime = State.bobTime + (dt * 1.5)
--		--local bobOffset = math.sin(State.bobTime * math.pi * 0.5) * 0.2 -- Subtle bobbing

--		-- Normal hover mode
--		local targetPos = result.Position + Vector3.new(0, HOVER_HEIGHT, 0)
--		--local targetPos = result.Position + Vector3.new(0, State.baseHoverHeight + bobOffset, 0)
--		bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
--		bodyPosition.Position = targetPos
--	else
--		-- FALLING / JUMPING → disable hover force
--		bodyPosition.MaxForce = Vector3.new(0, 0, 0)
--	end
--end


--return HoverboardMovement