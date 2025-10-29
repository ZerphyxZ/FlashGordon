local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local RunService = Global.RunService
local UserInputService = Global.UserInputService
local TweenService = Global.TweenService
local workspace = Global.Workspace
local player = Players.LocalPlayer
local Hoverboards = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboards")
)
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- store config for currently equipped hoverboard
HoverboardController.ActiveConfig = nil

-- Constants
local CONSTANTS = {
	MAX_SPEED = 65,
	ACCELERATION = 1,
	DECELERATION = 1,
	MOVEMENT_SMOOTHNESS = 0.8,
	BRAKE_FORCE = 10,
	BRAKINGSPEED_THRESHOLD = 1,
	ROTATION_SPEED = 65,
	ROTATION_SMOOTHNESS = 0.3,
	JUMP_POWER = 60,
	MIN_JUMP_HEIGHT = 10,
	MAX_JUMP_HEIGHT = 25,
	STEP_MULTIPLIER = 1,
	STUDS_MULTIPLIER = 5,
	TILT_ANGLE = 15,
	HOVER_HEIGHT = 5,
	HOVER_SMOOTHNESS = 2,
	RAYCAST_DISTANCE = 8,
	DELTA_TIME = 0.01,
}

-- State
local character = player.Character
local humanoid, humanoidRootPart
local hoverboard -- reference to server-cloned Hoverboard model
local bodyVelocity -- server-created BodyVelocity on HRP (client will update .Velocity)
local bodyGyro -- server-created BodyGyro on HRP (client will update .CFrame)
local hoverBodyPosition -- server-created BodyPosition under hoverboard primary part (client will update .Position)
local inputVector = Vector3.zero
local currentSpeed = 0
local isOnHoverboard = false

-- Jump / ground
local canJump = false
local isJumping = false
local jumpCooldown = 0.35
local lastJumpTime = 0
local lastMoveDir = Vector3.zero
local braking = false
local hoverOffset
local speedValue

-- Mobile controls
local mobileControls = {}

----------------------------------------------------------
-- GUI Setup
----------------------------------------------------------
local function setupGUI()
	if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SpeedGUI") then
		-- already created
		speedValue = player.PlayerGui.SpeedGUI:FindFirstChildWhichIsA("TextLabel", true)
		return
	end

	local speedGui = Instance.new("ScreenGui")
	speedGui.Name = "SpeedGUI"
	speedGui.Parent = player:WaitForChild("PlayerGui")

	local speedFrame = Instance.new("Frame")
	speedFrame.Size = UDim2.new(0, 200, 0, 80)
	speedFrame.Position = UDim2.new(0, 20, 0, 20)
	speedFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	speedFrame.BackgroundTransparency = 0.3
	speedFrame.BorderSizePixel = 0
	speedFrame.Parent = speedGui

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(1, 0, 0.5, 0)
	speedLabel.Position = UDim2.new(0, 0, 0, 0)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "SPEED"
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.TextScaled = true
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.Parent = speedFrame

	speedValue = Instance.new("TextLabel")
	speedValue.Size = UDim2.new(1, 0, 0.5, 0)
	speedValue.Position = UDim2.new(0, 0, 0.5, 0)
	speedValue.BackgroundTransparency = 1
	speedValue.Text = "0"
	speedValue.TextColor3 = Color3.new(1, 1, 1)
	speedValue.TextScaled = true
	speedValue.Font = Enum.Font.GothamBold
	speedValue.Parent = speedFrame
end

local function resetStates()
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
	inputVector = Vector3.zero
	currentSpeed = 0
	isOnHoverboard = false

	canJump = false
	isJumping = false
	lastJumpTime = 0
	lastMoveDir = Vector3.zero
	braking = false
	hoverOffset = 0
end

----------------------------------------------------------
-- Animation Control
----------------------------------------------------------
local function disableAnimations()
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Enabled = false
	end
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

local function restoreAnimations()
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Enabled = true
	end
end

