--// HoverboardMovement.lua

local HoverboardMovement = {}

local currentVelocity = Vector3.zero
local smoothedLean = 0
local prevYaw = 0
local prevMoveDir = nil

HoverboardMovement.CurrentSpeed = 0

function HoverboardMovement.CalculateSpeed(
	Acceleration,
	Deceleration,
	targetSpeed,
	dt,
	isMoving,
	MAX_SPEED,
	MOVEMENT_SMOOTHNESS,
	allowedExceedMax
)
	local rate = isMoving and Acceleration or Deceleration
	-- Ensure minimum rate to prevent movement issues
	local minRate = 0.1
	rate = math.max(rate, minRate)
	local smooth = 1 - math.exp(-rate * MOVEMENT_SMOOTHNESS * dt)
	HoverboardMovement.CurrentSpeed = HoverboardMovement.CurrentSpeed
		+ (targetSpeed - HoverboardMovement.CurrentSpeed) * smooth

	if allowedExceedMax then
		HoverboardMovement.CurrentSpeed = math.clamp(HoverboardMovement.CurrentSpeed, 0, MAX_SPEED)
	end
end

function HoverboardMovement.ApplyVelocity(dt, hrp, moveDir, bodyVelocity, hoverboard, currentSpeed, State)
	if not bodyVelocity or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	local effectiveDir = (currentSpeed > 0) and State.lastMoveDir or Vector3.zero
	local velocity = effectiveDir * currentSpeed
	local currentVel = hoverboard.PrimaryPart.AssemblyLinearVelocity

	-- Only apply movement if allowed and we have input
	if moveDir.Magnitude > 0.1 then
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

function HoverboardMovement.HandleMovement(
	humanoid,
	hrp,
	hoverboard,
	bodyVelocity,
	MAX_SPEED,
	ACCELERATION,
	DECELERATION,
	MOVEMENT_SMOOTHNESS,
	MIN_MOVEMENT_THRESHOLD,
	State,
	isBoosting,
	dt
)
	if not humanoid or not hoverboard or not hoverboard.PrimaryPart then
		return Vector3.zero
	end
	local moveDir = humanoid.MoveDirection
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)

	local isMoving = moveDir.Magnitude > MIN_MOVEMENT_THRESHOLD
	if isMoving and State.lastMoveDir then
		if moveDir:Dot(State.lastMoveDir) < -0.5 then
			HoverboardMovement.CurrentSpeed = 0
		end
	end

	-- Update last movement direction only if actually moving
	if isMoving then
		State.lastMoveDir = moveDir.Unit
	end

	-- Calculate target speed with directional modifiers
	local targetSpeed = isMoving and MAX_SPEED or 0

	-- Apply speed calculation
	HoverboardMovement.CalculateSpeed(
		ACCELERATION,
		DECELERATION,
		targetSpeed,
		dt,
		isMoving,
		MAX_SPEED,
		MOVEMENT_SMOOTHNESS
	)

	-- Stop if speed is very low
	if HoverboardMovement.CurrentSpeed < 0.3 then
		HoverboardMovement.CurrentSpeed = 0
	end

	HoverboardMovement.ApplyVelocity(dt, hrp, moveDir, bodyVelocity, hoverboard, HoverboardMovement.CurrentSpeed, State)

	return moveDir
end

