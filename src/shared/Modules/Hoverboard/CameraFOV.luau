--// HoverboardFOV.lua
local HoverboardFOV = {}

local IDLE_FOV = 70
local MOVE_FOV = 80
local BOOST_FOV = 85
local JUMP_FOV = 77
local BASE_IDLE = 70
local BASE_MOVE = 80
local BASE_BOOST = 85
local SMOOTHNESS = 3
local JUMP_BOOST = 30

-- jumpFovOffset smoothly goes: +10 → 0 → +10 → 0
local jumpFovOffset = 0
local jumpFovVel = 0   -- used to smooth back

-- Jump state passed from Jump module
function HoverboardFOV.ApplyJumpState(state)
	if state == "up_start" then
		jumpFovOffset = JUMP_BOOST
	elseif state == "down_start" then
		jumpFovOffset = JUMP_BOOST
	end
end


function HoverboardFOV.Update(dt, moveDir, isBoosting, isJumping, isFalling)
	local cam = workspace.CurrentCamera
	if not cam then return end

	local isMoving = moveDir.Magnitude > 0.1

	----------------------------
	-- Base camera FOV
	----------------------------
	local baseTarget = BASE_IDLE

	if isBoosting then
		baseTarget = BASE_BOOST
	elseif isMoving then
		baseTarget = BASE_MOVE
	end

	----------------------------
	-- Smooth jump FOV decay
	----------------------------
	-- make jumpFovOffset → 0 smoothly
	jumpFovOffset = jumpFovOffset - jumpFovOffset * 6 * dt
	-- (fast decay, feels responsive)

	----------------------------
	-- Combine base + jump wave
	----------------------------
	local finalTarget = baseTarget + jumpFovOffset

	----------------------------
	-- Smooth FOV change
	----------------------------
	local smooth = 1 - math.exp(-SMOOTHNESS * dt)
	cam.FieldOfView = cam.FieldOfView + (finalTarget - cam.FieldOfView) * smooth








	--OLD WORKING CODE
	-- local cam = workspace.CurrentCamera
	-- if not cam then return end

	-- local isMoving = moveDir.Magnitude > 0.1
	-- local target = IDLE_FOV
	
	-- if isBoosting then
	-- 	target = BOOST_FOV
	
	-- elseif isJumping then
	-- 	if isMoving then
	-- 		target = MOVE_FOV + 3
	-- 	else
	-- 		target = JUMP_FOV
	-- 	end
		
	-- elseif isFalling then
	-- 	if isMoving then
	-- 		target = MOVE_FOV
	-- 	else
	-- 		target = IDLE_FOV
	-- 	end
		
	-- elseif isMoving then
	-- 	target = MOVE_FOV
	-- else
	-- 	target = IDLE_FOV
	-- end

	-- local smooth = 1 - math.exp(-SMOOTHNESS * dt)
	-- cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * smootha
end

return HoverboardFOV