-- Create client-owned physics helpers and local Motor6D for visuals
local function createClientConstraints()
	if not humanoidRootPart or not hoverboard or not hoverboard.PrimaryPart then
		return
	end
	-- BodyVelocity on HRP (client-owned)
	if not humanoidRootPart:FindFirstChild("HoverBodyVelocity") then
		local bv = Instance.new("BodyVelocity")
		bv.Name = "HoverBodyVelocity"
		bv.MaxForce = Vector3.new(1e5, 0, 1e5)
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.P = 8e3
		bv.Parent = humanoidRootPart
		bodyVelocity = bv
	else
		bodyVelocity = humanoidRootPart:FindFirstChild("HoverBodyVelocity")
	end

	-- BodyGyro on HRP (client-owned)
	if not humanoidRootPart:FindFirstChild("HoverBodyGyro") then
		local bg = Instance.new("BodyGyro")
		bg.Name = "HoverBodyGyro"
		bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		bg.P = 8e3
		bg.D = 300
		bg.CFrame = humanoidRootPart.CFrame
		bg.Parent = humanoidRootPart
		bodyGyro = bg
	else
		bodyGyro = humanoidRootPart:FindFirstChild("HoverBodyGyro")
	end

	-- BodyPosition on hoverboard PrimaryPart (client-owned)
	local primary = hoverboard.PrimaryPart
	if primary and not primary:FindFirstChild("HoverPosition") then
		local bp = Instance.new("BodyPosition")
		bp.Name = "HoverPosition"
		bp.MaxForce = Vector3.new(0, 1e6, 0)
		bp.Position = primary.Position
		bp.P = 7000
		bp.D = 500
		bp.Parent = primary
		hoverBodyPosition = bp
	else
		hoverBodyPosition = primary and primary:FindFirstChild("HoverPosition")
	end
end

function HoverboardController:WaitForHoverboard()
	if not character then
		return
	end
	local hb = character:WaitForChild("Hoverboard", 5)
	if hb then
		print("Hoverboard detected:", hb.Name)
		hoverboard = hb

		-- Instead of repositioning the hoverboard client-side, read server Motor6D to determine offset for local visuals
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local motor6D = hrp and hrp:FindFirstChild("HoverboardMotor")
		if motor6D and motor6D:IsA("Motor6D") then
			-- Motor6D.C0 was set by the server to CFrame.new(0, -offset, 0)
			-- We store the offset as positive value for local math usage
			local c0Pos = motor6D.C0.Position
			hoverOffset = -c0Pos.Y
		else
			-- Fallback: measure model bounding box relative to HRP (non-authoritative, just for visuals)
			hoverOffset = 0
		end

		-- create physics constraints
		--bindServerConstraints()
		createClientConstraints()
		isOnHoverboard = true
		disableAnimations()
		setupGUI()
		print("Hoverboard detected (server-cloned):", hb.Name)
	end
end

----------------------------------------------------------
-- Jump handling
----------------------------------------------------------
local function isGrounded()
	if not hoverboard or not hoverboard.PrimaryPart then
		return false, nil, nil
	end

	local primary = hoverboard.PrimaryPart
	local rayOrigin = primary.Position
	local rayDir = Vector3.new(0, -CONSTANTS.RAYCAST_DISTANCE, 0)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		local distance = primary.Position.Y - result.Position.Y
		if distance <= (CONSTANTS.HOVER_HEIGHT + 2.5) then
			return true, result.Position, distance
		end
	end
	return false, nil, nil
end

local function attemptJump()
	local now = tick()
	if now - lastJumpTime < jumpCooldown then
		return
	end
	local grounded = isGrounded()
	if not grounded or isJumping then
		return
	end

	lastJumpTime = now
	isJumping = true
	canJump = false

	local speedRatio = math.clamp(currentSpeed / CONSTANTS.MAX_SPEED, 0, 1)
	local jumpHeight = CONSTANTS.MIN_JUMP_HEIGHT
		+ (
			math.floor((CONSTANTS.MAX_JUMP_HEIGHT - CONSTANTS.MIN_JUMP_HEIGHT) * speedRatio / CONSTANTS.STEP_MULTIPLIER)
			* CONSTANTS.STEP_MULTIPLIER
		)
	local jumpVelocity = jumpHeight * CONSTANTS.STUDS_MULTIPLIER

	local currentVelocity = humanoidRootPart.Velocity
	humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, jumpVelocity, currentVelocity.Z)

	if hoverBodyPosition then
		hoverBodyPosition.MaxForce = Vector3.zero
		task.delay(0.5, function()
			if hoverBodyPosition and hoverBodyPosition.Parent then
				hoverBodyPosition.MaxForce = Vector3.new(0, 1e6, 0)
			end
		end)
	end