function HoverboardMovement.UpdateOrientation(
	rootPart,
	bodyGyro,
	hoverboard,
	moveDir,
	HoverboardJump,
	SPEED_THRESHOLD,
	ROTATION_SPEED,
	ROTATION_SMOOTHNESS,
	MAX_LEAN,
	LEAN_SMOOTH,
	LEAN_MULTIPLIER,
	State,
	dt
)
	if
		not bodyGyro
		or not hoverboard
		or not hoverboard.PrimaryPart
		or not State.lastMoveDir
		or State.lastMoveDir.Magnitude == 0
	then
		return
	end
	-----------------------------
	-- 1. DETERMINE MOVEMENT STATE
	-----------------------------
	moveDir = State.lastMoveDir
	local speed = HoverboardMovement.CurrentSpeed
	local isMoving = moveDir.Magnitude > 0.1 and speed > SPEED_THRESHOLD -- Additional check for actual movement

	-- Define multipliers based on movement state
	local rotationMultiplier = isMoving and 0.8 or 1 -- 2.5x rotation when still
	ROTATION_SMOOTHNESS = isMoving and 0.2 or ROTATION_SMOOTHNESS
	--LEAN_SMOOTH = isMoving and 50 or LEAN_SMOOTH
	local leanMultiplier = isMoving and 1 or 0.25 -- 1/4 leaning when still

	-----------------------------
	-- 2. ROTATION
	-----------------------------
	local candidateNormal = State.smoothedGroundNormal or Vector3.new(0, 1, 0)

	-- 90-degree facing offset (right side)
	local rightVector = candidateNormal:Cross(moveDir).Unit
	local facingDir = rightVector -- facing sideways instead of forward

	if facingDir.Magnitude < 1e-5 then
		facingDir = Vector3.new(0, 0, -1)
	end

	local primary = hoverboard.PrimaryPart
	local targetPlayerCFrame = CFrame.lookAt(primary.Position, primary.Position + facingDir, candidateNormal)

	-- Apply rotation multiplier based on movement state
	local adjustedRotation = ROTATION_SPEED * rotationMultiplier
	local rotSmooth = 1 - math.exp(-adjustedRotation * ROTATION_SMOOTHNESS * dt) -- exponential smoothing
	local currentCF = bodyGyro.CFrame
	local newRot = (currentCF - currentCF.Position):Lerp(targetPlayerCFrame - targetPlayerCFrame.Position, rotSmooth)

	-----------------------------
	-- 3. LEANING
	-----------------------------
	local grounded = HoverboardJump.IsGrounded()
	if grounded and not HoverboardJump.IsJumping then
		local _, currentYaw, _ = rootPart.CFrame:ToOrientation()
		local yawDelta = currentYaw - prevYaw
		prevYaw = currentYaw

		-- Apply lean multiplier based on movement state
		if yawDelta ~= 0 then
			local adjustedLean = yawDelta * LEAN_MULTIPLIER * leanMultiplier
			adjustedLean = math.clamp(adjustedLean, -MAX_LEAN, MAX_LEAN)
			local leanT = 1 - math.exp(-50 * dt)
			smoothedLean = smoothedLean + (adjustedLean - smoothedLean) * leanT

			-- Apply lean to rotation
			newRot = newRot * CFrame.Angles(-math.rad(smoothedLean), 0, 0)
		end
	else
		smoothedLean = smoothedLean * 0.85
	end

	-----------------------------
	-- 4. UPDATE PLAYER ORIENTATION
	-----------------------------
	if bodyGyro then
		bodyGyro.CFrame = CFrame.new(primary.Position) * newRot
	end
end

function HoverboardMovement.UpdateSurfaceAlignment(
	character,
	rootPart,
	bodyGyro,
	RAY_DISTANCE,
	ORIENTATION_SMOOTHNESS,
	State,
	HoverboardJump,
	hoverboard,
	dt
)
	if not rootPart or not hoverboard or not hoverboard.PrimaryPart or not HoverboardJump.IsGrounded() then
		return
	end
	local primaryPart = hoverboard.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	-- Cast multiple rays for better surface detection
	local rayOrigins = {
		primaryPart.Position + Vector3.new(0, 0, 0),
		primaryPart.Position + Vector3.new(2, 0, 0),
		primaryPart.Position + Vector3.new(-2, 0, 0),
		primaryPart.Position + Vector3.new(0, 0, 2),
		primaryPart.Position + Vector3.new(0, 0, -2),
	}

	local hitNormals = {}
	local hitCount = 0

	for _, origin in ipairs(rayOrigins) do
		local direction = Vector3.new(0, -RAY_DISTANCE, 0)
		local result = workspace:Raycast(origin, direction, params)
		if result then
			table.insert(hitNormals, result.Normal)
			hitCount = hitCount + 1
		end
	end

	if hitCount == 0 then
		return
	end

	-- Calculate average normal from all hits
	local avgNormal = Vector3.zero
	for _, normal in ipairs(hitNormals) do
		avgNormal = avgNormal + normal
	end
	avgNormal = (avgNormal / hitCount).Unit

	local rootForward = primaryPart.CFrame.LookVector
	local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, avgNormal)

	if forwardProj.Magnitude < 1e-5 then
		forwardProj = avgNormal:Cross(Vector3.new(0, 0, 1))
		if forwardProj.Magnitude < 1e-5 then
			forwardProj = avgNormal:Cross(Vector3.new(0, 1, 0))
		end
	end

	--local orientSmooth = math.clamp(dt * ORIENTATION_SMOOTHNESS, 0, 1)
	local orientSmooth = 1 - math.exp(-ORIENTATION_SMOOTHNESS * dt)

	-- Initialize smoothed normal if needed
	if not State.smoothedGroundNormal then
		State.smoothedGroundNormal = avgNormal
	else
		State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(avgNormal, orientSmooth)
	end

	local finalNormal = State.smoothedGroundNormal.Unit
	local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)

	if finalForward.Magnitude < 1e-5 then
		finalForward = Vector3.new(0, 0, -1)
	else
		finalForward = finalForward.Unit
	end

	local targetCFrame = CFrame.lookAt(primaryPart.Position, primaryPart.Position + finalForward, finalNormal)

	if bodyGyro then
		local currentOrient = bodyGyro.CFrame
		local currentPos = primaryPart.Position
		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, orientSmooth)
		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	end





	-- if not rootPart or not hoverboard or not hoverboard.PrimaryPart then return end

	-- local origin = hoverboard.PrimaryPart.Position
	-- local direction = Vector3.new(0, -1, 0) * RAY_DISTANCE

	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character }

	-- local result = workspace:Raycast(origin, direction, params)
	-- if not result then
	-- 	return
	-- end

	-- local surfaceNormal = result.Normal
	-- local rootForward = hoverboard.PrimaryPart.CFrame.LookVector
	-- local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, surfaceNormal)

	-- if forwardProj.Magnitude < 1e-5 then
	-- 	forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
	-- 	if forwardProj.Magnitude < 1e-5 then
	-- 		forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
	-- 	end
	-- end

	-- local orientSmooth = math.clamp(dt * ORIENTATION_SMOOTHNESS, 0, 1)
	-- State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)

	-- local finalNormal = State.smoothedGroundNormal.Unit
	-- local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)

	-- if finalForward.Magnitude < 1e-5 then
	-- 	finalForward = Vector3.new(0, 0, -1)
	-- end

	-- local targetCFrame = CFrame.lookAt(hoverboard.PrimaryPart.Position, hoverboard.PrimaryPart.Position + finalForward, finalNormal)

	-- if bodyGyro then
	-- 	local currentOrient = bodyGyro.CFrame
	-- 	local currentPos = hoverboard.PrimaryPart.Position
	-- 	local lerpT = orientSmooth
	-- 	local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
	-- 	bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	-- end
