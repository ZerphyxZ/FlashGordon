-- HoverboardDash.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local DashTrailModule = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("HoverboardVFX"):WaitForChild("ElectricDash")

local HoverboardDash = {}
local flashConnection

-- state
local player = Players.LocalPlayer
local character, humanoid, rootPart
local dashReady = true
HoverboardDash.isDashing = false

-- GUI references (module-owned)
local gameHUD = player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
local flashFrame = gameHUD:WaitForChild("FlashFrame")
local flashButton = flashFrame:WaitForChild("FlashButton")
local cooldownFiller = flashFrame:WaitForChild("CooldownFill")

-- Config
local DASH_DISTANCE = 70 -- default distance in studs
local DASH_DURATION = 0.25 -- seconds
local DASH_COOLDOWN = 3 -- seconds
local DASH_SPEED_MULTIPLIER = 1.5

-- VFX: attach electric trails to player body parts
local BODY_PARTS = {
	"Head",
	"LeftFoot",
	"LeftHand",
	"LeftLowerArm",
	"LeftLowerLeg",
	"LeftUpperArm",
	"LeftUpperLeg",
	"LowerTorso",
	"RightFoot",
	"RightHand",
	"RightLowerArm",
	"RightLowerLeg",
	"RightUpperArm",
	"RightUpperLeg",
	"UpperTorso",
}

local function CloneVFX()
	HoverboardDash._activeVFX = {}
	for _, partName in ipairs(BODY_PARTS) do
		local part = character:FindFirstChild(partName)
		if part then
			-- Clone the whole folder
			local fxFolder = DashTrailModule:Clone()
			fxFolder.Name = "ElectricDash_VFX_" .. partName

			-- Extract the objects BEFORE re-parenting
			local attach = fxFolder:FindFirstChild("ParticleAttachment")
			local particleEmitter = fxFolder:FindFirstChild("ParticleEmitter")

			if attach then
				attach.Parent = part
			end
			if particleEmitter then
				particleEmitter.Parent = part
				particleEmitter.Enabled = false
			end

			-- store the trails ONLY (they are what we toggle)
			table.insert(HoverboardDash._activeVFX, {
				ParticleEmitter = particleEmitter,
			})

			-- destroy the empty folder now
			fxFolder:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- Utility: Enable and Disable electric VFX
local function EnableDashVFX(enable)
	for _, fx in ipairs(HoverboardDash._activeVFX or {}) do
		if fx.ParticleEmitter then
			print("VFX Enabled")
			fx.ParticleEmitter.Enabled = enable
		end
	end
end

---------------------------------------------------------------------
-- Char handlers
---------------------------------------------------------------------

local function RefreshGUI()
	if not player then
		return
	end

	local pg = player:WaitForChild("PlayerGui")
	local mg = pg:WaitForChild("GameHUD")

	gameHUD = mg
	flashFrame = mg:WaitForChild("FlashFrame")
	cooldownFiller = flashFrame:WaitForChild("CooldownFill")
	if cooldownFiller then
		cooldownFiller.Visible = false
		-- ensure correct initial size (full height = ready, 0 = empty)
		cooldownFiller.Size = UDim2.new(1, 0, 0, 0)
	end
end

function HoverboardDash.BindDash(char, hum, root, currentSpeed, hoverboard, State)
	character = char
	humanoid = hum
	rootPart = root
	HoverboardDash.isDashing = false
	dashReady = true
	RefreshGUI()
	CloneVFX()

	if flashConnection then
		flashConnection:Disconnect()
		flashConnection = nil
	end
	flashConnection = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			print("Returning GPE")
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			print("Hoverboard: Dash requested.")
			HoverboardDash.ApplyDash(currentSpeed(), hoverboard, State)
		end
	end)
	flashButton.MouseButton1Click:Connect(function()
		print("Hoverboard: Boost requested.")
		HoverboardDash.ApplyDash(currentSpeed(), hoverboard, State)
	end)
end