end

----------------------------------------------------------
-- Movement + Hover Update (client updates server-owned constraints)
----------------------------------------------------------

-- Align player's HumanoidRootPart with the surface normal
local function alignPlayerToGround(dt)
	if not humanoidRootPart or not hoverboard then
		return
	end

	local origin = humanoidRootPart.Position
	local direction = Vector3.new(0, -1, 0) * CONSTANTS.RAYCAST_DISTANCE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local result = workspace:Raycast(origin, direction, params)
	if result then
		local normal = result.Normal
		local forward = humanoidRootPart.CFrame.LookVector
		local right = forward:Cross(normal).Unit
		local adjustedForward = normal:Cross(right).Unit

		-- Build new CFrame aligned with ground
		local targetCFrame = CFrame.fromMatrix(humanoidRootPart.Position, right, normal, -adjustedForward)
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, dt * 6)
	end
end

local function updateMovement(dt)
	if not isOnHoverboard or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	local cfg = HoverboardController.ActiveConfig or {}
	local MAX_SPEED = cfg.TopSpeed or CONSTANTS.MAX_SPEED
	local ACCELERATION = cfg.Acceleration or CONSTANTS.ACCELERATION
	local DECELERATION = cfg.Deceleration or CONSTANTS.DECELERATION
	local JUMP_POWER = cfg.JumpPower or CONSTANTS.JUMP_POWER

	local camera = workspace.CurrentCamera
	local lookDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if lookDir.Magnitude > 0 then
		lookDir = lookDir.Unit
	end
	local rightDir = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if rightDir.Magnitude > 0 then
		rightDir = rightDir.Unit
	end
	local moveDir = (lookDir * -inputVector.Z + rightDir * inputVector.X)
	moveDir = moveDir.Magnitude > 0 and moveDir.Unit or Vector3.zero

	if moveDir.Magnitude > 0 then
		lastMoveDir = moveDir
	end

	local targetSpeed = moveDir.Magnitude > 0 and MAX_SPEED or 0
	local rate = moveDir.Magnitude > 0 and ACCELERATION or DECELERATION
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * rate * dt * CONSTANTS.MOVEMENT_SMOOTHNESS
	currentSpeed = math.clamp(currentSpeed, 0, MAX_SPEED)

	-- Apply horizontal velocity via server-owned BodyVelocity (client updates Velocity)
	local effectiveDir = (currentSpeed > 0) and lastMoveDir or Vector3.zero
	local velocity = effectiveDir * currentSpeed
	local currentVel = humanoidRootPart.AssemblyLinearVelocity
	if bodyVelocity then
		-- preserve vertical velocity
		bodyVelocity.Velocity = Vector3.new(velocity.X, currentVel.Y, velocity.Z)
	end

	-- Rotation smoothing: update server-owned BodyGyro .CFrame
	if effectiveDir.Magnitude > 0 and bodyGyro then
		local targetCF = CFrame.new(Vector3.zero, effectiveDir)
		local facingOffset = CFrame.Angles(0, math.rad(-90), 0)
		targetCF = targetCF * facingOffset
		local currentCF = humanoidRootPart.CFrame - humanoidRootPart.CFrame.Position
		local lerped =
			currentCF:Lerp(targetCF, math.clamp(dt * CONSTANTS.ROTATION_SPEED * CONSTANTS.ROTATION_SMOOTHNESS, 0, 1))
		bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * lerped
	end

	-- Keep Motor6D C0 if a Motor6D exists (other visuals may rely on it)
	local motor6D = humanoidRootPart:FindFirstChild("HoverboardMotor")
	if motor6D then
		--local baseC0 = CFrame.new(0, -hoverOffset, 0)
		--motor6D.C0 = baseC0
	end

	-- Hover + Tilt: compute ground normals & update server BodyPosition and primary part CFrame for visuals
	local primary = hoverboard.PrimaryPart
	if primary then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, hoverboard }

		local size = primary.Size
		local rayLength = CONSTANTS.RAYCAST_DISTANCE
		local rayOffsets = {
			Vector3.new(size.X / 2, 0, size.Z / 2),
			Vector3.new(-size.X / 2, 0, size.Z / 2),
			Vector3.new(size.X / 2, 0, -size.Z / 2),
			Vector3.new(-size.X / 2, 0, -size.Z / 2),
		}

		local hitPositions = {}
		local hitNormals = {}

		for _, offset in ipairs(rayOffsets) do
			local origin = primary.CFrame:PointToWorldSpace(offset)
			local direction = Vector3.new(0, -rayLength, 0)
			local result = workspace:Raycast(origin, direction, params)
			if result then
				table.insert(hitPositions, result.Position)
				table.insert(hitNormals, result.Normal)
			end
		end

		if #hitPositions > 0 and not isJumping then
			local avgPos = Vector3.zero
			local avgNormal = Vector3.zero
			for i = 1, #hitPositions do
				avgPos = avgPos + hitPositions[i]
				avgNormal = avgNormal + hitNormals[i]
			end
			avgPos = avgPos / #hitPositions
			avgNormal = avgNormal.Unit

			local targetY = avgPos.Y + CONSTANTS.HOVER_HEIGHT
			if hoverBodyPosition then
				hoverBodyPosition.Position = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
			end

			local forward = humanoidRootPart.CFrame.LookVector
			local right = forward:Cross(avgNormal)
			if right.Magnitude > 0 then
				right = right.Unit
			end
			local alignedForward = avgNormal:Cross(right)
			if alignedForward.Magnitude > 0 then
				alignedForward = alignedForward.Unit
			end

			-- local surfaceCF = CFrame.fromMatrix(primary.Position, right, avgNormal, -alignedForward)
			-- local newCF = primary.CFrame:Lerp(surfaceCF, dt * CONSTANTS.HOVER_SMOOTHNESS)
			-- primary.CFrame = newCF

			-- Hoverboard follows player's orientation and stays under them
			if hoverBodyPosition then
				hoverBodyPosition.Position = Vector3.new(
					humanoidRootPart.Position.X,
					humanoidRootPart.Position.Y - hoverOffset,
					humanoidRootPart.Position.Z
				)
			end

			-- Match hoverboard's rotation to player's root part
			if primary then
				primary.CFrame = primary.CFrame:Lerp(
					CFrame.new(primary.Position) * CFrame.Angles(0, humanoidRootPart.Orientation.Y * math.pi / 180, 0),
					dt * CONSTANTS.HOVER_SMOOTHNESS
				)
			end

			-- Align player orientation with same surface normal
			alignPlayerToGround(dt)
		else
			if hoverBodyPosition then
				hoverBodyPosition.MaxForce = Vector3.zero
			end
		end
	end

	-- Speed GUI
	if speedValue then
		speedValue.Text = tostring(math.floor(currentSpeed))
	end
