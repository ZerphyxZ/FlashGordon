--// HoverboardFOV.lua
local HoverboardFOV = {}

local IDLE_FOV = 70
local MOVE_FOV = 80
local BOOST_FOV = 85
local JUMP_FOV = 77

local SMOOTHNESS = 2

function HoverboardFOV.Update(dt, humanoid, isBoosting, isJumping, isFalling)
	local cam = workspace.CurrentCamera
	if not cam then return end

	local isMoving = humanoid.MoveDirection.Magnitude > 0.1
	local target = IDLE_FOV
	
	if isBoosting then
		target = BOOST_FOV
	
	elseif isJumping then
		if isMoving then
			target = MOVE_FOV + 3
		else
			target = JUMP_FOV
		end
		
	elseif isFalling then
		if isMoving then
			target = MOVE_FOV
		else
			target = IDLE_FOV
		end
		
	elseif isMoving then
		target = MOVE_FOV
	else
		target = IDLE_FOV
	end

	local smooth = 1 - math.exp(-SMOOTHNESS * dt)
	cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * smooth
end

return HoverboardFOV