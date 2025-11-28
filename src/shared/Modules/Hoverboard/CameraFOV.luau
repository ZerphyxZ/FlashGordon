--// HoverboardFOV.lua
local HoverboardFOV = {}

local IDLE_FOV = 70
local MOVE_FOV = 80
local BOOST_FOV = 85

local FAR_SMOOTHNESS = 0.8
local NEAR_SMOOTHNESS = 2.2
local BOOST_SMOOTHNESS = 1.5

function HoverboardFOV.Update(dt, moveDir, isBoosting)
	local cam = workspace.CurrentCamera
	if not cam then return end

	local isMoving = moveDir.Magnitude > 0.1
	local target
	local smoothFactor

	-- BOOST HAS PRIORITY ABOVE EVERYTHING
	if isBoosting then
		target = BOOST_FOV
		smoothFactor = BOOST_SMOOTHNESS

	else
		-- NORMAL INPUT-BASED FOV
		if isMoving then
			target = MOVE_FOV
			smoothFactor = FAR_SMOOTHNESS
		else
			target = IDLE_FOV
			smoothFactor = NEAR_SMOOTHNESS
		end
	end

	local smooth = 1 - math.exp(-smoothFactor * dt)
	cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * smooth
end

return HoverboardFOV
