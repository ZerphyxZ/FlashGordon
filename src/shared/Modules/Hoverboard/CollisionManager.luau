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

	-- Reset if no nearby wall
	if not wallNormal or wallDistance > Constants.Collision.SLOW_DOWN_DISTANCE then
		State.isCollidingWithWall = false
		State.collisionNormal = Vector3.zero
		State.collisionRecoveryTimer = 0
		State.inputBlocked = false
		return
	end

	-- Check if player is pressing into the wall
	local isPressingIntoWall = false
	if moveDir and moveDir.Magnitude > 0 then
		local moveDirection = moveDir.Unit
		local dot = moveDirection:Dot(wallNormal)
		isPressingIntoWall = dot < -0.35 -- means pressing toward wall
	end

	State.isCollidingWithWall = wallDistance < Constants.Collision.CLAMP_DISTANCE
	State.collisionNormal = wallNormal
	State.collisionRecoveryTimer = State.collisionRecoveryTimer + dt

	if isPressingIntoWall and wallDistance <= stopDistance then
		if currentSpeed > 20 then
			-- SLIDE along wall (sideways at 90°)
			State.inputBlocked = false -- don't freeze input

			local wallTangent = wallNormal:Cross(Vector3.new(0, 1, 0))
			if wallTangent.Magnitude < 0.001 then
				wallTangent = Vector3.new(0, 0, 0)
			else
				wallTangent = wallTangent.Unit
			end

			-- Smoothly redirect velocity to slide sideways along wall
			if bodyVelocity then
				local currentVel = humanoidRootPart.AssemblyLinearVelocity
				local slideVelocity = wallTangent * currentSpeed
				local velT = math.clamp(dt * 8, 0, 1)
				local newVel = Vector3.new(
					currentVel.X, currentVel.Y, currentVel.Z
				):Lerp(Vector3.new(slideVelocity.X, currentVel.Y, slideVelocity.Z), velT)
				bodyVelocity.Velocity = newVel
			end

			-- Smoothly rotate player to face the slide direction
			if bodyGyro then
				local targetCFrame = CFrame.lookAt(
					humanoidRootPart.Position,
					humanoidRootPart.Position + wallTangent,
					Vector3.new(0, 1, 0)
				)
				local currentCF = humanoidRootPart.CFrame
				local rotT = math.clamp(dt * 6, 0, 1)
				bodyGyro.CFrame = currentCF:Lerp(targetCFrame, rotT)
			end

			return
		else
			-- speed <= 20 → STOP movement normally
			State.inputBlocked = true

			if bodyVelocity then
				local curVel = humanoidRootPart.AssemblyLinearVelocity
				local tangential = wallNormal:Cross(Vector3.new(0, 1, 0))
				if tangential.Magnitude < 1e-3 then tangential = Vector3.new(0, 0, 0) end

				local projected = curVel:Dot(tangential) * tangential
				local targetVel = Vector3.new(projected.X, curVel.Y, projected.Z)

				local velT = math.clamp(dt * 10, 0, 1)
				bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVel, velT)
			end

			-- Rotate slightly along wall to avoid jitter
			local wallTangent = wallNormal:Cross(Vector3.new(0, 1, 0))
			if wallTangent.Magnitude > 0.001 then
				local targetCFrame = CFrame.lookAt(
					humanoidRootPart.Position,
					humanoidRootPart.Position + wallTangent.Unit,
					Vector3.new(0, 1, 0)
				)
				local currentCF = humanoidRootPart.CFrame
				local rotT = math.clamp(dt * 8, 0, 1)
				local newRot = currentCF:Lerp(targetCFrame, rotT)
				bodyGyro.CFrame = newRot
			end

			return
		end
	end

	State.inputBlocked = false

	-- Slight smoothing when approaching a wall
	if bodyVelocity and isPressingIntoWall then
		local normalizedDist = math.clamp(
			(wallDistance - stopDistance) / (Constants.Collision.SLOW_DOWN_DISTANCE - stopDistance),
			0, 1
		)
		local smoothFactor = 1 - normalizedDist
		local curVel = humanoidRootPart.AssemblyLinearVelocity
		local velT = math.clamp(dt * 8, 0, 1)
		local horiz = Vector3.new(curVel.X, 0, curVel.Z)
		local newHoriz = horiz:Lerp(horiz * (1 - smoothFactor * 0.15), velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, curVel.Y, newHoriz.Z)
	end




    -- local stopDistance = Constants.COLLISION.STOP_DISTANCE or 3

	-- if not wallNormal or wallDistance > Constants.COLLISION.SLOW_DOWN_DISTANCE then
	-- 	State.isCollidingWithWall = false
	-- 	State.collisionNormal = Vector3.zero
	-- 	State.collisionRecoveryTimer = 0
	-- 	State.inputBlocked = false
	-- 	return
	-- end

	-- -- Detect if player is pressing movement keys toward wall
	-- local isPressingIntoWall = false
	-- if moveDir and moveDir.Magnitude > 0 then
	-- 	local moveDirection = moveDir.Unit
	-- 	local dot = moveDirection:Dot(wallNormal)
	-- 	isPressingIntoWall = dot < -0.35 -- only if moving *into* wall
	-- end

	-- State.isCollidingWithWall = wallDistance < Constants.COLLISION.CLAMP_DISTANCE
	-- State.collisionNormal = wallNormal
	-- State.collisionRecoveryTimer = State.collisionRecoveryTimer + dt

	-- -- Only block input when actually trying to move into the wall and close enough
	-- if isPressingIntoWall and wallDistance <= stopDistance then
	-- 	State.inputBlocked = true

	-- 	-- stop only if moving directly toward wall
	-- 	if bodyVelocity then
	-- 		local curVel = humanoidRootPart.AssemblyLinearVelocity
	-- 		local tangential = wallNormal:Cross(Vector3.new(0, 1, 0))
	-- 		if tangential.Magnitude < 1e-3 then tangential = Vector3.new(0, 0, 0) end

	-- 		-- keep horizontal velocity only in tangential direction
	-- 		local projected = curVel:Dot(tangential) * tangential
	-- 		local targetVel = Vector3.new(projected.X, curVel.Y, projected.Z)

	-- 		local velT = math.clamp(dt * 10, 0, 1)
	-- 		bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVel, velT)
	-- 	end

	-- 	-- Rotate player 90 degrees smoothly along wall
	-- 	local wallTangent = wallNormal:Cross(Vector3.new(0, 1, 0))
	-- 	if wallTangent.Magnitude > 0.001 then
	-- 		local targetCFrame = CFrame.lookAt(
	-- 			humanoidRootPart.Position,
	-- 			humanoidRootPart.Position + wallTangent.Unit,
	-- 			Vector3.new(0, 1, 0)
	-- 		)
	-- 		local currentCF = humanoidRootPart.CFrame
	-- 		local rotT = math.clamp(dt * 8, 0, 1)
	-- 		local newRot = currentCF:Lerp(targetCFrame, rotT)
	-- 		bodyGyro.CFrame = newRot
	-- 	end

	-- 	return
	-- else
	-- 	State.inputBlocked = false
	-- end

	-- -- Slight smoothing near wall but not stopping
	-- if bodyVelocity and isPressingIntoWall then
	-- 	local normalizedDist = math.clamp(
	-- 		(wallDistance - stopDistance) / (Constants.COLLISION.SLOW_DOWN_DISTANCE - stopDistance),
	-- 		0, 1
	-- 	)
	-- 	local smoothFactor = 1 - normalizedDist
	-- 	local curVel = humanoidRootPart.AssemblyLinearVelocity
	-- 	local velT = math.clamp(dt * 8, 0, 1)
	-- 	local horiz = Vector3.new(curVel.X, 0, curVel.Z)
	-- 	local newHoriz = horiz:Lerp(horiz * (1 - smoothFactor * 0.15), velT)
	-- 	bodyVelocity.Velocity = Vector3.new(newHoriz.X, curVel.Y, newHoriz.Z)
	-- end
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


	-- -- If no Constants.COLLISION is active, allow all movement
	-- if not State.isCollidingWithWall then
	-- 	return true
	-- end

	-- -- Only prevent movement if we're trying to move directly into the Constants.COLLISION normal
	-- if direction.Magnitude > 0 then
	-- 	local moveDirection = direction.Unit
	-- 	local dotProduct = moveDirection:Dot(State.collisionNormal)

	-- 	-- Allow movement if we're moving away from the wall or at an angle
	-- 	-- Only block movement that's directly into the wall
	-- 	return dotProduct > -0.7 -- More permissive threshold
	-- end

	-- return true
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