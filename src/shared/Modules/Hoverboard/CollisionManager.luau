local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard"):WaitForChild("HoverboardConstants"))


local CollisionManager = {}

function CollisionManager.DetectWallCollision(humanoidRootPart, character, hoverboard, probeDir, currentSpeed, maxSpeed)
	if probeDir.Magnitude == 0 then
		return nil, nil, math.huge
	end

	probeDir = probeDir.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local probeDistance = math.clamp(
		Constants.Collision.PROBE_DISTANCE_MIN + (currentSpeed / maxSpeed) * Constants.Collision.PROBE_DISTANCE_MULTIPLIER,
		Constants.Collision.PROBE_DISTANCE_MIN,
		Constants.Collision.PROBE_DISTANCE_MAX
	)

	local origin = humanoidRootPart.Position + Vector3.new(0, Constants.Collision.PROBE_HEIGHT_OFFSET, 0)

	-- Cast multiple rays for better detection
	local rayDirections = {
		probeDir,
		(probeDir + probeDir:Cross(Vector3.new(0, 1, 0)) * Constants.Collision.RAY_CONE_ANGLE).Unit,
		(probeDir - probeDir:Cross(Vector3.new(0, 1, 0)) * Constants.Collision.RAY_CONE_ANGLE).Unit,
	}

	local wallHit, wallNormal, wallDistance = nil, nil, math.huge

	for _, rayDir in ipairs(rayDirections) do
		local result = workspace:Raycast(origin, rayDir * probeDistance, params)
		if result then
			local dist = (result.Position - origin).Magnitude
			if dist < wallDistance then
				wallDistance = dist
				wallHit = result
				wallNormal = result.Normal
			end
		end
	end

	return wallHit, wallNormal, wallDistance
end

function CollisionManager.HandleWallCollision(humanoidRootPart, wallNormal, wallDistance, moveDir, State, bodyVelocity, bodyGyro, currentSpeed, MOVEMENT, dt)
	local stopDistance = Constants.Collision.STOP_DISTANCE or 3
	local slowDownDistance = Constants.Collision.SLOW_DOWN_DISTANCE or 10
	local slideThreshold = Constants.Collision.SLIDE_START_DISTANCE or 4

	-- Reset if far from wall
	if not wallNormal or wallDistance > slowDownDistance then
		State.isCollidingWithWall = false
		State.collisionNormal = Vector3.zero
		State.collisionRecoveryTimer = 0
		State.inputBlocked = false
		return
	end

	-- Check if moving toward wall
	local isPressingIntoWall = false
	if moveDir and moveDir.Magnitude > 0 then
		local moveDirection = moveDir.Unit
		local dot = moveDirection:Dot(wallNormal)
		isPressingIntoWall = dot < -0.35 -- facing into wall
	end

	-- Maintain state
	State.isCollidingWithWall = wallDistance < Constants.Collision.CLAMP_DISTANCE
	State.collisionNormal = wallNormal
	State.collisionRecoveryTimer += dt

	-- Compute wall tangent (right-hand rule)
	local worldUp = Vector3.new(0, 1, 0)
	local tangent = wallNormal:Cross(worldUp)
	if tangent.Magnitude < 1e-3 then
		tangent = wallNormal:Cross(Vector3.new(1, 0, 0))
	end
	tangent = tangent.Unit

	-- Pick slide direction: whichever is closer to current moveDir
	local tangentLeft = tangent
	local tangentRight = -tangent
	local leftDot = (moveDir or Vector3.zero):Dot(tangentLeft)
	local rightDot = (moveDir or Vector3.zero):Dot(tangentRight)
	local slideDir = (leftDot > rightDot) and tangentLeft or tangentRight

	-- === PHASE 1: Rotate smoothly toward slide direction ===
	if bodyGyro then
		local currentCF = humanoidRootPart.CFrame
		local targetCF = CFrame.lookAt(
			humanoidRootPart.Position,
			humanoidRootPart.Position + slideDir,
			worldUp
		)
		local rotSpeed = 0.5 -- smooth rotation speed
		local rotT = 1 - math.exp(-rotSpeed * dt)
		bodyGyro.CFrame = currentCF:Lerp(targetCF, rotT)
	end

	-- === PHASE 2: Movement handling ===
	if isPressingIntoWall then
		if wallDistance <= slideThreshold then
			-- Begin sliding naturally along wall
			State.inputBlocked = false

			if bodyVelocity then
				local currentVel = humanoidRootPart.AssemblyLinearVelocity
				local targetVel = slideDir * math.clamp(currentSpeed, 30, MOVEMENT.MAX_SPEED)
				targetVel = Vector3.new(targetVel.X, currentVel.Y, targetVel.Z)

				local velSmooth = 1 - math.exp(-4 * dt)
				bodyVelocity.Velocity = currentVel:Lerp(targetVel, velSmooth)
			end
		elseif wallDistance <= stopDistance then
			-- Too close — stop moving forward but allow slow sideways drift
			State.inputBlocked = true

			if bodyVelocity then
				local curVel = humanoidRootPart.AssemblyLinearVelocity
				local sideVel = slideDir * math.min(currentSpeed * 0.3, 8)
				local targetVel = Vector3.new(sideVel.X, curVel.Y, sideVel.Z)
				local velT = 1 - math.exp(-5 * dt)
				bodyVelocity.Velocity = curVel:Lerp(targetVel, velT)
			end
		else
			-- Gently slow down when nearing wall
			if bodyVelocity then
				local curVel = humanoidRootPart.AssemblyLinearVelocity
				local slowFactor = math.clamp((wallDistance - stopDistance) / (slowDownDistance - stopDistance), 0, 1)
				local newVel = curVel * (0.8 + 0.2 * slowFactor)
				local velT = 1 - math.exp(-2 * dt)
				bodyVelocity.Velocity = curVel:Lerp(newVel, velT)
			end
			State.inputBlocked = false
		end
	else
		-- Not pressing into wall → normal movement resumes
		State.inputBlocked = false
	end
end

function CollisionManager.ApplyGentleBackwardForce(humanoidRootPart, wallNormal, bodyGyro, State, dt)
	-- Instead of pushing, rotate smoothly 90° along wall
	local wallTangent = wallNormal:Cross(Vector3.new(0, 1, 0))
	if wallTangent.Magnitude < 1e-3 then return end
	wallTangent = wallTangent.Unit

	local currentCF = humanoidRootPart.CFrame
	local targetCF = CFrame.lookAt(
		humanoidRootPart.Position,
		humanoidRootPart.Position + wallTangent,
		Vector3.new(0, 1, 0)
	)

	local rotT = math.clamp(dt * 8, 0, 1)
	local newRot = currentCF:Lerp(targetCF, rotT)

	if bodyGyro then
		bodyGyro.CFrame = newRot
	end
end

function CollisionManager.CanMoveInDirection(direction, State)
	-- If input is blocked (pressing into wall), no movement
	if State.inputBlocked then
		return false
	end

	if not State.isCollidingWithWall then
		return true
	end

	if direction and direction.Magnitude > 0 then
		local moveDirection = direction.Unit
		local dot = moveDirection:Dot(State.collisionNormal)
		return dot > -0.4 -- allow free sliding along wall
	end

	return true
end

function CollisionManager.UpdateCollisionState(State, dt)
	-- Auto-reset collision state if no recent collisions
	if State.isCollidingWithWall and State.collisionRecoveryTimer > 1.0 then
		State.isCollidingWithWall = false
		State.collisionNormal = Vector3.zero
		State.collisionRecoveryTimer = 0
	end
end

return CollisionManager
