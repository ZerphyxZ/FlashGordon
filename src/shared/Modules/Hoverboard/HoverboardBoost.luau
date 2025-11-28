-- HoverboardBoost.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HoverboardModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")
local HoverboardMovement = require(HoverboardModules:WaitForChild("HoverboardMovement"))

local BoostModule = {}

-- Player reference
local player = Players.LocalPlayer

-- GUI references (module-owned)
local gameHUD = player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
local boostFrame = gameHUD:WaitForChild("BoostFrame")
local boostButton = boostFrame:WaitForChild("BoostButton")
local boostCooldownFiller = boostFrame:WaitForChild("CooldownFill")

-- Boost config
local BOOST_AMOUNT = 50
local BOOST_DURATION = 1
local BOOST_COOLDOWN = 3
local BOOSTED_ACCELERATION = 100

BoostModule.isBoosting = false
local boostReady = true

-- Character variables
local character
local humanoid
local rootPart

-- Input connection (module-local, but controller also binds; keep this optional)
local boostConnection

---------------------------------------------------------------------
-- GUI Refresh
---------------------------------------------------------------------
local function RefreshGUI()
	if not player then return end

	local pg = player:WaitForChild("PlayerGui")
	local mg = pg:WaitForChild("GameHUD")

	gameHUD = mg
	boostFrame = mg:WaitForChild("BoostFrame")
	boostCooldownFiller = boostFrame:WaitForChild("CooldownFill")
	if boostCooldownFiller then
		boostCooldownFiller.Visible = false
		-- ensure correct initial size (full height = ready, 0 = empty)
		boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
	end
end

---------------------------------------------------------------------
-- CharAdded / CharRemoving
---------------------------------------------------------------------
function BoostModule.BindBoost(char, hum, root, currentSpeedGetter, accelRef, topSpeedRef)
	character = char
	humanoid = hum
	rootPart = root

	BoostModule.isBoosting = false
	boostReady = true
	RefreshGUI()

	if boostConnection then
		boostConnection:Disconnect()
	end
	boostConnection = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			print("Hoverboard: Boost requested.")
			BoostModule.ApplyBoost(currentSpeedGetter(), accelRef, topSpeedRef)
		end
	end)
	boostButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Boost requested.")
		BoostModule.ApplyBoost(currentSpeedGetter(), accelRef, topSpeedRef)
	end)
end

function BoostModule.CharRemoving()
	-- disconnect module-local connection if any
	if boostConnection then
		boostConnection:Disconnect()
		boostConnection = nil
	end

	character = nil
	humanoid = nil
	rootPart = nil

	BoostModule.isBoosting = false
	boostReady = true
end

---------------------------------------------------------------------
-- MAIN BOOST FUNCTION
-- accelRef and topSpeedRef must be tables with `.value` (mutable refs)
---------------------------------------------------------------------
function BoostModule.ApplyBoost(currentSpeed, accelRef, topSpeedRef)
	-- sanity checks
	if not humanoid then print("Humanoid: ", humanoid) return end
	if not boostReady then print("boostReady: ", boostReady) return end
	if humanoid.MoveDirection.Magnitude < 0.1 then print("humanoid.MoveDirection.Magnitude ", humanoid.MoveDirection.Magnitude) return end
	if not currentSpeed or currentSpeed < 20 then print("currentSpeed: ", currentSpeed) return end
	if type(accelRef) ~= "table" or type(topSpeedRef) ~= "table" then
		warn("BoostModule: ApplyBoost expects accelRef and topSpeedRef as tables with .value")
		return
	end

	-- Activate boost
	boostReady = false
	BoostModule.isBoosting = true

	print("Boost activated")

	local originalAcceleration = accelRef.value
	local originalTopSpeed = topSpeedRef.value

	-- Boosted values
	local boostedSpeed = currentSpeed + BOOST_AMOUNT
	-- apply to movement current speed (so UI and other systems see it immediately)
	HoverboardMovement.CurrentSpeed = boostedSpeed

	-- mutate refs
	accelRef.value = BOOSTED_ACCELERATION
	topSpeedRef.value = boostedSpeed

	if boostCooldownFiller then
		boostCooldownFiller.Visible = true
		-- start full progress and will shrink
		boostCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end

	-- End boost after duration: restore accel/top speed
	task.delay(BOOST_DURATION, function()
		BoostModule.isBoosting = false
		-- double-check refs still exist
		if accelRef then accelRef.value = originalAcceleration end
		if topSpeedRef then topSpeedRef.value = originalTopSpeed end
	end)

	-- Start cooldown UI / timer
	task.spawn(function()
		local step = 0.05
		local timeLeft = BOOST_COOLDOWN

		while timeLeft > 0 do
			-- update UI filler: shrink from 1->0 vertically
			if boostCooldownFiller then
				local frac = timeLeft / BOOST_COOLDOWN
				boostCooldownFiller.Size = UDim2.new(1, 0, frac, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end

		-- cooldown end
		boostReady = true
		if boostCooldownFiller then
			boostCooldownFiller.Visible = false
			boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
		end
	end)

	return true
end

---------------------------------------------------------------------
-- Init Module
---------------------------------------------------------------------
function BoostModule.Init(plr)
	player = plr
end

return BoostModule
