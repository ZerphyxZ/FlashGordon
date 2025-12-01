--// HoverboardJump.lua
-- Fully compatible advanced jump module (grid jump, landing, grounded check)

local HoverboardJump = {}

-- External references (assigned by controller during initialization)
local hoverboard
local character
local humanoidRootPart
local hoverBodyPosition

-- CONFIG (edit in controller if needed)
local JUMPING = {
	JUMP_COOLDOWN = 0.25,
	MIN_AIR_TIME = 1,
	STUDS_MULTIPLIER = 5,
	JUMP_HEIGHT = 15,
	MAX_AIR_TIME = 5,
	SMOOTH_JUMP_DURATION = 1,
	GRAVITY_MULTPLIER = 0.6
}

local HOVER = {
	HOVER_HEIGHT = 3,
	RAYCAST_DISTANCE = 20,
	MAX_OBSTACLE_HEIGHT = 50,
}
local PHYSICS = {
	BODY_POSITION_MAX_FORCE = Vector3.new(0, 100000, 0),
}

-- STATE
local Jump = {
	lastJumpTime = 0,
	jumpStartTime = 0,
	isJumping = false,
	isJumpHeld = false,
	canJump = true,
	isFlying = false,
	flyStartTime = 0,
	jumpProgress = 0,
	targetJumpHeight = 0,
	IsDeadFalling = false,
	originalHoverHeight = HOVER.HOVER_HEIGHT or 2,
	baseHoverHeight = HOVER.HOVER_HEIGHT,
	hasLandedAfterSpawn = false,
	moveDir = Vector3.Zero,
}

-- Fly system constants
local FLY = {
	FLY_SPEED = 50, -- How fast the player rises when flying
	MAX_FLY_HEIGHT = 100, -- Maximum flying height
	RETURN_SPEED = 5, -- How fast the player returns to hover height
	SMOOTH_JUMP_DURATION = 0.5, -- Duration of smooth jump animation
	LAND_SMOOTHNESS = 0.05, -- Landing smoothness (lower = smoother)
}

local currentSpeed = 0
local maxSpeed = 0

--------------------------------------------------------------------------------
-- PUBLIC SETTERS FROM CONTROLLER
--------------------------------------------------------------------------------
function HoverboardJump.SetReferences(hb, char, root, bp)
	hoverboard = hb
	character = char
	humanoidRootPart = root
	hoverBodyPosition = bp
end

function HoverboardJump.SetCurrentSpeed(speed)
	currentSpeed = speed
end

function HoverboardJump.SetMaxSpeed(topSpeed)
	maxSpeed = topSpeed
end

function HoverboardJump.SetHoverHeight(height)
	Jump.baseHoverHeight = height
end

function HoverboardJump.ResetJumpStates()
	Jump.isJumping = false
	Jump.isJumpHeld = false
	Jump.isFlying = false
	Jump.canJump = true
	Jump.hasLandedAfterSpawn = false

	Jump.jumpStartTime = 0
	Jump.lastJumpTime = 0
	Jump.jumpProgress = 0
	Jump.jumpStartHeight = 0
	Jump.targetJumpHeight = 0

	Jump.baseHoverHeight = HOVER.HOVER_HEIGHT or 1.5

	-- Reset hover forces
	if hoverBodyPosition then
		hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
	end
