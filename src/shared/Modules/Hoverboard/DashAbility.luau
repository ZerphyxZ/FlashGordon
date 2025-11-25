-- HoverboardDash.lua
local HoverboardDash = {}

-- Dash constants
local DASH_SPEED = 100
local DASH_DURATION = 0.3
local DASH_COOLDOWN = 5
local DASH_VFX_DURATION = 0.5

-- Dash state
local isDashing = false
local dashReady = true
local dashTimeLeft = 0

-- VFX assets
local electricVFX = nil

function HoverboardDash.Initialize(hoverboard)
	-- Create electric VFX
	if hoverboard and hoverboard.PrimaryPart then
		electricVFX = Instance.new("ParticleEmitter")
		electricVFX.Name = "DashVFX"
		electricVFX.LightEmission = 0.8
		electricVFX.Color = ColorSequence.new(Color3.fromRGB(0, 200, 255))
		electricVFX.Size = NumberSequence.new(0.5)
		electricVFX.Texture = "rbxassetid://242932105"
		electricVFX.Lifetime = NumberRange.new(0.3, 0.5)
		electricVFX.Rate = 50
		electricVFX.SpreadAngle = Vector2.new(45, 45)
		electricVFX.Speed = NumberRange.new(5, 10)
		electricVFX.Enabled = false
		electricVFX.Parent = hoverboard.PrimaryPart
	end
end

function HoverboardDash.CanDash(currentSpeed)
	return dashReady and currentSpeed > 10 and not isDashing
end

function HoverboardDash.PerformDash(hoverboard, currentSpeed, moveDir, bodyVelocity)
	if not HoverboardDash.CanDash(currentSpeed) or not hoverboard or not hoverboard.PrimaryPart then
		return false
	end

	print("Dash activated!")
	isDashing = true
	dashReady = false
	dashTimeLeft = DASH_COOLDOWN

	-- Activate VFX
	if electricVFX then
		electricVFX.Enabled = true
	end

	-- Calculate dash direction (use last movement direction if available)
	local dashDirection = moveDir
	if dashDirection.Magnitude == 0 then
		dashDirection = hoverboard.PrimaryPart.CFrame.LookVector
	end

	-- Apply dash impulse
	local dashVelocity = dashDirection.Unit * DASH_SPEED
	if bodyVelocity then
		bodyVelocity.Velocity = Vector3.new(dashVelocity.X, bodyVelocity.Velocity.Y, dashVelocity.Z)
	end

	-- Schedule dash end
	task.delay(DASH_DURATION, function()
		isDashing = false
		if electricVFX then
			electricVFX.Enabled = false
		end
	end)

	-- Start cooldown
	task.spawn(function()
		local step = 0.1
		local timeLeft = DASH_COOLDOWN
		while timeLeft > 0 do
			dashTimeLeft = timeLeft
			timeLeft = timeLeft - step
			task.wait(step)
		end
		dashReady = true
		dashTimeLeft = 0
		print("Dash ready!")
	end)

	return true
end

function HoverboardDash.IsDashing()
	return isDashing
end

function HoverboardDash.GetCooldown()
	return dashTimeLeft
end

function HoverboardDash.IsReady()
	return dashReady
end

function HoverboardDash.Cleanup()
	if electricVFX then
		electricVFX:Destroy()
		electricVFX = nil
	end
	isDashing = false
	dashReady = true
	dashTimeLeft = 0
end

return HoverboardDash