end

----------------------------------------------------------
-- Cleanup & Reset (client-side only — DO NOT destroy server constraints)
----------------------------------------------------------
local function cleanupHoverboard()
	isOnHoverboard = false

	-- Destroy client-owned physics objects
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	if bodyGyro and bodyGyro.Parent then
		bodyGyro:Destroy()
	end
	if hoverBodyPosition and hoverBodyPosition.Parent then
		hoverBodyPosition:Destroy()
	end
	-- local motor
	local localMotor = humanoidRootPart and humanoidRootPart:FindFirstChild("HoverboardMotorLocal")
	if localMotor then
		localMotor:Destroy()
	end

	-- Client should NOT destroy server-owned constraints; only clear references
	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil

	-- Remove visual GUI controls for mobile
	if mobileControls.JumpButton then
		if mobileControls.JumpButton.Parent then
			mobileControls.JumpButton.Parent:Destroy()
		end
		mobileControls.JumpButton = nil
	end
	hoverboard = nil
end

----------------------------------------------------------
-- Mobile Controls
----------------------------------------------------------
function HoverboardController:setupMobileControls()
	if UserInputService.TouchEnabled and not mobileControls.JumpButton then
		local playerGui = player:WaitForChild("PlayerGui")

		local jumpGui = Instance.new("ScreenGui")
		jumpGui.Name = "HoverboardJumpGUI"
		jumpGui.ResetOnSpawn = false
		jumpGui.Parent = playerGui

		local jumpButton = Instance.new("TextButton")
		jumpButton.Name = "JumpButton"
		jumpButton.Size = UDim2.new(0, 120, 0, 120)
		jumpButton.Position = UDim2.new(1, -150, 1, -180)
		jumpButton.AnchorPoint = Vector2.new(0, 0)
		jumpButton.Text = "Jump"
		jumpButton.TextScaled = true
		jumpButton.Font = Enum.Font.GothamBold
		jumpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		jumpButton.TextColor3 = Color3.new(1, 1, 1)
		jumpButton.BackgroundTransparency = 0.2
		jumpButton.Parent = jumpGui

		jumpButton.MouseButton1Down:Connect(function()
			if isOnHoverboard and not isJumping then
				attemptJump()
			end
		end)

		mobileControls.JumpButton = jumpButton
	end