end
--------------------------------------------------------------------------------
-- GROUND CHECK
--------------------------------------------------------------------------------
function HoverboardJump.IsGrounded()
	if not hoverboard or not hoverboard.PrimaryPart then
		return false, nil, nil
	end

	local now = tick()

	-- Prevent immediate re-grounding after a jump
	if Jump.isJumping and (now - Jump.jumpStartTime) < JUMPING.MIN_AIR_TIME then
		return false
	end

	local primary = hoverboard.PrimaryPart
	local rayOrigin = primary.Position + Vector3.new(0, 0.5, 0) -- Start slightly above
	local rayDir = Vector3.new(0, -HOVER.RAYCAST_DISTANCE, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	-- Cast multiple rays in a grid pattern for better detection
	local rayOffsets = {
		Vector3.new(0, 0, 0), -- Center
		Vector3.new(2, 0, 2), -- Front-right
		Vector3.new(-2, 0, 2), -- Front-left
		Vector3.new(2, 0, -2), -- Back-right
		Vector3.new(-2, 0, -2), -- Back-left
	}

	local validHits = 0
	local totalDistance = 0
	local avgNormal = Vector3.zero
	local closestHit = nil

	for _, offset in ipairs(rayOffsets) do
		local worldOrigin = rayOrigin + offset
		local result = workspace:Raycast(worldOrigin, rayDir, params)

		if result then
			local distance = (worldOrigin - result.Position).Magnitude

			-- Only count as valid ground if within reasonable hover distance
			if distance <= (HOVER.HOVER_HEIGHT + 2) then
				validHits = validHits + 1
				totalDistance = totalDistance + distance
				avgNormal = avgNormal + result.Normal

				if not closestHit or distance < (closestHit.Position - worldOrigin).Magnitude then
					closestHit = result
				end
			end
		end
	end

	-- Require at least 2 valid hits for stable ground detection
	if validHits >= 2 and closestHit then
		avgNormal = (avgNormal / validHits).Unit
		return true, closestHit.Position, avgNormal
	end

	return false, nil, nil

	-- if not hoverboard or not hoverboard.PrimaryPart then
	-- 	return false, nil, nil
	-- end

	-- local now = tick()

	-- -- Prevent immediate re-grounding after a jump
	-- if Jump.isJumping and (now - Jump.jumpStartTime) < JUMPING.MIN_AIR_TIME then
	-- 	return false
	-- end

	-- -- Still rising? → not grounded
	-- if humanoidRootPart and humanoidRootPart.Velocity.Y > HOVER.MAX_OBSTACLE_HEIGHT then
	-- 	return false
	-- end

	-- local primary = hoverboard.PrimaryPart
	-- local rayOrigin = primary.Position --+ Vector3.new(0, 0.5, 0) -- Start slightly above
	-- local rayDir = Vector3.new(0, -HOVER.RAYCAST_DISTANCE, 0)

	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character, hoverboard }

	-- -- Cast multiple rays in a wider pattern for better ramp detection
	-- local rayOffsets = {
	-- 	Vector3.new(0, 0, 0), -- Center
	-- 	Vector3.new(2, 0, 2), -- Front-right
	-- 	Vector3.new(-2, 0, 2), -- Front-left
	-- 	Vector3.new(2, 0, -2), -- Back-right
	-- 	Vector3.new(-2, 0, -2), -- Back-left
	-- 	Vector3.new(3, 0, 0), -- Right
	-- 	Vector3.new(-3, 0, 0), -- Left
	-- 	Vector3.new(0, 0, 3), -- Front
	-- 	Vector3.new(0, 0, -3), -- Back
	-- }

	-- local hitCount = 0
	-- local totalHits = 0
	-- local avgNormal = Vector3.zero
	-- local closestDistance = math.huge
	-- local closestPosition = nil

	-- for _, offset in ipairs(rayOffsets) do
	-- 	local origin = rayOrigin + offset
	-- 	local result = workspace:Raycast(origin, rayDir, params)
	-- 	if result then
	-- 		totalHits = totalHits + 1
	-- 		local distance = (origin - result.Position).Magnitude -- Use actual distance, not just Y difference
	-- 		avgNormal = avgNormal + result.Normal

	-- 		if distance < closestDistance then
	-- 			closestDistance = distance
	-- 			closestPosition = result.Position
	-- 		end

	-- 		-- Consider grounded if within hover height + tolerance (increased for ramps)
	-- 		local tolerance = (HOVER.HOVER_HEIGHT or 4) + 0.5 -- Increased tolerance for ramps
	-- 		if distance <= tolerance then
	-- 			hitCount = hitCount + 1
	-- 		end
	-- 	end
	-- end

	-- -- Also check if we're very close to any surface using a shorter, angled ray for ramps
	-- if hitCount < 2 then
	-- 	local shortRayLength = (HOVER.HOVER_HEIGHT or 4) + 1
	-- 	local shortRayDir = (rayDir.Unit * shortRayLength)

	-- 	for _, offset in ipairs(rayOffsets) do
	-- 		local origin = rayOrigin + offset
	-- 		local result = workspace:Raycast(origin, shortRayDir, params)
	-- 		if result then
	-- 			local distance = (origin - result.Position).Magnitude
	-- 			if distance <= shortRayLength then
	-- 				hitCount = hitCount + 1
	-- 				if totalHits == 0 then
	-- 					closestPosition = result.Position
	-- 					avgNormal = result.Normal
	-- 				else
	-- 					avgNormal = avgNormal + result.Normal
	-- 				end
	-- 				totalHits = totalHits + 1
	-- 			end
	-- 		end
	-- 	end
	-- end

	-- -- Require at least 2 rays to hit for stable ground detection
	-- if hitCount >= 2 and totalHits > 0 then
	-- 	avgNormal = (avgNormal / totalHits).Unit
	-- 	return true, closestPosition, avgNormal
	-- end

	-- return false, nil, nil
