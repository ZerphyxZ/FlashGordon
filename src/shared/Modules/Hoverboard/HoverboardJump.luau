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
	MIN_AIR_TIME = 0.12,
	STUDS_MULTIPLIER = 5,
	MIN_JUMP_HEIGHT = 10,
	MAX_JUMP_HEIGHT = 25,
	MAX_AIR_TIME = 5
}
local HOVER = {
	HOVER_HEIGHT = 4,
	RAYCAST_DISTANCE = 20
}
local PHYSICS = {
	BODY_POSITION_MAX_FORCE = Vector3.new(0, 100000, 0)
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
	originalHoverHeight = HOVER.HOVER_HEIGHT or 5,
	baseHoverHeight = HOVER.HOVER_HEIGHT,
}

-- Fly system constants
local FLY = {
	FLY_SPEED = 50,              -- How fast the player rises when flying
	MAX_FLY_HEIGHT = 100,        -- Maximum flying height
	RETURN_SPEED = 5,           -- How fast the player returns to hover height
	SMOOTH_JUMP_DURATION = 0.5,  -- Duration of smooth jump animation
	LAND_SMOOTHNESS = 0.05        -- Landing smoothness (lower = smoother)
}


local currentSpeed = 0

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

function HoverboardJump.SetHoverHeight(height)
	Jump.baseHoverHeight = height
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

	-- Still rising? → not grounded
	if humanoidRootPart and humanoidRootPart.Velocity.Y > 6 then
		return false
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
		local tolerance = (HOVER.HOVER_HEIGHT or 4) + 1.5
		if distance <= tolerance then
			return true, result.Position, result.Normal
		end
	end

	return false, nil, nil
end

--------------------------------------------------------------------------------
-- ATTEMPT JUMP
--------------------------------------------------------------------------------
function HoverboardJump.AttemptJump()
	local grounded = HoverboardJump.IsGrounded()
	if not grounded or Jump.isJumping then
		print("Grounded. Returning") return
	end
	if not Jump.isJumpHeld then
		Jump.isJumpHeld = true
	end

	-- Disable vertical hover force
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

	-- Store the current hover height as the starting point for the jump
	if hoverboard.PrimaryPart then
		Jump.jumpStartHeight = hoverboard.PrimaryPart.Position.Y 
	end

	-- Calculate jump height based on speed (grid system)
	local studsMult = JUMPING.STUDS_MULTIPLIER
	local rawMin = JUMPING.MIN_JUMP_HEIGHT
	local rawMax = JUMPING.MAX_JUMP_HEIGHT

	local function snap(v, grid)
		return math.floor(v / grid + 0.5) * grid
	end

	local minStuds = snap(rawMin, studsMult)
	local maxStuds = snap(rawMax, studsMult)

	local levelCount = math.floor((maxStuds - minStuds) / studsMult) + 1
	local speedStep = 10
	local speedIndex = math.floor(currentSpeed / speedStep)
	local levelIndex = math.clamp(speedIndex, 0, math.max(0, levelCount - 1))

	-- Always use maximum jump height for single press
	Jump.targetJumpHeight = Jump.jumpStartHeight + maxStuds  	--minStuds + (levelIndex * studsMult)
	print("Jump started with target height: ", Jump.targetJumpHeight)
end

function HoverboardJump.UpdateJump(dt)
	if not hoverboard or not humanoidRootPart then
		return
	end

	local grounded = HoverboardJump.IsGrounded()
	-- If grounded and jump key is still held → auto-jump again
	if grounded and Jump.isJumpHeld and not Jump.isJumping then
		HoverboardJump.AttemptJump()
		return
	end
	if grounded then
		return
	end
	local vel = humanoidRootPart.Velocity

	-- Handle upward jump animation
	if Jump.isJumping then
		Jump.jumpProgress = Jump.jumpProgress + (dt / FLY.SMOOTH_JUMP_DURATION)

		if Jump.jumpProgress < 1 then
			-- Smooth upward velocity from current position
			local t = Jump.jumpProgress
			--local smoothT = t * t * (3 - 2 * t) -- Smoothstep interpolation
			local smoothT = t
			local targetHeight = Jump.jumpStartHeight + (Jump.targetJumpHeight - Jump.jumpStartHeight) * smoothT
			local currentHeight = hoverboard.PrimaryPart.Position.Y

			-- Calculate velocity needed to reach target height
			local heightDiff = targetHeight - currentHeight
			local jumpVel = heightDiff / dt

			humanoidRootPart.Velocity = Vector3.new(vel.X, jumpVel, vel.Z)

		else
			-- Jump phase complete, start falling
			Jump.isJumping = false
			Jump.jumpProgress = 0

			-- Apply downward velocity for smooth fall
			local fallPull = 12
			humanoidRootPart.Velocity = Vector3.new(vel.X, vel.Y - fallPull, vel.Z)
		end
	end
end