end

----------------------------------------------------------
-- Character setup + Knit lifecycle
----------------------------------------------------------

-- helper to refresh config when hoverboard changes
function HoverboardController:SetActiveHoverboard(boardName)
	local config = Hoverboards.GetConfig(boardName)
	if not config then
		warn("[HoverboardController] Could not find hoverboard config for " .. tostring(boardName))
		return
	end

	print("SetActiveHoverboard called")
	self.ActiveConfig = config
end

local function setupCharacter(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	-- On death: cleanup local references & restore animations
	humanoid.Died:Connect(function()
		cleanupHoverboard()
		resetStates()
		restoreAnimations()
	end)

	-- When character spawns, wait for server-cloned Hoverboard then bind constraints
	task.defer(function()
		HoverboardController:WaitForHoverboard()
	end)
end

function HoverboardController:KnitInit()
	print("Knit initialized")
end

function HoverboardController:KnitStart()
	print("knit started on client")
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner == player then
			self:SetActiveHoverboard(boardName)
			task.defer(function()
				print("Waiting for hoverboard...")
				self:WaitForHoverboard()
			end)
		end
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
	player.CharacterRemoving:Connect(function()
		resetStates()
		cleanupHoverboard()
	end)

	-- Main update loop
	RunService.Heartbeat:Connect(function(dt)
		if isOnHoverboard then
			updateMovement(dt)
			--checkFallToDeath()
		end
	end)

	-- Landing detection (RenderStepped for responsiveness)
	RunService.RenderStepped:Connect(function()
		if isJumping then
			local grounded = isGrounded()
			if grounded then
				isJumping = false
				canJump = true
			end
		end
	end)

	----------------------------------------------------------
	-- Input Handling
	----------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isOnHoverboard then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W then
				inputVector = Vector3.new(inputVector.X, 0, -1)
			elseif input.KeyCode == Enum.KeyCode.S then
				inputVector = Vector3.new(inputVector.X, 0, 1)
			elseif input.KeyCode == Enum.KeyCode.A then
				inputVector = Vector3.new(-1, 0, inputVector.Z)
			elseif input.KeyCode == Enum.KeyCode.D then
				inputVector = Vector3.new(1, 0, inputVector.Z)
			elseif input.KeyCode == Enum.KeyCode.Space and not isJumping then
				attemptJump()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not isOnHoverboard then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
				inputVector = Vector3.new(inputVector.X, 0, 0)
			elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
				inputVector = Vector3.new(0, 0, inputVector.Z)
			end
		end
	end)

	-- Mobile dynamic joystick fallback - sample MoveDirection
	RunService.RenderStepped:Connect(function()
		if UserInputService.TouchEnabled and isOnHoverboard then
			local moveDir = humanoid.MoveDirection
			if moveDir.Magnitude > 0 then
				inputVector = Vector3.new(moveDir.X, 0, -moveDir.Z)
			else
				inputVector = Vector3.zero
			end
		end
	end)
end

return HoverboardController