end

function HoverboardMovement.UpdateBoardAlignment(
	rootPart,
	hoverboard,
	HOVER_HEIGHT,
	HOVER_SMOOTHNESS,
	ORIENTATION_SMOOTHNESS,
	dt
)
	if not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	local boardCF = hoverboard.PrimaryPart.CFrame
	local halfSize = hoverboard.PrimaryPart.Size * 0.5

	-- Ray origin offsets (4 corners)
	local offsets = {
		Vector3.new( halfSize.X, 0,  halfSize.Z),
		Vector3.new(-halfSize.X, 0,  halfSize.Z),
		Vector3.new( halfSize.X, 0, -halfSize.Z),
		Vector3.new(-halfSize.X, 0, -halfSize.Z),
	}

	local normalSum = Vector3.zero
	local bestDistance = math.huge
	local bestPosition

	--------------------------------------------
	-- 4-Corner RAYCAST - strongest + optimized
	--------------------------------------------
	for _, offset in ipairs(offsets) do
		local origin = boardCF:PointToWorldSpace(offset + Vector3.new(0, 3, 0))
		local result = workspace:Raycast(origin, Vector3.new(0, -15, 0))

		if result then
			normalSum = normalSum + result.Normal

			if result.Distance < bestDistance then
				bestDistance = result.Distance
				bestPosition = result.Position
			end
		end
	end

	--------------------------------------------
	-- If no ground detected → keep current tilt
	--------------------------------------------
	if bestDistance == math.huge then
		return
	end

	--------------------------------------------
	-- 1. Compute averaged surface normal
	--------------------------------------------
	local avgNormal = normalSum.Unit

	--------------------------------------------
	-- 2. Compute target hover position
	--------------------------------------------
	local targetPos = bestPosition + (avgNormal * HOVER_HEIGHT)

	--------------------------------------------
	-- 3. Smooth vertical hover height
	--------------------------------------------
	local hoverT = 1 - math.exp(-HOVER_SMOOTHNESS * dt)
	local newPos = hoverboard.PrimaryPart.Position:Lerp(targetPos, hoverT)

	--------------------------------------------
	-- 4. Compute new orientation based on avgNormal
	--------------------------------------------
	local forward = boardCF.LookVector
	forward = forward - forward:Dot(avgNormal) * avgNormal
	forward = forward.Magnitude > 0.01 and forward.Unit or boardCF.LookVector

	local targetCFrame = CFrame.lookAt(newPos, newPos + forward, avgNormal)

	--------------------------------------------
	-- 5. Smooth the final CFrame (position + rotation)
	--------------------------------------------
	local orientT = 1 - math.exp(-ORIENTATION_SMOOTHNESS * dt)
	local finalCF = boardCF:Lerp(targetCFrame, orientT)

	hoverboard:PivotTo(finalCF)
end



function HoverboardMovement.ProjectVectorOnPlane(vector, planeNormal)
	return vector - planeNormal * vector:Dot(planeNormal)
end

