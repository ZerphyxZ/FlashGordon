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
			local leanT = 1 - math.exp(-20 * dt)
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

function HoverboardMovement.UpdateSurfaceAlignment1(
	character,
	rootPart,
	bodyGyro,
	RAY_DISTANCE,
	ORIENTATION_SMOOTHNESS,
	State,
	HoverboardJump,
	hoverboard,
	HOVER_HEIGHT,
	dt
)
	if not rootPart or not character or not HoverboardJump.IsGrounded() then
        return
    end

    local charPos = rootPart.Position

    -- Prepare raycast params
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, hoverboard }

    ------------------------------------------------------
    -- 1) MULTI-RAY SURFACE DETECTION FROM CHARACTER —
    ------------------------------------------------------

    local rayOrigins = {
        charPos,
        charPos + Vector3.new(2, 0, 0),
        charPos + Vector3.new(-2, 0, 0),
        charPos + Vector3.new(0, 0, 2),
        charPos + Vector3.new(0, 0, -2),
    }

    local hitNormals = {}
    local hitCount = 0

    for _, origin in ipairs(rayOrigins) do
        local result = workspace:Raycast(origin, Vector3.new(0, -RAY_DISTANCE, 0), params)
        if result then
            hitCount = hitCount + 1
            table.insert(hitNormals, result.Normal)
        end
    end


    ------------------------------------------------------
    -- 2) AVERAGE SURFACE NORMAL
    ------------------------------------------------------

    local avgNormal = Vector3.zero
    for _, normal in ipairs(hitNormals) do
        avgNormal = avgNormal + normal
    end
    avgNormal = (avgNormal / hitCount).Unit

    ------------------------------------------------------
    -- 3) SMOOTH THE GROUND NORMAL
    ------------------------------------------------------

    local orientSmooth = 1 - math.exp(-ORIENTATION_SMOOTHNESS * dt)

    if not State.smoothedGroundNormal then
        State.smoothedGroundNormal = avgNormal
    else
        State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(avgNormal, orientSmooth)
    end

    local finalNormal = State.smoothedGroundNormal.Unit

    ------------------------------------------------------
    -- 4) DETERMINE CHARACTER FORWARD DIRECTION ON SLOPE
    ------------------------------------------------------

    local rootForward = rootPart.CFrame.LookVector
    local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, finalNormal)

    if forwardProj.Magnitude < 1e-5 then
        forwardProj = finalNormal:Cross(Vector3.new(0, 0, 1))
        if forwardProj.Magnitude < 1e-5 then
            forwardProj = finalNormal:Cross(Vector3.new(0, 1, 0))
        end
    end

    forwardProj = forwardProj.Unit

    ------------------------------------------------------
    -- 5) APPLY FINAL ROTATION TO CHARACTER (not hoverboard)
    ------------------------------------------------------

    local targetCFrame = CFrame.lookAt(
        rootPart.Position,
        rootPart.Position + forwardProj,
        finalNormal
    )

	local current = rootPart.CFrame
    local newRot = current:ToObjectSpace(current):Lerp(
        current:ToObjectSpace(targetCFrame),
        orientSmooth
    )

    rootPart.CFrame = CFrame.new(rootPart.Position) * newRot

    -- if bodyGyro then
    --     local current = bodyGyro.CFrame
    --     local newRot = (current - current.Position):Lerp(targetCFrame - targetCFrame.Position, orientSmooth)
    --     bodyGyro.CFrame = CFrame.new(rootPart.Position) * newRot
    -- end





	-- if not rootPart or not hoverboard or not hoverboard.PrimaryPart or not HoverboardJump.IsGrounded() then
	-- 	return
	-- end
	-- local primaryPart = hoverboard.PrimaryPart
	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character }

	-- -- Cast multiple rays for better surface detection
	-- local size = primaryPart.Size
	-- local rayOrigins = {
	-- 	primaryPart.Position + Vector3.new(size.X / 2, 0, size.Z / 2),
	-- 	primaryPart.Position + Vector3.new(-size.X / 2, 0, size.Z / 2),
	-- 	primaryPart.Position + Vector3.new(size.X / 2, 0, -size.Z / 2),
	-- 	primaryPart.Position + Vector3.new(-size.X / 2, 0, -size.Z / 2),



	-- 	-- primaryPart.Position + Vector3.new(0, 0, 0),
	-- 	-- primaryPart.Position + Vector3.new(5, 0, 0),
	-- 	-- primaryPart.Position + Vector3.new(-5, 0, 0),
	-- 	-- primaryPart.Position + Vector3.new(0, 0, 5),
	-- 	-- primaryPart.Position + Vector3.new(0, 0, -5),
	-- }

	-- local hitNormals = {}
	-- local hitCount = 0

	-- for _, origin in ipairs(rayOrigins) do
	-- 	local direction = Vector3.new(0, -RAY_DISTANCE, 0)
	-- 	local result = workspace:Raycast(origin, direction, params)
	-- 	if result then
	-- 		table.insert(hitNormals, result.Normal)
	-- 		hitCount = hitCount + 1
	-- 	end
	-- end

	-- if hitCount == 0 then
	-- 	return
	-- end

	-- -- Calculate average normal from all hits
	-- local avgNormal = Vector3.zero
	-- for _, normal in ipairs(hitNormals) do
	-- 	avgNormal = avgNormal + normal
	-- end
	-- avgNormal = (avgNormal / hitCount).Unit

	-- local rootForward = primaryPart.CFrame.LookVector
	-- local forwardProj = HoverboardMovement.ProjectVectorOnPlane(rootForward, avgNormal)

	-- if forwardProj.Magnitude < 1e-5 then
	-- 	forwardProj = avgNormal:Cross(Vector3.new(0, 0, 1))
	-- 	if forwardProj.Magnitude < 1e-5 then
	-- 		forwardProj = avgNormal:Cross(Vector3.new(0, 1, 0))
	-- 	end
	-- end

	-- --local orientSmooth = math.clamp(dt * ORIENTATION_SMOOTHNESS, 0, 1)
	-- local orientSmooth = 1 - math.exp(-ORIENTATION_SMOOTHNESS * dt)

	-- -- Initialize smoothed normal if needed
	-- if not State.smoothedGroundNormal then
	-- 	State.smoothedGroundNormal = avgNormal
	-- else
	-- 	State.smoothedGroundNormal = State.smoothedGroundNormal:Lerp(avgNormal, orientSmooth)
	-- end

	-- local finalNormal = State.smoothedGroundNormal.Unit
	-- local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)

	-- if finalForward.Magnitude < 1e-5 then
	-- 	finalForward = Vector3.new(0, 0, -1)
	-- else
	-- 	finalForward = finalForward.Unit
	-- end

	-- local targetCFrame = CFrame.lookAt(primaryPart.Position, primaryPart.Position + finalForward, finalNormal)

	-- if bodyGyro then
	-- 	local currentOrient = bodyGyro.CFrame
	-- 	local currentPos = primaryPart.Position
	-- 	local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, orientSmooth)
	-- 	bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	-- end
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
		Vector3.new(size.X / 2, 0.2, size.Z / 2),
		Vector3.new(-size.X / 2, 0.2, size.Z / 2),
		Vector3.new(size.X / 2, 0.2, -size.Z / 2),
		Vector3.new(-size.X / 2, 0.2, -size.Z / 2),
		Vector3.new(0, 0.2, 0)
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
	HOVER_SMOOTHNESS,
	MAX_BODY_FORCE,
	HoverboardJump,
	State,
	dt
)
	if not hoverboard or not hoverboard.PrimaryPart or HoverboardJump.State.isJumping then
		return
	end

	local primary = hoverboard.PrimaryPart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

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

		local hoverT = math.clamp(1 - math.exp(-HOVER_SMOOTHNESS * dt), 0, 1)
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
		local targetY = avgPos.Y + State.baseHoverHeight --+ bobOffset
		-- ========== END UPDATED CODE ==========

		if bodyPosition then
			local currentBP = bodyPosition.Position
			local targetBP = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
			local posT = math.clamp(dt * 10, 0, 1)
			bodyPosition.Position = currentBP:Lerp(targetBP, posT)
		end
	else
		if bodyPosition then
			bodyPosition.MaxForce = Vector3.zero
		end
	end






	-- if not rootPart or not hoverboard or not hoverboard.PrimaryPart then
	-- 	return
	-- end

	-- if not HoverboardJump.IsGrounded() then
	-- 	print("Not grounded")
	-- end

	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character, hoverboard }

	-- local primary = hoverboard.PrimaryPart
	-- local primarySize = primary.Size

	-- -- Cast rays from multiple points on the hoverboard
	-- local rayOffsets = {
	-- 	Vector3.new(primarySize.X / 2, 0.5, primarySize.Z / 2), -- Front-right
	-- 	Vector3.new(-primarySize.X / 2, 0.5, primarySize.Z / 2), -- Front-left
	-- 	Vector3.new(primarySize.X / 2, 0.5, -primarySize.Z / 2), -- Back-right
	-- 	Vector3.new(-primarySize.X / 2, 0.5, -primarySize.Z / 2), -- Back-left
	-- 	Vector3.new(0, 0.5, 0), -- Center
	-- }

	-- local hitPositions = {}
	-- local hitDistances = {}
	-- local hitNormals = {}

	-- -- Cast all rays
	-- for _, offset in ipairs(rayOffsets) do
	-- 	local worldOffset = primary.CFrame:PointToWorldSpace(offset)
	-- 	local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0)
	-- 	local result = workspace:Raycast(worldOffset, rayDirection, params)

	-- 	if result then
	-- 		table.insert(hitPositions, result.Position)
	-- 		table.insert(hitDistances, math.abs(worldOffset.Y - result.Position.Y))
	-- 		table.insert(hitNormals, result.Normal)
	-- 	end
	-- end

	-- if #hitPositions > 0 then
	-- 	-- Find the highest ground point (lowest Y position since Y goes down)
	-- 	local highestGroundY = -math.huge
	-- 	local avgGroundPos = Vector3.zero
	-- 	local avgNormal = Vector3.zero

	-- 	for i, pos in ipairs(hitPositions) do
	-- 		if pos.Y > highestGroundY then
	-- 			highestGroundY = pos.Y
	-- 		end
	-- 		avgGroundPos = avgGroundPos + pos
	-- 		avgNormal = avgNormal + hitNormals[i]
	-- 	end

	-- 	avgGroundPos = avgGroundPos / #hitPositions
	-- 	avgNormal = avgNormal.Unit

	-- 	-- Calculate target position with proper hover height
	-- 	--local currentPos = rootPart.Position
	-- 	local currentPos = hoverboard.PrimaryPart.Position
	-- 	local targetY = highestGroundY + HOVER_HEIGHT

	-- 	-- Only adjust Y position if we're within reasonable distance
	-- 	local currentHeight = currentPos.Y
	-- 	local heightDiff = math.abs(currentHeight - targetY)

	-- 	if heightDiff > 0.1 then
	-- 		local smoothFactor = math.clamp(1 - math.exp(-8 * dt), 0, 1)
	-- 		local smoothedY = currentHeight + (targetY - currentHeight) * smoothFactor

	-- 		bodyPosition.Position = Vector3.new(currentPos.X, smoothedY, currentPos.Z)
	-- 		bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	-- 	else
	-- 		bodyPosition.Position = Vector3.new(currentPos.X, targetY, currentPos.Z)
	-- 		bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	-- 	end
	-- else
	-- 	-- No ground detected, maintain current height with reduced force
	-- 	bodyPosition.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	-- end