function HoverboardDash.CharRemoving()
	if flashConnection then
		flashConnection:Disconnect()
		flashConnection = nil
	end

	character = nil
	humanoid = nil
	rootPart = nil
	HoverboardDash.isDashing = false
	dashReady = true
end

---------------------------------------------------------------------
-- Public API: ApplyDash
---------------------------------------------------------------------

local function dash_velocity_method(hoverboard, moveDir, distance, duration)
	if not hoverboard or not hoverboard.PrimaryPart or moveDir.Magnitude == 0 then
		return
	end
	local primary = hoverboard.PrimaryPart
	local startVel = primary.AssemblyLinearVelocity

	-- compute dash velocity required to traverse distance in duration
	local dashSpeed = distance / math.max(duration, 0.0001) * DASH_SPEED_MULTIPLIER
	print("Dash speed: ", dashSpeed)
	local dashVel = moveDir.Unit * dashSpeed

	-- apply: ramp assembly velocity towards dashVel, hold, then restore
	local t = 0
	local holdT = duration
	local lastTime = tick()
	-- create a short run-service loop for reliable timing
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not primary or not conn then
			if conn then
				conn:Disconnect()
			end
			return
		end
		t = t + dt
		if t <= holdT then
			-- lerp current assembly velocity towards dashVel (fast)
			local cur = primary.AssemblyLinearVelocity
			local lerpT = 1 - math.exp(-60 * dt)
			local new = cur:Lerp(Vector3.new(dashVel.X, cur.Y, dashVel.Z), lerpT)
			primary.AssemblyLinearVelocity = new
		else
			-- restore: lerp back to startVel over 0.2s
			local restoreDur = 0.2
			local restoreT = math.min((t - holdT) / restoreDur, 1)
			local cur = primary.AssemblyLinearVelocity
			local target = Vector3.new(startVel.X, cur.Y, startVel.Z)
			local new = cur:Lerp(target, restoreT)
			primary.AssemblyLinearVelocity = new

			if restoreT >= 1 then
				conn:Disconnect()
			end
		end
	end)
end

function HoverboardDash.ApplyDash(currentSpeed, hoverboard, State)
	-- sanity
	if not humanoid then
		warn("HoverboardDash: humanoid nil")
		return
	end
	if not dashReady then
		return
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end
	if not hoverboard or not hoverboard.PrimaryPart then
		warn("HoverboardDash: invalid hoverboard")
		return
	end
	if not State or not State.lastMoveDir or State.lastMoveDir.Magnitude == 0 then
		return
	end
	if currentSpeed < 20 then
		return
	end -- require some minimum speed (tweakable)

	print("Dash applied.")
	dashReady = false
	HoverboardDash.isDashing = true

	-- compute dash params adaptively from current speed
	local moveDir = State.lastMoveDir
	local distance = math.max(DASH_DISTANCE, math.clamp(currentSpeed * 0.6, 8, 40))
	local duration = DASH_DURATION

	dash_velocity_method(hoverboard, moveDir, distance, duration)
	EnableDashVFX(true)

	if cooldownFiller then
		cooldownFiller.Visible = true
		-- start full progress and will shrink
		cooldownFiller.Size = UDim2.new(1, 0, 1, 0)
	end

	-- finish dash after duration: unset flag and start cooldown
	task.delay(duration, function()
		HoverboardDash.isDashing = false
		EnableDashVFX(false)
	end)

	task.spawn(function()
		local step = 0.05
		local timeLeft = DASH_COOLDOWN

		while timeLeft > 0 do
			-- update UI filler: shrink from 1->0 vertically
			if cooldownFiller then
				local frac = timeLeft / DASH_COOLDOWN
				cooldownFiller.Size = UDim2.new(1, 0, frac, 0)
			end
			timeLeft = timeLeft - step
			task.wait(step)
		end
		dashReady = true
		print("Dash ready")
	end)

	return true
end

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function HoverboardDash.Init(plr)
	player = plr or Players.LocalPlayer
end

return HoverboardDash