function HoverboardMovement.UpdateHoverboardOrientation(
	character,
	hoverboard,
	rootPart,
	RAY_DISTANCE,
	HOVER_SMOOTHNESS,
	State,
	dt
)
	if not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	local primary = hoverboard.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

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

		HoverboardMovement.AlignHoverboardToSurface(
			primary,
			State.smoothedGroundNormal,
			rootPart,
			HOVER_SMOOTHNESS,
			State,
			dt
		)
	end
end

function HoverboardMovement.AlignHoverboardToSurface(primary, surfaceNormal, rootPart, HOVER_SMOOTHNESS, State, dt)
	if not rootPart then
		return
	end
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
	if primary then
		primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)
	end
end

function HoverboardMovement.HandleHovering(
	character,
	rootPart,
	bodyPosition,
	hoverboard,
	RAY_DISTANCE,
	HOVER_HEIGHT,
	MAX_BODY_FORCE,
	HoverboardJump,
	dt
)
	if not rootPart or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	if not HoverboardJump.IsGrounded() then
		print("Not grounded")
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local primary = hoverboard.PrimaryPart
	local primarySize = primary.Size

	-- Cast rays from multiple points on the hoverboard
	local rayOffsets = {
		Vector3.new(primarySize.X / 2, 0.5, primarySize.Z / 2), -- Front-right
		Vector3.new(-primarySize.X / 2, 0.5, primarySize.Z / 2), -- Front-left
		Vector3.new(primarySize.X / 2, 0.5, -primarySize.Z / 2), -- Back-right
		Vector3.new(-primarySize.X / 2, 0.5, -primarySize.Z / 2), -- Back-left
		Vector3.new(0, 0.5, 0), -- Center
	}

	local hitPositions = {}
	local hitDistances = {}
	local hitNormals = {}

	-- Cast all rays
	for _, offset in ipairs(rayOffsets) do
		local worldOffset = primary.CFrame:PointToWorldSpace(offset)
		local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0)
		local result = workspace:Raycast(worldOffset, rayDirection, params)

		if result then
			table.insert(hitPositions, result.Position)
			table.insert(hitDistances, math.abs(worldOffset.Y - result.Position.Y))
			table.insert(hitNormals, result.Normal)
		end
	end

	if #hitPositions > 0 then
		-- Find the highest ground point (lowest Y position since Y goes down)
		local highestGroundY = -math.huge
		local avgGroundPos = Vector3.zero
		local avgNormal = Vector3.zero

		for i, pos in ipairs(hitPositions) do
			if pos.Y > highestGroundY then
				highestGroundY = pos.Y
			end
			avgGroundPos = avgGroundPos + pos
			avgNormal = avgNormal + hitNormals[i]
		end

		avgGroundPos = avgGroundPos / #hitPositions
		avgNormal = avgNormal.Unit

		-- Calculate target position with proper hover height
		--local currentPos = rootPart.Position
		local currentPos = hoverboard.PrimaryPart.Position
		local targetY = highestGroundY + HOVER_HEIGHT

		-- Only adjust Y position if we're within reasonable distance
		local currentHeight = currentPos.Y
		local heightDiff = math.abs(currentHeight - targetY)

		if heightDiff > 0.1 then
			local smoothFactor = math.clamp(1 - math.exp(-8 * dt), 0, 1)
			local smoothedY = currentHeight + (targetY - currentHeight) * smoothFactor

			bodyPosition.Position = Vector3.new(currentPos.X, smoothedY, currentPos.Z)
			bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
		else
			bodyPosition.Position = Vector3.new(currentPos.X, targetY, currentPos.Z)
			bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
		end
	else
		-- No ground detected, maintain current height with reduced force
		bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	end

	-- if not rootPart then
	-- 	return
	-- end

	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character }

	-- -- Cast rays in 4 cardinal directions + center
	-- local rayOrigins = {
	-- 	rootPart.Position,
	-- 	rootPart.Position + rootPart.CFrame.RightVector * 2,
	-- 	rootPart.Position - rootPart.CFrame.RightVector * 2,
	-- 	rootPart.Position + rootPart.CFrame.LookVector * 2,
	-- 	rootPart.Position - rootPart.CFrame.LookVector * 2,
	-- }

	-- local highestGround = nil
	-- local highestY = -math.huge

	-- for _, origin in ipairs(rayOrigins) do
	-- 	local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0)
	-- 	local result = workspace:Raycast(origin, rayDirection, params)

	-- 	if result and result.Position.Y > highestY then
	-- 		highestY = result.Position.Y
	-- 		highestGround = result.Position
	-- 	end
	-- end

	-- if highestGround then
	-- 	local targetPos = Vector3.new(rootPart.Position.X, highestGround.Y + HOVER_HEIGHT, rootPart.Position.Z)
	-- 	bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	-- 	bodyPosition.Position = targetPos
	-- else
	-- 	bodyPosition.MaxForce = Vector3.new(0, 0, 0)
	-- end
end

return HoverboardMovement