end


function HoverboardMovement.AlignCharacterToSurface(
    character,
    rootPart,
    bodyGyro,
    ORIENTATION_SMOOTHNESS,
    State,
    HoverboardJump,
    dt
)
    if not rootPart or not bodyGyro then
        return
    end
    
    -- Use single source: IsGrounded()
    local grounded, groundPos, surfaceNormal = HoverboardJump.IsGrounded()
    if not grounded then
        return
    end
    
    -- Determine forward direction based on player input or look direction
    local forwardDir
    if State.lastMoveDir and State.lastMoveDir.Magnitude > 0.1 then
        -- Use movement input direction
        forwardDir = State.lastMoveDir.Unit
    else
        -- Use character's look direction (flattened)
        local lookVec = rootPart.CFrame.LookVector
        forwardDir = Vector3.new(lookVec.X, 0, lookVec.Z)
        if forwardDir.Magnitude < 0.1 then
            forwardDir = Vector3.new(0, 0, -1)
        else
            forwardDir = forwardDir.Unit
        end
    end
    
    -- Project forward onto surface plane
    local forwardProj = HoverboardMovement.ProjectVectorOnPlane(forwardDir, surfaceNormal)
    
    -- Fallback if projection fails
    if forwardProj.Magnitude < 1e-5 then
        forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
        if forwardProj.Magnitude < 1e-5 then
            forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
        end
    end
    
    -- Calculate smoothing
    local surfaceSteepness = 1 - math.abs(surfaceNormal.Y)
    local adaptiveSmoothness = ORIENTATION_SMOOTHNESS
    
    -- Faster response on steep slopes
    if surfaceSteepness > 0.3 then
        adaptiveSmoothness = ORIENTATION_SMOOTHNESS * 2
    end
    
    local orientSmooth = 1 - math.exp(-adaptiveSmoothness * dt)
    
    -- Initialize or update smoothed normal
    if not State.charSmoothedNormal then
        State.charSmoothedNormal = surfaceNormal
    else
        State.charSmoothedNormal = State.charSmoothedNormal:Lerp(surfaceNormal, orientSmooth)
    end
    
    local finalNormal = State.charSmoothedNormal.Unit
    local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardDir, finalNormal)
    
    if finalForward.Magnitude < 1e-5 then
        finalForward = Vector3.new(0, 0, -1)
    else
        finalForward = finalForward.Unit
    end
    
    -- Create target CFrame
    local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + finalForward, finalNormal)
    
    -- Apply to BodyGyro
    local currentRot = bodyGyro.CFrame - bodyGyro.CFrame.Position
    local targetRot = targetCFrame - targetCFrame.Position
    local finalRot = currentRot:Lerp(targetRot, orientSmooth)
    
    bodyGyro.CFrame = CFrame.new(rootPart.Position) * finalRot
