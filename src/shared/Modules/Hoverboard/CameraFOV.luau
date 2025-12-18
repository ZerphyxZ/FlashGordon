--// HoverboardFOV.lua
local HoverboardFOV = {}

local IDLE_FOV = 70
local MOVE_FOV = 80
local BOOST_FOV = 85
local JUMP_FOV = 77

local JUMP_FOV_BOOST = 10
--local MAX_VERTICAL_SPEED = -- tune if needed


local SMOOTHNESS = 2

function HoverboardFOV.Update(dt, humanoid, isBoosting, isJumping, isFalling, jumpPower)
	local cam = workspace.CurrentCamera
	if not cam then return end

	local root = humanoid.RootPart
	if not root then return end

	local verticalVel = root.AssemblyLinearVelocity.Y
	local target = IDLE_FOV

	-- BOOST always wins
	if isBoosting then
		target = BOOST_FOV

	-- JUMPING (upwards)
	elseif isJumping then
		local upwardRatio = math.clamp(verticalVel / jumpPower, 0, 1)
		target = 70 + (80 - 70) * (1 - upwardRatio)
		--target = IDLE_FOV + (JUMP_FOV_BOOST * upwardRatio)

	-- FALLING (downwards)
	elseif isFalling then
		local downwardRatio = math.clamp(-verticalVel / jumpPower, 0, 1)
		target = 70 + (80 - 70) * downwardRatio
		--target = IDLE_FOV + (JUMP_FOV_BOOST * downwardRatio)

	-- NORMAL MOVE
	elseif humanoid.MoveDirection.Magnitude > 0.1 then
		target = MOVE_FOV
	end

	-- Smooth interpolation
	local smooth = 1 - math.exp(-SMOOTHNESS * dt)
	cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * smooth







	-- local cam = workspace.CurrentCamera
	-- if not cam then return end

	-- local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	-- local target = IDLE_FOV
	
	-- if isBoosting then
	-- 	target = BOOST_FOV
	
	-- elseif isJumping then
	-- 	if isMoving then
	-- 		print("Jumping moving")
	-- 		target = MOVE_FOV + 3
	-- 	else
	-- 		print("Jumping idle")
	-- 		target = JUMP_FOV
	-- 	end
		
	-- elseif isFalling then
	-- 	if isMoving then
	-- 		print("Falling moving")
	-- 		target = MOVE_FOV
	-- 	else
	-- 		print("Falling idle")
	-- 		target = IDLE_FOV
	-- 	end
		
	-- elseif isMoving then
	-- 	target = MOVE_FOV
	-- else
	-- 	target = IDLE_FOV
	-- end

	-- local smooth = 1 - math.exp(-SMOOTHNESS * dt)
	-- cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * smooth
end

return HoverboardFOV