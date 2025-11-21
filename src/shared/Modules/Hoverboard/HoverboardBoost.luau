local HoverboardBoost = {}

local BOOST_AMOUNT = 15
local BOOST_DURATION = 0.5
local BOOST_COOLDOWN = 5
local isBoosting = false
local boostReady = true
local boostTimeLeft = 0
local BOOST_MULTIPLIER = 3

function HoverboardBoost:ApplyBoost(HoverboardMovement, ACCELERATION, boostLabel)
	if not boostReady or HoverboardMovement.CurrentSpeed < 20 then return end
	
	print("Boost called.")
	isBoosting = true
	boostReady = false
	boostTimeLeft = BOOST_COOLDOWN

	-- Apply speed boost immediately
	HoverboardMovement.CurrentSpeed = HoverboardMovement.CurrentSpeed + BOOST_AMOUNT

	-- Temp acceleration boost
	local originalAcceleration = ACCELERATION
	ACCELERATION = ACCELERATION * BOOST_MULTIPLIER

	task.delay(BOOST_DURATION, function()
		isBoosting = false
		ACCELERATION = originalAcceleration
	end)

	-- Cooldown management
	task.spawn(function()
		while boostTimeLeft > 0 do
			boostLabel.Text = "Boost CD: " .. string.format("%.1f", boostTimeLeft)
			boostTimeLeft = boostTimeLeft - 0.1
			task.wait(0.1)
		end
		boostReady = true
		boostLabel.Text = "Boost Ready"
	end)
	print("Boost completed.")
end

return HoverboardBoost