end

function HoverboardMovement.AlignHoverboardModel(
    character,
    hoverboard,
    ORIENTATION_SMOOTHNESS,
    State,
    HoverboardJump,
    HOVER_HEIGHT,
    dt
)
    if not hoverboard or not hoverboard.PrimaryPart then
        return
    end
    
    local primary = hoverboard.PrimaryPart
    
    -- Use corner raycasting for hoverboard (more stable than single point)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    
    local size = primary.Size
    local rayLength = HOVER_HEIGHT * 3
    local rayOffsets = {
        Vector3.new(size.X / 2, 0.2, size.Z / 2),    -- Front-right
        Vector3.new(-size.X / 2, 0.2, size.Z / 2),   -- Front-left
        Vector3.new(size.X / 2, 0.2, -size.Z / 2),   -- Back-right
        Vector3.new(-size.X / 2, 0.2, -size.Z / 2),  -- Back-left
        Vector3.new(0, 0.2, 0),                      -- Center
    }
    
    local hitPositions = {}
    local hitNormals = {}
    
    for _, offset in ipairs(rayOffsets) do
        local origin = primary.CFrame:PointToWorldSpace(offset)
        local direction = Vector3.new(0, -rayLength, 0)
        local result = workspace:Raycast(origin, direction, params)
        
        if result then
            table.insert(hitPositions, result.Position)
            table.insert(hitNormals, result.Normal)
        end
    end
    
    if #hitNormals == 0 then
        return  -- No ground detected
    end
    
    -- Calculate weighted average (center ray has more weight)
    local avgNormal = Vector3.zero
    local avgPosition = Vector3.zero
    
    for i = 1, #hitNormals do
        local weight = (i == 5) and 2.0 or 1.0  -- Center ray has double weight
        avgNormal = avgNormal + (hitNormals[i] * weight)
        avgPosition = avgPosition + (hitPositions[i] * weight)
    end
    
    avgNormal = (avgNormal / (#hitNormals + 1)).Unit  -- +1 for extra center weight
    avgPosition = avgPosition / (#hitPositions + 1)
    
    -- Get hoverboard's current forward direction
    local boardForward = primary.CFrame.LookVector
    
    -- Project forward onto surface plane
    local forwardProj = HoverboardMovement.ProjectVectorOnPlane(boardForward, avgNormal)
    
    -- Fallback if projection fails
    if forwardProj.Magnitude < 1e-5 then
        forwardProj = avgNormal:Cross(Vector3.new(0, 0, 1))
        if forwardProj.Magnitude < 1e-5 then
            forwardProj = avgNormal:Cross(Vector3.new(0, 1, 0))
        end
    end
    
    -- Calculate smoothing
    local surfaceSteepness = 1 - math.abs(avgNormal.Y)
    local adaptiveSmoothness = ORIENTATION_SMOOTHNESS
    
    -- Very fast response for hoverboard (should match surface exactly)
    if surfaceSteepness > 0.2 then  -- ~78° or steeper
        adaptiveSmoothness = ORIENTATION_SMOOTHNESS * 5  -- 5x faster
    end
    
    local boardSmooth = 1 - math.exp(-adaptiveSmoothness * dt)
    
    -- Initialize or update board smoothed normal
    if not State.boardSmoothedNormal then
        State.boardSmoothedNormal = avgNormal
    else
        -- Instant update for large changes
        local angleDiff = math.deg(math.acos(math.clamp(
            State.boardSmoothedNormal:Dot(avgNormal), -1, 1
        )))
        
        if angleDiff > 20 then
            boardSmooth = 1.0  -- Instant alignment
        end
        
        State.boardSmoothedNormal = State.boardSmoothedNormal:Lerp(avgNormal, boardSmooth)
    end
    
    local finalNormal = State.boardSmoothedNormal.Unit
    local finalForward = HoverboardMovement.ProjectVectorOnPlane(forwardProj, finalNormal)
    
    if finalForward.Magnitude < 1e-5 then
        finalForward = Vector3.new(0, 0, -1)
    else
        finalForward = finalForward.Unit
    end
    
    -- Create target CFrame for hoverboard
    local targetCFrame = CFrame.lookAt(primary.Position, primary.Position + finalForward, finalNormal)
    
    -- Adjust height based on average ground position
    local targetHeight = avgPosition.Y + HOVER_HEIGHT
    local heightDiff = targetHeight - primary.Position.Y
    
    -- Combine rotation with height adjustment
    if math.abs(heightDiff) > 0.05 then
        local heightSmooth = 1 - math.exp(-30 * dt)
        local newY = primary.Position.Y + (heightDiff * heightSmooth)
        
        -- Apply with height
        local targetPos = Vector3.new(primary.Position.X, newY, primary.Position.Z)
        local targetRot = targetCFrame - targetCFrame.Position
        primary.CFrame = CFrame.new(targetPos) * primary.CFrame.Rotation:Lerp(targetRot, boardSmooth)
    else
        -- Apply rotation only
        primary.CFrame = primary.CFrame:Lerp(targetCFrame, boardSmooth)
    end
    
    -- DEBUG: Uncomment to see board alignment
    -- local boardAngle = math.deg(math.acos(finalNormal.Y))
    -- print(string.format("Hoverboard aligned: %.1f° (Height diff: %.2f)", boardAngle, heightDiff))
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
    HOVER_HEIGHT,
    dt
)
    -- Only align when grounded
    if not HoverboardJump.IsGrounded() then
        return
    end
    
    -- Align CHARACTER (uses BodyGyro)
    HoverboardMovement.AlignCharacterToSurface(
        character,
        rootPart,
        bodyGyro,
        ORIENTATION_SMOOTHNESS,
        State,
        HoverboardJump,
        dt
    )
    
    -- Align HOVERBOARD MODEL (direct CFrame manipulation)
    HoverboardMovement.AlignHoverboardModel(
        character,
        hoverboard,
        ORIENTATION_SMOOTHNESS * 1.5,  -- Slightly faster for board
        State,
        HoverboardJump,
        HOVER_HEIGHT,
        dt
    )
end


return HoverboardMovement