end

--------------------------------------------------------------------------------
-- ATTEMPT JUMP
--------------------------------------------------------------------------------
function HoverboardJump.AttemptJump()
	local grounded = HoverboardJump.IsGrounded()
	if not grounded or Jump.isJumping then
		return
	end

	if not Jump.isJumpHeld then
		Jump.isJumpHeld = true
	end

	-- disable vertical hover force
	if hoverBodyPosition then
		hoverBodyPosition.MaxForce = Vector3.zero
	end

	local now = tick()
	Jump.lastJumpTime = now
	Jump.jumpStartTime = now
	Jump.isJumping = true
	Jump.jumpProgress = 0
	Jump.isFlying = false
	Jump.canJump = false

	Jump.jumpStartHeight = hoverboard.PrimaryPart.Position.Y
	Jump.targetJumpHeight = Jump.jumpStartHeight + JUMPING.JUMP_HEIGHT

	---------------------------------------------------------
	-- ▶ NEW: Play animations
	---------------------------------------------------------
	-- if Animations.Player.Jump then
	-- 	Animations.Player.Jump:Play()
	-- end
	-- if Animations.Hoverboard.Jump then
	-- 	Animations.Hoverboard.Jump:Play()
	-- end
end

function HoverboardJump.UpdateJump(moveDir, dt)
	if not hoverboard or not hoverboard.PrimaryPart or not humanoidRootPart then
		return
	end

	local grounded = HoverboardJump.IsGrounded()

	-- Auto jump if holding and grounded
	if grounded and Jump.isJumpHeld and not Jump.isJumping and not Jump.isFalling then
		HoverboardJump.AttemptJump()
		return
	end

	if grounded and not Jump.isJumping and not Jump.isFalling then
		return
	end

	local vel = humanoidRootPart.Velocity

	-----------------------------------------------------
	-- 1) GOING UP
	-----------------------------------------------------
	if Jump.isJumping then
		Jump.jumpProgress = Jump.jumpProgress + dt / (JUMPING.SMOOTH_JUMP_DURATION * JUMPING.GRAVITY_MULTPLIER)  
		-- ↑ 0.6 = FASTER smoothness (you requested speed-up)

		if Jump.jumpProgress < 1 then
			local t = Jump.jumpProgress
			local smoothT = t * t * (3 - 2 * t)

			local targetY = Jump.jumpStartHeight +
				(Jump.targetJumpHeight - Jump.jumpStartHeight) * smoothT

			local currentY = hoverboard.PrimaryPart.Position.Y
			local diffY = targetY - currentY
			local jumpVelY = diffY / dt

			humanoidRootPart.Velocity = Vector3.new(vel.X, jumpVelY, vel.Z)

		else
			-- Switch to falling phase
			Jump.isJumping = false
			Jump.isFalling = true
			Jump.jumpProgress = 1 -- start falling from top
			print("Reached top → falling")
		end
	end

	-----------------------------------------------------
	-- 2) GOING DOWN
	-----------------------------------------------------
	if Jump.isFalling then
		Jump.jumpProgress = Jump.jumpProgress - dt / (JUMPING.SMOOTH_JUMP_DURATION * JUMPING.GRAVITY_MULTPLIER)

		if Jump.jumpProgress > 0 then
			-- smooth fall from 1 → 0
			local t = Jump.jumpProgress
			local smoothT = t * t * (3 - 2 * t)
			print("Smooth falling: ", smoothT)

			local targetY = Jump.jumpStartHeight +
				(Jump.targetJumpHeight - Jump.jumpStartHeight) * smoothT

			local currentY = hoverboard.PrimaryPart.Position.Y

			-- delta but reversed
			local diffY = targetY - currentY
			local fallVelY = diffY / dt

			humanoidRootPart.Velocity = Vector3.new(vel.X, fallVelY, vel.Z)

		else
			-- Finished falling
			Jump.isFalling = false
			Jump.jumpProgress = 0
			print("Fall finished")
		end
	end









	-- if not hoverboard or not hoverboard.PrimaryPart or not humanoidRootPart then
	-- 	return
	-- end

	-- local grounded = HoverboardJump.IsGrounded()
	-- -- If grounded and jump key is still held → auto-jump again
	-- if grounded and Jump.isJumpHeld and not Jump.isJumping then
	-- 	HoverboardJump.AttemptJump()
	-- 	return
	-- end
	-- if grounded then
	-- 	return
	-- end
	-- local vel = humanoidRootPart.Velocity

	-- --Handle upward jump animation
	-- if Jump.isJumping then
	-- 	Jump.jumpProgress = Jump.jumpProgress + dt / JUMPING.SMOOTH_JUMP_DURATION
	-- 	print("Jump progress: ", Jump.jumpProgress)
	-- 	if Jump.jumpProgress < 1 then
	-- 		-- Smooth upward velocity from current position
	-- 		local t = Jump.jumpProgress
	-- 		local smoothT = t * t * (3 - 2 * t) -- Smoothstep interpolation
	-- 		local targetHeight = Jump.jumpStartHeight + (Jump.targetJumpHeight - Jump.jumpStartHeight) * smoothT
	-- 		local currentHeight = hoverboard.PrimaryPart.Position.Y

	-- 		-- Calculate velocity needed to reach target height
	-- 		local heightDiff = targetHeight - currentHeight
	-- 		local jumpVel = heightDiff / dt

	-- 		humanoidRootPart.Velocity = Vector3.new(vel.X, jumpVel, vel.Z)
	-- 	else
	-- 		-- Jump phase complete, start falling
	-- 		Jump.isJumping = false
	-- 		Jump.jumpProgress = 0
	-- 		local fallPull = 0.005
	-- 		humanoidRootPart.Velocity = Vector3.new(vel.X, vel.Y - fallPull, vel.Z)
	-- 		print("Jump completed")
	-- 	end
	-- end