function HoverboardJump.UpdateJumpAndFly(deltaTime)
	if not hoverboard or not humanoidRootPart then
		return
	end

	local grounded = HoverboardJump.IsGrounded()
	local currentVelocity = humanoidRootPart.Velocity

	-- Handle flying state
	if Jump.isFlying then
		-- Apply upward flying force
		local flyVelocity = Vector3.new(currentVelocity.X, FLY.FLY_SPEED, currentVelocity.Z)
		humanoidRootPart.Velocity = flyVelocity

		-- Check if we've reached max fly height
		if hoverboard.Position.Y >= FLY.MAX_FLY_HEIGHT then
			-- Maintain position at max height
			humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
		end

		-- Keep hover force disabled during flight
		if hoverBodyPosition then
			hoverBodyPosition.MaxForce = Vector3.zero
		end

	elseif Jump.isJumping and not Jump.isFlying then
		-- Handle smooth jump progression
		Jump.jumpProgress = Jump.jumpProgress + (deltaTime / FLY.SMOOTH_JUMP_DURATION)

		if Jump.jumpProgress < 1 then
			-- Smooth upward motion during jump
			local jumpT = Jump.jumpProgress
			local smoothT = 1 - (1 - jumpT) * (1 - jumpT) -- Ease out quad
			local currentJumpVelocity = Jump.targetJumpHeight * (1 - smoothT)

			humanoidRootPart.Velocity = Vector3.new(
				currentVelocity.X,
				currentJumpVelocity,
				currentVelocity.Z
			)
		else
			-- Jump phase complete, start smooth landing if not flying
			if grounded then
				Jump.isJumping = false
				Jump.jumpProgress = 0
				-- Restore hover force
				if hoverBodyPosition then
					hoverBodyPosition.MaxForce = Vector3.new(0, HOVER.HOVER_FORCE or 10000, 0)
				end
			else
				-- Apply gentle downward force for smooth landing
				local landT = (Jump.jumpProgress - 1) * FLY.LAND_SMOOTHNESS
				local downwardForce = math.min(landT * 20, 10) -- Gentle pull toward ground

				humanoidRootPart.Velocity = Vector3.new(
					currentVelocity.X,
					currentVelocity.Y - downwardForce,
					currentVelocity.Z
				)
			end
		end

		-- Keep hover force disabled during jump
		if hoverBodyPosition then
			hoverBodyPosition.MaxForce = Vector3.zero
		end

	elseif not grounded and not Jump.isJumping and not Jump.isFlying then
		-- Return to hover height when not jumping or flying
		local currentHeight = hoverboard.Position.Y
		local hoverHeight = Jump.originalHoverHeight

		if currentHeight > hoverHeight + 1 then
			-- Smoothly return to hover height
			local heightDiff = currentHeight - hoverHeight
			local returnStrength = math.min(heightDiff * FLY.RETURN_SPEED * deltaTime, heightDiff)

			humanoidRootPart.Velocity = Vector3.new(
				currentVelocity.X,
				currentVelocity.Y - returnStrength,
				currentVelocity.Z
			)
		end
	end

	-- Auto-land if we've been in the air too long without flying
	if Jump.isJumping and not Jump.isFlying and (tick() - Jump.jumpStartTime) > JUMPING.MAX_AIR_TIME then
		Jump.isJumping = false
		Jump.jumpProgress = 0
	end
end

--------------------------------------------------------------------------------
-- START FLYING (when jump button is held)
--------------------------------------------------------------------------------
function HoverboardJump.StartFlying()
	--if State.isJumping and not State.isFlying then
	--	State.isFlying = true
	--	State.flyStartTime = tick()
	--	print("Flying started")
	--end
end

--------------------------------------------------------------------------------
-- STOP FLYING (when jump button is released)
--------------------------------------------------------------------------------
function HoverboardJump.StopFlying()
	--if State.isFlying then
	--	State.isFlying = false
	--	State.jumpStartTime = tick() -- Reset jump timer for smooth landing
	--	print("Flying stopped, returning to hover height")
	--end
end

--------------------------------------------------------------------------------
-- LANDING LOGIC
--------------------------------------------------------------------------------
function HoverboardJump.UpdateLanding(dt)
	if not hoverboard and not hoverboard.PrimaryPart then return end
	-- If jumping: check if landed
	if Jump.isJumping then
		local grounded = HoverboardJump.IsGrounded()
		if grounded then
			Jump.isJumping = false
			Jump.canJump = true

			-- Restore hover lock
			if hoverBodyPosition then
				local p = hoverboard.PrimaryPart.Position
				hoverBodyPosition.Position = Vector3.new(p.X, p.Y, p.Z)
				hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
			end
		end
	end

	-- Always keep hover height consistent when NOT jumping
	if not Jump.isJumping and hoverBodyPosition then

		local primary = hoverboard.PrimaryPart
		local origin = primary.Position

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, hoverboard }

		local result = workspace:Raycast(origin, Vector3.new(0, -(HOVER.RAYCAST_DISTANCE + 1), 0), params)
		if result then
			local groundY = result.Position.Y
			local targetY = groundY + Jump.baseHoverHeight
			hoverBodyPosition.Position = Vector3.new(origin.X, targetY, origin.Z)
			hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
		end
	end
end

HoverboardJump.State = Jump

return HoverboardJump