end

--------------------------------------------------------------------------------
-- LANDING LOGIC
--------------------------------------------------------------------------------
function HoverboardJump.UpdateLanding(humanoid, dt)
	if not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	-- Kill player if falling too fast
	if humanoidRootPart and humanoidRootPart.Velocity.Y < -300 then
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end

	local grounded, groundPos, groundNormal = HoverboardJump.IsGrounded()

	-- If jumping: check if landed
	if Jump.isJumping then
		if grounded then
			Jump.isJumping = false
			Jump.canJump = true
			Jump.jumpProgress = 0
		else
			return
		end
	end

	-- Always keep hover height consistent when NOT jumping
	if hoverBodyPosition and hoverboard.PrimaryPart then
		local primary = hoverboard.PrimaryPart
		local origin = primary.Position

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, hoverboard }

		local result = workspace:Raycast(origin, Vector3.new(0, -(HOVER.RAYCAST_DISTANCE + 1), 0), params)
		if result then
			local groundY = result.Position.Y
			local targetY = groundY + Jump.baseHoverHeight

			local heightSmooth = 1 - math.exp(-100 * dt)
			local currentY = hoverBodyPosition.Position.Y
			local newY = currentY + (targetY - currentY) * heightSmooth

			hoverBodyPosition.Position = Vector3.new(origin.X, newY, origin.Z)
			hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
		else
			-- No ground detected within ray distance -> let physics take over and fall
			hoverBodyPosition.MaxForce = Vector3.zero
		end
	end
end

HoverboardJump.State = Jump

return HoverboardJump
