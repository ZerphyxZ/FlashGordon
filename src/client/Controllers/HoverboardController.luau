-- local Global =
-- 	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
-- local Knit = Global.Knit
-- local Players = Global.Players
-- local RunService = Global.RunService
-- local UserInputService = Global.UserInputService
-- local TweenService = Global.TweenService
-- local workspace = Global.Workspace
-- local player = Players.LocalPlayer
-- local Hoverboards = require(
-- 	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboards")
-- )
-- local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
-- local HoverboardService

-- -- store config for currently equipped hoverboard
-- HoverboardController.ActiveConfig = nil

-- -- Constants
-- local CONSTANTS = {
-- 	MAX_SPEED = 65,
-- 	ACCELERATION = 1,
-- 	DECELERATION = 1,
-- 	MOVEMENT_SMOOTHNESS = 0.8,
-- 	BRAKE_FORCE = 10,
-- 	BRAKINGSPEED_THRESHOLD = 1,
-- 	ROTATION_SPEED = 65,
-- 	ROTATION_SMOOTHNESS = 0.1,
-- 	JUMP_POWER = 60,
-- 	MIN_JUMP_HEIGHT = 10,
-- 	MAX_JUMP_HEIGHT = 25,
-- 	STEP_MULTIPLIER = 1,
-- 	STUDS_MULTIPLIER = 5,
-- 	TILT_ANGLE = 15,
-- 	HOVER_HEIGHT = 2,
-- 	HOVER_SMOOTHNESS = 2,
-- 	RAYCAST_DISTANCE = 10,
-- 	DELTA_TIME = 0.01,

-- 	ORIENTATION_SMOOTHNESS = 12,
-- 	BODYGYRO_P = 8e4,
-- 	BODYGYRO_D = 600,
-- 	MIN_PROJECTED_MAG = 0.01,
-- }

-- -- State
-- local character = player.Character
-- local humanoid, humanoidRootPart
-- local hoverboard -- reference to server-cloned Hoverboard model
-- local bodyVelocity -- server-created BodyVelocity on HRP (client will update .Velocity)
-- local bodyGyro -- server-created BodyGyro on HRP (client will update .CFrame)
-- local hoverBodyPosition -- server-created BodyPosition under hoverboard primary part (client will update .Position)
-- local inputVector = Vector3.zero
-- local currentSpeed = 0
-- local isOnHoverboard = false

-- -- Jump / ground
-- local canJump = false
-- local isJumping = false
-- local jumpCooldown = 0.35
-- local lastJumpTime = 0
-- local lastMoveDir = Vector3.zero
-- local braking = false
-- local hoverOffset
-- local speedValue
-- local smoothedGroundNormal = nil

-- -- Mobile controls
-- local mobileControls = {}

-- ----------------------------------------------------------
-- -- GUI Setup
-- ----------------------------------------------------------
-- local function setupGUI()
-- 	if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SpeedGUI") then
-- 		-- already created
-- 		speedValue = player.PlayerGui.SpeedGUI:FindFirstChildWhichIsA("TextLabel", true)
-- 		return
-- 	end

-- 	local speedGui = Instance.new("ScreenGui")
-- 	speedGui.Name = "SpeedGUI"
-- 	speedGui.Parent = player:WaitForChild("PlayerGui")

-- 	local speedFrame = Instance.new("Frame")
-- 	speedFrame.Size = UDim2.new(0, 200, 0, 80)
-- 	speedFrame.Position = UDim2.new(0, 20, 0, 20)
-- 	speedFrame.BackgroundColor3 = Color3.new(0, 0, 0)
-- 	speedFrame.BackgroundTransparency = 0.3
-- 	speedFrame.BorderSizePixel = 0
-- 	speedFrame.Parent = speedGui

-- 	local speedLabel = Instance.new("TextLabel")
-- 	speedLabel.Size = UDim2.new(1, 0, 0.5, 0)
-- 	speedLabel.Position = UDim2.new(0, 0, 0, 0)
-- 	speedLabel.BackgroundTransparency = 1
-- 	speedLabel.Text = "SPEED"
-- 	speedLabel.TextColor3 = Color3.new(1, 1, 1)
-- 	speedLabel.TextScaled = true
-- 	speedLabel.Font = Enum.Font.GothamBold
-- 	speedLabel.Parent = speedFrame

-- 	speedValue = Instance.new("TextLabel")
-- 	speedValue.Size = UDim2.new(1, 0, 0.5, 0)
-- 	speedValue.Position = UDim2.new(0, 0, 0.5, 0)
-- 	speedValue.BackgroundTransparency = 1
-- 	speedValue.Text = "0"
-- 	speedValue.TextColor3 = Color3.new(1, 1, 1)
-- 	speedValue.TextScaled = true
-- 	speedValue.Font = Enum.Font.GothamBold
-- 	speedValue.Parent = speedFrame
-- end

-- local function resetStates()
-- 	hoverboard = nil
-- 	bodyVelocity = nil
-- 	bodyGyro = nil
-- 	hoverBodyPosition = nil
-- 	inputVector = Vector3.zero
-- 	currentSpeed = 0
-- 	isOnHoverboard = false

-- 	canJump = false
-- 	isJumping = false
-- 	lastJumpTime = 0
-- 	lastMoveDir = Vector3.zero
-- 	braking = false
-- 	hoverOffset = 0
-- end

-- ----------------------------------------------------------
-- -- Animation Control
-- ----------------------------------------------------------
-- local function disableAnimations()
-- 	local animate = character:FindFirstChild("Animate")
-- 	if animate then
-- 		animate.Enabled = false
-- 	end
-- 	if humanoid then
-- 		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
-- 	end
-- end

-- local function restoreAnimations()
-- 	local animate = character:FindFirstChild("Animate")
-- 	if animate then
-- 		animate.Enabled = true
-- 	end
-- end

-- -- Create client-owned physics helpers and local Motor6D for visuals
-- local function createClientConstraints()
-- 	if not humanoidRootPart or not hoverboard or not hoverboard.PrimaryPart then
-- 		return
-- 	end
-- 	-- BodyVelocity on HRP (client-owned)
-- 	if not humanoidRootPart:FindFirstChild("HoverBodyVelocity") then
-- 		local bv = Instance.new("BodyVelocity")
-- 		bv.Name = "HoverBodyVelocity"
-- 		bv.MaxForce = Vector3.new(1e5, 0, 1e5)
-- 		bv.Velocity = Vector3.new(0, 0, 0)
-- 		bv.P = 8e3
-- 		bv.Parent = humanoidRootPart
-- 		bodyVelocity = bv
-- 	else
-- 		bodyVelocity = humanoidRootPart:FindFirstChild("HoverBodyVelocity")
-- 	end

-- 	-- BodyGyro on HRP (client-owned)
-- 	if not humanoidRootPart:FindFirstChild("HoverBodyGyro") then
-- 		local bg = Instance.new("BodyGyro")
-- 		bg.Name = "HoverBodyGyro"
-- 		bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
-- 		bg.P = CONSTANTS.BODYGYRO_P
-- 		bg.D = CONSTANTS.BODYGYRO_D
-- 		bg.CFrame = humanoidRootPart.CFrame
-- 		bg.Parent = humanoidRootPart
-- 		bodyGyro = bg
-- 	else
-- 		bodyGyro = humanoidRootPart:FindFirstChild("HoverBodyGyro")
-- 	end

-- 	-- BodyPosition on hoverboard PrimaryPart (client-owned)
-- 	local primary = hoverboard.PrimaryPart
-- 	if primary and not primary:FindFirstChild("HoverPosition") then
-- 		local bp = Instance.new("BodyPosition")
-- 		bp.Name = "HoverPosition"
-- 		bp.MaxForce = Vector3.new(0, 1e6, 0)
-- 		bp.Position = primary.Position
-- 		bp.P = 7000
-- 		bp.D = 500
-- 		bp.Parent = primary
-- 		hoverBodyPosition = bp
-- 	else
-- 		hoverBodyPosition = primary and primary:FindFirstChild("HoverPosition")
-- 	end
-- end

-- function HoverboardController:WaitForHoverboard()
-- 	if not character then
-- 		return
-- 	end
-- 	local hb = character:WaitForChild("Hoverboard", 5)
-- 	if hb then
-- 		print("Hoverboard detected:", hb.Name)
-- 		hoverboard = hb

-- 		-- Instead of repositioning the hoverboard client-side, read server Motor6D to determine offset for local visuals
-- 		local hrp = character:FindFirstChild("HumanoidRootPart")
-- 		local motor6D = hrp and hrp:FindFirstChild("HoverboardMotor")
-- 		if motor6D and motor6D:IsA("Motor6D") then
-- 			-- Motor6D.C0 was set by the server to CFrame.new(0, -offset, 0)
-- 			-- We store the offset as positive value for local math usage
-- 			local c0Pos = motor6D.C0.Position
-- 			hoverOffset = -c0Pos.Y
-- 		else
-- 			-- Fallback: measure model bounding box relative to HRP (non-authoritative, just for visuals)
-- 			hoverOffset = 0
-- 		end

-- 		-- create physics constraints
-- 		--bindServerConstraints()
-- 		createClientConstraints()
-- 		isOnHoverboard = true
-- 		disableAnimations()
-- 		setupGUI()
-- 		print("Hoverboard detected (server-cloned):", hb.Name)
-- 	end
-- end

-- ----------------------------------------------------------
-- -- Jump handling
-- ----------------------------------------------------------
-- local function isGrounded()
-- 	if not hoverboard or not hoverboard.PrimaryPart then
-- 		return false, nil, nil
-- 	end

-- 	local primary = hoverboard.PrimaryPart
-- 	local rayOrigin = primary.Position
-- 	local rayDir = Vector3.new(0, -CONSTANTS.RAYCAST_DISTANCE, 0)

-- 	local params = RaycastParams.new()
-- 	params.FilterType = Enum.RaycastFilterType.Exclude
-- 	params.FilterDescendantsInstances = { character, hoverboard }

-- 	local result = workspace:Raycast(rayOrigin, rayDir, params)
-- 	if result then
-- 		local distance = primary.Position.Y - result.Position.Y
-- 		if distance <= (CONSTANTS.HOVER_HEIGHT + 1.5) then
-- 			return true, result.Position, result.Normal
-- 		end
-- 	end
-- 	return false, nil, nil
-- end

-- local function attemptJump()
-- 	local now = tick()
-- 	if now - lastJumpTime < jumpCooldown then
-- 		return
-- 	end
-- 	local grounded = isGrounded()
-- 	if not grounded or isJumping then
-- 		return
-- 	end

-- 	lastJumpTime = now
-- 	isJumping = true
-- 	canJump = false

-- 	local speedRatio = math.clamp(currentSpeed / CONSTANTS.MAX_SPEED, 0, 1)
-- 	local jumpHeight = CONSTANTS.MIN_JUMP_HEIGHT
-- 		+ (
-- 			math.floor((CONSTANTS.MAX_JUMP_HEIGHT - CONSTANTS.MIN_JUMP_HEIGHT) * speedRatio / CONSTANTS.STEP_MULTIPLIER)
-- 			* CONSTANTS.STEP_MULTIPLIER
-- 		)

-- 	local jumpVelocity = jumpHeight * CONSTANTS.STUDS_MULTIPLIER

-- 	local currentVelocity = humanoidRootPart.Velocity
-- 	humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, 50, currentVelocity.Z)

-- 	if hoverBodyPosition then
-- 		hoverBodyPosition.MaxForce = Vector3.zero
-- 		task.delay(0.5, function()
-- 			if hoverBodyPosition and hoverBodyPosition.Parent then
-- 				hoverBodyPosition.MaxForce = Vector3.new(0, 1e6, 0)
-- 			end
-- 		end)
-- 	end
-- end

-- ----------------------------------------------------------
-- -- Movement + Hover Update (client updates server-owned constraints)
-- ----------------------------------------------------------

-- -- Align player's HumanoidRootPart with the surface normal
-- local function alignPlayerToSurface(dt)
-- 	if not humanoidRootPart or not hoverboard then
-- 		return
-- 	end

-- 	-- Raycast down from HRP to find surface normal
-- 	local origin = humanoidRootPart.Position
-- 	local direction = Vector3.new(0, -1, 0) * CONSTANTS.RAYCAST_DISTANCE

-- 	local params = RaycastParams.new()
-- 	params.FilterType = Enum.RaycastFilterType.Exclude
-- 	params.FilterDescendantsInstances = { character, hoverboard }

-- 	local result = workspace:Raycast(origin, direction, params)
-- 	if not result then
-- 		return
-- 	end

-- 	local surfaceNormal = result.Normal
-- 	-- compute forward projected onto the plane of the surface (so forward stays tangent to surface)
-- 	local rootForward = humanoidRootPart.CFrame.LookVector
-- 	local forwardProj = rootForward - surfaceNormal * rootForward:Dot(surfaceNormal)
-- 	if forwardProj.Magnitude <= 1e-5 then
-- 		-- fallback: use a forward that is perpendicular to normal if projection degenerated
-- 		forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
-- 		if forwardProj.Magnitude <= 1e-5 then
-- 			forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
-- 		end
-- 	end
-- 	forwardProj = forwardProj.Unit

-- 	-- compute a smooth interpolation factor (frame-rate independent)
-- 	local orientSmooth = math.clamp(dt * CONSTANTS.ORIENTATION_SMOOTHNESS, 0, 1)

-- 	-- smooth the normal to avoid jitter
-- 	if not smoothedGroundNormal then
-- 		smoothedGroundNormal = surfaceNormal
-- 	else
-- 		smoothedGroundNormal = smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)
-- 	end
-- 	local finalNormal = smoothedGroundNormal.Unit

-- 	-- recompute forward based on smoothed normal
-- 	local finalForward = forwardProj - finalNormal * forwardProj:Dot(finalNormal)
-- 	if finalForward.Magnitude <= 1e-5 then
-- 		finalForward = Vector3.new(0, 0, -1)
-- 	end
-- 	finalForward = finalForward.Unit

-- 	-- target CFrame that has forward facing along finalForward and up = finalNormal
-- 	local targetCFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + finalForward, finalNormal)

-- 	-- Prefer using client-owned BodyGyro to steer orientation (less jitter than setting CFrame directly).
-- 	if bodyGyro and bodyGyro.Parent then
-- 		-- Smoothly interpolate between current bodyGyro orientation and target
-- 		local currentOrient = bodyGyro.CFrame
-- 		local currentPos = humanoidRootPart.Position
-- 		-- Extract rotation component and lerp using slerp-like approach through CFrame:Lerp
-- 		local lerpT = orientSmooth
-- 		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
-- 		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
-- 	else
-- 		-- Fallback: lerp HRP CFrame directly (less preferred)
-- 		local current = humanoidRootPart.CFrame
-- 		humanoidRootPart.CFrame = current:Lerp(targetCFrame, orientSmooth)
-- 	end
-- end

-- local function updateMovement(dt)
-- 	if not isOnHoverboard or not hoverboard or not hoverboard.PrimaryPart then
-- 		return
-- 	end

-- 	local cfg = HoverboardController.ActiveConfig or {}
-- 	local MAX_SPEED = cfg.TopSpeed or CONSTANTS.MAX_SPEED
-- 	local ACCELERATION = cfg.Acceleration or CONSTANTS.ACCELERATION
-- 	local DECELERATION = cfg.Deceleration or CONSTANTS.DECELERATION
-- 	local JUMP_POWER = cfg.JumpPower or CONSTANTS.JUMP_POWER

-- 	local camera = workspace.CurrentCamera
-- 	local lookDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
-- 	if lookDir.Magnitude > 0 then
-- 		lookDir = lookDir.Unit
-- 	end
-- 	local rightDir = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
-- 	if rightDir.Magnitude > 0 then
-- 		rightDir = rightDir.Unit
-- 	end

-- 	local moveDir = (lookDir * -inputVector.Z + rightDir * inputVector.X)
-- 	moveDir = moveDir.Magnitude > 0 and moveDir.Unit or Vector3.zero

-- 	if moveDir.Magnitude > 0 then
-- 		lastMoveDir = moveDir
-- 	end

-- 	local targetSpeed = moveDir.Magnitude > 0 and MAX_SPEED or 0
-- 	local rate = moveDir.Magnitude > 0 and ACCELERATION or DECELERATION
-- 	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * rate * dt * CONSTANTS.MOVEMENT_SMOOTHNESS
-- 	currentSpeed = math.clamp(currentSpeed, 0, MAX_SPEED)

-- 	--=========================================
-- 	-- SMOOTH WALL HANDLING SYSTEM
-- 	--=========================================
-- 	local wallHit = nil
-- 	local wallNormal = nil
-- 	local wallDistance = math.huge
-- 	local probeDir = Vector3.zero

-- 	-- Calculate probe direction
-- 	if moveDir.Magnitude > 0 then
-- 		probeDir = moveDir
-- 	elseif lastMoveDir and lastMoveDir.Magnitude > 0 then
-- 		probeDir = lastMoveDir
-- 	else
-- 		probeDir = Vector3.new(humanoidRootPart.CFrame.LookVector.X, 0, humanoidRootPart.CFrame.LookVector.Z)
-- 	end

-- 	if probeDir.Magnitude > 0 then
-- 		probeDir = probeDir.Unit
-- 		local params = RaycastParams.new()
-- 		params.FilterType = Enum.RaycastFilterType.Exclude
-- 		params.FilterDescendantsInstances = { character, hoverboard }

-- 		-- Use multiple rays for better detection
-- 		local probeDistance = math.clamp(3.0 + (currentSpeed / MAX_SPEED) * 4, 3.0, 6.0)
-- 		local origin = humanoidRootPart.Position + Vector3.new(0, 1.2, 0)

-- 		-- Cast multiple rays in a small cone for better detection
-- 		local rayDirections = {
-- 			probeDir,
-- 			(probeDir + probeDir:Cross(Vector3.new(0, 1, 0)) * 0.1).Unit,
-- 			(probeDir - probeDir:Cross(Vector3.new(0, 1, 0)) * 0.1).Unit,
-- 		}

-- 		for _, rayDir in ipairs(rayDirections) do
-- 			local result = workspace:Raycast(origin, rayDir * probeDistance, params)
-- 			if result then
-- 				local dist = (result.Position - origin).Magnitude
-- 				if dist < wallDistance then
-- 					wallDistance = dist
-- 					wallHit = result
-- 					wallNormal = result.Normal
-- 				end
-- 			end
-- 		end
-- 	end

-- 	-- Smooth wall avoidance with progressive response
-- 	if wallHit and wallNormal then
-- 		local CLAMP_DISTANCE = 2.0 -- Increased for smoother transition
-- 		local SLOW_DOWN_DISTANCE = 4.0 -- Start slowing down earlier

-- 		-- Calculate normalized distance (0 = at clamp, 1 = at slow down distance)
-- 		local normalizedDist = math.clamp((wallDistance - CLAMP_DISTANCE) / (SLOW_DOWN_DISTANCE - CLAMP_DISTANCE), 0, 1)

-- 		-- Progressive deceleration based on distance
-- 		if wallDistance < SLOW_DOWN_DISTANCE then
-- 			local decelIntensity = 1 - normalizedDist
-- 			local smoothDecel = decelIntensity * decelIntensity -- Quadratic for smoother start

-- 			-- Very gentle deceleration
-- 			currentSpeed = currentSpeed * (1 - smoothDecel * DECELERATION * dt * 0.5)

-- 			-- Gentle push-away force using velocity instead of direct position changes
-- 			if wallDistance < CLAMP_DISTANCE + 0.5 then
-- 				local pushFactor = math.clamp((CLAMP_DISTANCE + 0.5 - wallDistance) / 0.5, 0, 1)
-- 				local pushStrength = pushFactor * pushFactor * 2.0 -- Gentle velocity push

-- 				if bodyVelocity and bodyVelocity.Parent then
-- 					local currentVel = humanoidRootPart.AssemblyLinearVelocity
-- 					local pushVelocity = wallNormal * pushStrength

-- 					-- Only apply horizontal push, preserve vertical velocity for hover system
-- 					local newVelocity = Vector3.new(
-- 						currentVel.X + pushVelocity.X,
-- 						currentVel.Y, -- Keep original Y velocity - CRITICAL FOR HOVER
-- 						currentVel.Z + pushVelocity.Z
-- 					)

-- 					-- Smooth velocity transition
-- 					local velT = math.clamp(dt * 8, 0, 1)
-- 					bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(newVelocity, velT)
-- 				end
-- 			end

-- 			-- Ultra-smooth 90-degree redirection
-- 			if decelIntensity > 0.3 and bodyGyro and bodyGyro.Parent then
-- 				-- Calculate optimal rotation direction (away from wall)
-- 				local currentFacing =
-- 					Vector3.new(humanoidRootPart.CFrame.LookVector.X, 0, humanoidRootPart.CFrame.LookVector.Z)
-- 				if currentFacing.Magnitude > 0 then
-- 					currentFacing = currentFacing.Unit

-- 					-- Project current facing onto wall plane
-- 					local wallFacing = currentFacing - wallNormal * currentFacing:Dot(wallNormal)
-- 					if wallFacing.Magnitude > 0 then
-- 						wallFacing = wallFacing.Unit

-- 						-- Choose the rotation that maintains speed better
-- 						local rightFacing = wallNormal:Cross(Vector3.new(0, 1, 0))
-- 						if rightFacing.Magnitude > 0 then
-- 							rightFacing = rightFacing.Unit

-- 							-- Determine which direction is closer to our current movement
-- 							local dotRight = currentFacing:Dot(rightFacing)
-- 							local dotLeft = currentFacing:Dot(-rightFacing)

-- 							local targetFacing = dotRight > dotLeft and rightFacing or -rightFacing

-- 							-- EXTREMELY smooth rotation
-- 							local rotationProgress = (decelIntensity - 0.3) / 0.7 -- Normalize to 0-1
-- 							local smoothRotationProgress = 1 - math.cos(rotationProgress * math.pi * 0.5) -- Ease-out curve

-- 							-- Blend between current facing and target facing
-- 							local blendedFacing = currentFacing:Lerp(targetFacing, smoothRotationProgress * 0.5) -- Very slow blend
-- 							blendedFacing = Vector3.new(blendedFacing.X, 0, blendedFacing.Z)
-- 							if blendedFacing.Magnitude > 0 then
-- 								blendedFacing = blendedFacing.Unit

-- 								-- Update movement direction
-- 								lastMoveDir = blendedFacing

-- 								-- Apply ultra-smooth rotation to body gyro
-- 								local currentCF = bodyGyro.CFrame
-- 								local targetCF = CFrame.lookAt(
-- 									humanoidRootPart.Position,
-- 									humanoidRootPart.Position + blendedFacing,
-- 									Vector3.new(0, 1, 0)
-- 								)

-- 								-- Very slow rotation for maximum smoothness
-- 								local rotationLerp = math.clamp(dt * CONSTANTS.ROTATION_SPEED * 0.3, 0, 0.5)
-- 								local newRot = (currentCF - currentCF.Position):Lerp(
-- 									targetCF - targetCF.Position,
-- 									rotationLerp
-- 								)
-- 								bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot
-- 							end
-- 						end
-- 					end
-- 				end
-- 			end

-- 			-- Gentle speed reduction when rotating
-- 			if wallDistance < CLAMP_DISTANCE + 1.0 then
-- 				local speedReduction = math.clamp((CLAMP_DISTANCE + 1.0 - wallDistance) / 1.0, 0, 1)
-- 				currentSpeed = currentSpeed * (1 - speedReduction * 0.01) -- Minimal speed reduction
-- 			end
-- 		end
-- 	end

-- 	-- Stop completely if speed is very low (prevent crawling)
-- 	if currentSpeed < 0.3 then
-- 		currentSpeed = 0
-- 	end

-- 	--=========================================
-- 	-- Apply horizontal velocity
-- 	--=========================================
-- 	local effectiveDir = (currentSpeed > 0) and lastMoveDir or Vector3.zero
-- 	local velocity = effectiveDir * currentSpeed
-- 	local currentVel = humanoidRootPart.AssemblyLinearVelocity

-- 	if bodyVelocity and bodyVelocity.Parent then
-- 		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
-- 		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
-- 		local velT = math.clamp(dt * 12, 0, 1)
-- 		local newHoriz = curHoriz:Lerp(horiz, velT)
-- 		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
-- 	end

-- 	--=========================================
-- 	-- Rotation smoothing
-- 	--=========================================
-- 	if effectiveDir.Magnitude > 0 and bodyGyro and bodyGyro.Parent then
-- 		local candidateNormal = smoothedGroundNormal or Vector3.new(0, 1, 0)
-- 		local forwardProj = effectiveDir - candidateNormal * effectiveDir:Dot(candidateNormal)
-- 		if forwardProj.Magnitude < 1e-5 then
-- 			forwardProj = (candidateNormal:Cross(Vector3.new(0, 0, -1)))
-- 			if forwardProj.Magnitude < 1e-5 then
-- 				forwardProj = Vector3.new(0, 0, -1)
-- 			end
-- 		end
-- 		forwardProj = forwardProj.Unit

-- 		local targetPlayerCFrame =
-- 			CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + forwardProj, candidateNormal)
-- 		local rotSmooth = math.clamp(dt * CONSTANTS.ROTATION_SPEED * CONSTANTS.ROTATION_SMOOTHNESS, 0, 1)
-- 		local currentCF = bodyGyro.CFrame
-- 		local newRot = (currentCF - currentCF.Position):Lerp(
-- 			targetPlayerCFrame - targetPlayerCFrame.Position,
-- 			rotSmooth
-- 		)
-- 		bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot
-- 	end

-- 	--=========================================
-- 	-- Hover + Surface alignment (unchanged)
-- 	--=========================================
-- 	local primary = hoverboard.PrimaryPart
-- 	if primary then
-- 		local params = RaycastParams.new()
-- 		params.FilterType = Enum.RaycastFilterType.Exclude
-- 		params.FilterDescendantsInstances = { character, hoverboard }

-- 		local size = primary.Size
-- 		local rayLength = CONSTANTS.RAYCAST_DISTANCE
-- 		local rayOffsets = {
-- 			Vector3.new(size.X / 2, 0, size.Z / 2),
-- 			Vector3.new(-size.X / 2, 0, size.Z / 2),
-- 			Vector3.new(size.X / 2, 0, -size.Z / 2),
-- 			Vector3.new(-size.X / 2, 0, -size.Z / 2),
-- 		}

-- 		local hitPositions = {}
-- 		local hitNormals = {}

-- 		for _, offset in ipairs(rayOffsets) do
-- 			local origin = primary.CFrame:PointToWorldSpace(offset + Vector3.new(0, 0.2, 0))
-- 			local direction = Vector3.new(0, -rayLength, 0)
-- 			local result = workspace:Raycast(origin, direction, params)
-- 			if result then
-- 				table.insert(hitPositions, result.Position)
-- 				table.insert(hitNormals, result.Normal)
-- 			end
-- 		end

-- 		if #hitPositions > 0 and not isJumping then
-- 			local avgPos = Vector3.zero
-- 			local avgNormal = Vector3.zero
-- 			for i = 1, #hitPositions do
-- 				avgPos = avgPos + hitPositions[i]
-- 				avgNormal = avgNormal + hitNormals[i]
-- 			end
-- 			avgPos = avgPos / #hitPositions
-- 			avgNormal = avgNormal.Unit

-- 			local hoverT = math.clamp(1 - math.exp(-CONSTANTS.HOVER_SMOOTHNESS * dt * 10), 0, 1)
-- 			smoothedGroundNormal = smoothedGroundNormal and smoothedGroundNormal:Lerp(avgNormal, hoverT) or avgNormal

-- 			local finalNormal = smoothedGroundNormal.Unit
-- 			local targetY = avgPos.Y + CONSTANTS.HOVER_HEIGHT
-- 			if hoverBodyPosition and hoverBodyPosition.Parent then
-- 				local currentBP = hoverBodyPosition.Position
-- 				local targetBP = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
-- 				local posT = math.clamp(dt * 10, 0, 1)
-- 				local newBP = currentBP:Lerp(targetBP, posT)
-- 				hoverBodyPosition.Position = newBP
-- 			end

-- 			local playerForward = humanoidRootPart.CFrame.LookVector
-- 			local forwardOnPlane = playerForward - finalNormal * playerForward:Dot(finalNormal)
-- 			if forwardOnPlane.Magnitude <= 1e-5 then
-- 				forwardOnPlane = (
-- 					lastMoveDir.Magnitude > 0 and (lastMoveDir - finalNormal * lastMoveDir:Dot(finalNormal))
-- 				) or Vector3.new(0, 0, -1)
-- 			end
-- 			forwardOnPlane = forwardOnPlane.Unit

-- 			local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, finalNormal)
-- 			local primaryT = math.clamp(dt * CONSTANTS.HOVER_SMOOTHNESS * 6, 0, 1)
-- 			primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)

-- 			local playerTargetCF =
-- 				CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + forwardOnPlane, finalNormal)
-- 			local orientT = math.clamp(dt * CONSTANTS.ORIENTATION_SMOOTHNESS, 0, 1)
-- 			if bodyGyro and bodyGyro.Parent then
-- 				local curr = bodyGyro.CFrame
-- 				local newRot = (curr - curr.Position):Lerp(playerTargetCF - playerTargetCF.Position, orientT)
-- 				bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot
-- 			else
-- 				humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(playerTargetCF, orientT)
-- 			end
-- 		else
-- 			if hoverBodyPosition and hoverBodyPosition.Parent then
-- 				hoverBodyPosition.MaxForce = Vector3.zero
-- 			end
-- 		end
-- 	end

-- 	--=========================================
-- 	-- Speed GUI
-- 	--=========================================
-- 	if speedValue then
-- 		speedValue.Text = tostring(math.floor(currentSpeed))
-- 	end

-- end

-- ----------------------------------------------------------
-- -- Cleanup & Reset (client-side only — DO NOT destroy server constraints)
-- ----------------------------------------------------------
-- local function cleanupHoverboard()
-- 	isOnHoverboard = false

-- 	-- Destroy client-owned physics objects
-- 	if bodyVelocity and bodyVelocity.Parent then
-- 		bodyVelocity:Destroy()
-- 	end
-- 	if bodyGyro and bodyGyro.Parent then
-- 		bodyGyro:Destroy()
-- 	end
-- 	if hoverBodyPosition and hoverBodyPosition.Parent then
-- 		hoverBodyPosition:Destroy()
-- 	end
-- 	-- local motor
-- 	local localMotor = humanoidRootPart and humanoidRootPart:FindFirstChild("HoverboardMotorLocal")
-- 	if localMotor then
-- 		localMotor:Destroy()
-- 	end

-- 	-- Client should NOT destroy server-owned constraints; only clear references
-- 	bodyVelocity = nil
-- 	bodyGyro = nil
-- 	hoverBodyPosition = nil

-- 	-- Remove visual GUI controls for mobile
-- 	if mobileControls.JumpButton then
-- 		if mobileControls.JumpButton.Parent then
-- 			mobileControls.JumpButton.Parent:Destroy()
-- 		end
-- 		mobileControls.JumpButton = nil
-- 	end
-- 	hoverboard = nil
-- end

-- ----------------------------------------------------------
-- -- Mobile Controls
-- ----------------------------------------------------------
-- function HoverboardController:setupMobileControls()
-- 	if UserInputService.TouchEnabled and not mobileControls.JumpButton then
-- 		local playerGui = player:WaitForChild("PlayerGui")

-- 		local jumpGui = Instance.new("ScreenGui")
-- 		jumpGui.Name = "HoverboardJumpGUI"
-- 		jumpGui.ResetOnSpawn = false
-- 		jumpGui.Parent = playerGui

-- 		local jumpButton = Instance.new("TextButton")
-- 		jumpButton.Name = "JumpButton"
-- 		jumpButton.Size = UDim2.new(0, 120, 0, 120)
-- 		jumpButton.Position = UDim2.new(1, -150, 1, -180)
-- 		jumpButton.AnchorPoint = Vector2.new(0, 0)
-- 		jumpButton.Text = "Jump"
-- 		jumpButton.TextScaled = true
-- 		jumpButton.Font = Enum.Font.GothamBold
-- 		jumpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
-- 		jumpButton.TextColor3 = Color3.new(1, 1, 1)
-- 		jumpButton.BackgroundTransparency = 0.2
-- 		jumpButton.Parent = jumpGui

-- 		jumpButton.MouseButton1Down:Connect(function()
-- 			if isOnHoverboard and not isJumping then
-- 				attemptJump()
-- 			end
-- 		end)

-- 		mobileControls.JumpButton = jumpButton
-- 	end
-- end

-- ----------------------------------------------------------
-- -- Character setup + Knit lifecycle
-- ----------------------------------------------------------

-- -- helper to refresh config when hoverboard changes
-- function HoverboardController:SetActiveHoverboard(boardName)
-- 	local config = Hoverboards.GetConfig(boardName)
-- 	if not config then
-- 		warn("[HoverboardController] Could not find hoverboard config for " .. tostring(boardName))
-- 		return
-- 	end

-- 	print("SetActiveHoverboard called")
-- 	self.ActiveConfig = config
-- end

-- local function setupCharacter(newChar)
-- 	character = newChar
-- 	humanoid = character:WaitForChild("Humanoid")
-- 	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- 	-- On death: cleanup local references & restore animations
-- 	humanoid.Died:Connect(function()
-- 		cleanupHoverboard()
-- 		resetStates()
-- 		restoreAnimations()
-- 	end)

-- 	-- When character spawns, wait for server-cloned Hoverboard then bind constraints
-- 	task.defer(function()
-- 		HoverboardController:WaitForHoverboard()
-- 	end)
-- end

-- function HoverboardController:KnitInit()
-- 	print("Knit initialized")
-- end

-- function HoverboardController:KnitStart()
-- 	print("knit started on client")
-- 	HoverboardService = Knit.GetService("HoverboardService")
-- 	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
-- 		if owner == player then
-- 			self:SetActiveHoverboard(boardName)
-- 			task.defer(function()
-- 				print("Waiting for hoverboard...")
-- 				self:WaitForHoverboard()
-- 			end)
-- 		end
-- 	end)

-- 	if player.Character then
-- 		setupCharacter(player.Character)
-- 	end
-- 	player.CharacterAdded:Connect(setupCharacter)
-- 	player.CharacterRemoving:Connect(function()
-- 		resetStates()
-- 		cleanupHoverboard()
-- 	end)

-- 	-- Main update loop
-- 	RunService.Heartbeat:Connect(function(dt)
-- 		if isOnHoverboard then
-- 			updateMovement(dt)
-- 			--checkFallToDeath()
-- 		end
-- 	end)

-- 	-- Landing detection (RenderStepped for responsiveness)
-- 	RunService.RenderStepped:Connect(function(dt)
-- 		if isJumping then
-- 			local grounded = isGrounded()
-- 			if grounded then
-- 				isJumping = false
-- 				canJump = true
-- 			end
-- 		end

-- 		alignPlayerToSurface(dt)
-- 	end)

-- 	----------------------------------------------------------
-- 	-- Input Handling
-- 	----------------------------------------------------------
-- 	UserInputService.InputBegan:Connect(function(input, gameProcessed)
-- 		if gameProcessed or not isOnHoverboard then
-- 			return
-- 		end

-- 		if input.UserInputType == Enum.UserInputType.Keyboard then
-- 			if input.KeyCode == Enum.KeyCode.W then
-- 				inputVector = Vector3.new(inputVector.X, 0, -1)
-- 			elseif input.KeyCode == Enum.KeyCode.S then
-- 				inputVector = Vector3.new(inputVector.X, 0, 1)
-- 			elseif input.KeyCode == Enum.KeyCode.A then
-- 				inputVector = Vector3.new(-1, 0, inputVector.Z)
-- 			elseif input.KeyCode == Enum.KeyCode.D then
-- 				inputVector = Vector3.new(1, 0, inputVector.Z)
-- 			elseif input.KeyCode == Enum.KeyCode.Space and not isJumping then
-- 				attemptJump()
-- 			end
-- 		end
-- 	end)

-- 	UserInputService.InputEnded:Connect(function(input)
-- 		if not isOnHoverboard then
-- 			return
-- 		end

-- 		if input.UserInputType == Enum.UserInputType.Keyboard then
-- 			if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
-- 				inputVector = Vector3.new(inputVector.X, 0, 0)
-- 			elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
-- 				inputVector = Vector3.new(0, 0, inputVector.Z)
-- 			end
-- 		end
-- 	end)

-- 	-- Mobile dynamic joystick fallback - sample MoveDirection
-- 	RunService.RenderStepped:Connect(function()
-- 		if UserInputService.TouchEnabled and isOnHoverboard then
-- 			local moveDir = humanoid.MoveDirection
-- 			if moveDir.Magnitude > 0 then
-- 				inputVector = Vector3.new(moveDir.X, 0, -moveDir.Z)
-- 			else
-- 				inputVector = Vector3.zero
-- 			end
-- 		end
-- 	end)
-- end

-- return HoverboardController

local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local RunService = Global.RunService
local UserInputService = Global.UserInputService
local TweenService = Global.TweenService
local workspace = Global.Workspace
local ReplicatedStorage = Global.ReplicatedStorage

local player = Players.LocalPlayer
local Hoverboards = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Hoverboard")
		:WaitForChild("Hoverboards")
)
local HoverboardConstants = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Hoverboard")
		:WaitForChild("HoverboardConstants")
)
local CollisionManager = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Hoverboard")
		:WaitForChild("CollisionManager")
)

-- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- Module-level variables
local character, humanoid, humanoidRootPart
local hoverboard, bodyVelocity, bodyGyro, hoverBodyPosition
local inputVector = Vector3.zero
local currentSpeed = 0
local isOnHoverboard = false
local speedValue

-- Mobile controls
local mobileControls = {}

-- Local references for better performance
local MOVEMENT = HoverboardConstants.Movement
local JUMPING = HoverboardConstants.Jumping
local HOVER = HoverboardConstants.Hover
local PHYSICS = HoverboardConstants.Physics
local INPUT = HoverboardConstants.Input

-- State management
local State = {
	canJump = false,
	isJumping = false,
	lastJumpTime = 0,
	lastMoveDir = Vector3.zero,
	braking = false,
	hoverOffset = 0,
	smoothedGroundNormal = nil,
	isCollidingWithWall = false,
	collisionNormal = Vector3.zero,
	collisionRecoveryTimer = 0,
	smoothedTilt = 0,
	lastForwardWanted = nil,
	bobTime = 0,
	baseHoverHeight = HOVER.HOVER_HEIGHT,
}

--[[
    Utility Functions
]]
--
local Utilities = {}

function Utilities.ProjectVectorOnPlane(vector, planeNormal)
	local projection = vector - planeNormal * vector:Dot(planeNormal)
	return projection.Magnitude > 1e-5 and projection.Unit or Vector3.zero
end

function Utilities.SmoothDamp(current, target, smoothTime, dt)
	return current + (target - current) * (1 - math.exp(-smoothTime * dt))
end

function Utilities.CalculateMoveDirection(camera, inputVec)
	local lookDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local rightDir = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

	if lookDir.Magnitude > 0 then
		lookDir = lookDir.Unit
	end
	if rightDir.Magnitude > 0 then
		rightDir = rightDir.Unit
	end

	return (lookDir * -inputVec.Z + rightDir * inputVec.X)
end

function Utilities.CreateConstraint(part, className, properties)
	local constraint = Instance.new(className)
	for property, value in pairs(properties) do
		constraint[property] = value
	end
	constraint.Parent = part
	return constraint
end

--[[
    GUI Management
]]
--
local GUIManager = {}

function GUIManager.SetupSpeedGUI()
	if player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SpeedGUI") then
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

function GUIManager.UpdateSpeedDisplay()
	if speedValue then
		speedValue.Text = tostring(math.floor(currentSpeed))
	end
end

--[[
    Animation Management
]]
--
local AnimationManager = {}

function AnimationManager.DisableAnimations()
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Enabled = false
	end
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

function AnimationManager.RestoreAnimations()
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Enabled = true
	end
end

--[[
    Physics Constraints Management
]]
--
local PhysicsManager = {}

function PhysicsManager.CreateClientConstraints()
	if not humanoidRootPart or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	-- BodyVelocity
	if not humanoidRootPart:FindFirstChild("HoverBodyVelocity") then
		bodyVelocity = Utilities.CreateConstraint(humanoidRootPart, "BodyVelocity", {
			Name = "HoverBodyVelocity",
			MaxForce = PHYSICS.BODY_VELOCITY_MAX_FORCE,
			Velocity = Vector3.new(0, 0, 0),
			P = PHYSICS.BODY_VELOCITY_P,
		})
	else
		bodyVelocity = humanoidRootPart:FindFirstChild("HoverBodyVelocity")
	end

	-- BodyGyro
	if not humanoidRootPart:FindFirstChild("HoverBodyGyro") then
		bodyGyro = Utilities.CreateConstraint(humanoidRootPart, "BodyGyro", {
			Name = "HoverBodyGyro",
			MaxTorque = PHYSICS.BODY_GYRO_MAX_TORQUE,
			P = HOVER.BODYGYRO_P,
			D = HOVER.BODYGYRO_D,
			CFrame = humanoidRootPart.CFrame,
		})
	else
		bodyGyro = humanoidRootPart:FindFirstChild("HoverBodyGyro")
	end

	-- BodyPosition for hoverboard
	local primary = hoverboard.PrimaryPart
	if primary and not primary:FindFirstChild("HoverPosition") then
		hoverBodyPosition = Utilities.CreateConstraint(primary, "BodyPosition", {
			Name = "HoverPosition",
			MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE,
			Position = primary.Position,
			P = PHYSICS.BODY_POSITION_P,
			D = PHYSICS.BODY_POSITION_D,
		})
	else
		hoverBodyPosition = primary and primary:FindFirstChild("HoverPosition")
	end
end

function PhysicsManager.CleanupConstraints()
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	if bodyGyro and bodyGyro.Parent then
		bodyGyro:Destroy()
	end
	if hoverBodyPosition and hoverBodyPosition.Parent then
		hoverBodyPosition:Destroy()
	end

	local localMotor = humanoidRootPart and humanoidRootPart:FindFirstChild("HoverboardMotorLocal")
	if localMotor then
		localMotor:Destroy()
	end

	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
end

--[[
    Ground Detection & Jumping
]]
--
local JumpManager = {}

function JumpManager.IsGrounded()
	if not hoverboard or not hoverboard.PrimaryPart then
		return false, nil, nil
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
		if distance <= (HOVER.HOVER_HEIGHT + 1.5) then
			return true, result.Position, result.Normal
		end
	end
	return false, nil, nil
end

function JumpManager.AttemptJump()
	local now = tick()
	if now - State.lastJumpTime < JUMPING.JUMP_COOLDOWN then
		return
	end

	local grounded = JumpManager.IsGrounded()
	if not grounded or State.isJumping then
		return
	end

	State.lastJumpTime = now
	State.isJumping = true
	State.canJump = false

	local speedRatio = math.clamp(currentSpeed / MOVEMENT.MAX_SPEED, 0, 1)
	local jumpHeight = JUMPING.MIN_JUMP_HEIGHT
		+ math.floor((JUMPING.MAX_JUMP_HEIGHT - JUMPING.MIN_JUMP_HEIGHT) * speedRatio / JUMPING.STEP_MULTIPLIER)
			* JUMPING.STEP_MULTIPLIER

	local currentVelocity = humanoidRootPart.Velocity
	humanoidRootPart.Velocity = Vector3.new(currentVelocity.X, JUMPING.JUMP_VELOCITY_Y, currentVelocity.Z)

	if hoverBodyPosition then
		hoverBodyPosition.MaxForce = Vector3.zero
		task.delay(JUMPING.HOVER_DISABLE_TIME, function()
			if hoverBodyPosition and hoverBodyPosition.Parent then
				hoverBodyPosition.MaxForce = PHYSICS.BODY_POSITION_MAX_FORCE
			end
		end)
	end
end

--[[
    Movement System
]]
--
local MovementManager = {}

function MovementManager.CalculateSpeed(Acceleration, Deceleration, targetSpeed, dt, isMoving)
	local rate = isMoving and Acceleration or Deceleration
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * rate * dt * MOVEMENT.MOVEMENT_SMOOTHNESS
	currentSpeed = math.clamp(currentSpeed, 0, MOVEMENT.MAX_SPEED)
end

function MovementManager.ApplyMovement(moveDir, dt)
	local cfg = HoverboardController.ActiveConfig or {}
	local MAX_SPEED = cfg.TopSpeed or MOVEMENT.MAX_SPEED
	local ACCELERATION = cfg.Acceleration or MOVEMENT.ACCELERATION
	local DECELERATION = cfg.Deceleration or MOVEMENT.DECELERATION
	local JUMP_POWER = cfg.JumpPower or MOVEMENT.JUMP_POWER

	-- Update last movement direction only if actually moving
	if moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
		State.lastMoveDir = moveDir.Unit
	end

	-- Calculate target speed with directional modifiers
	local isMoving = moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD
	local targetSpeed = isMoving and MAX_SPEED or 0

	-- Apply speed calculation
	MovementManager.CalculateSpeed(ACCELERATION, DECELERATION, targetSpeed, dt, isMoving)

	-- Handle wall collisions - pass the current move direction
	local probeDir = (moveDir.Magnitude > 0) and moveDir or State.lastMoveDir
	local wallHit, wallNormal, wallDistance = CollisionManager.DetectWallCollision(
		humanoidRootPart,
		character,
		hoverboard,
		probeDir,
		currentSpeed,
		MOVEMENT.MAX_SPEED
	)
	CollisionManager.HandleWallCollision(
		humanoidRootPart,
		wallNormal,
		wallDistance,
		moveDir,
		State,
		bodyVelocity,
		bodyGyro,
		currentSpeed,
		MOVEMENT,
		dt
	)

	-- Update collision state for auto-reset
	CollisionManager.UpdateCollisionState(State, dt)

	-- If input is blocked by collision, ensure speed is zero and skip movement application
	if State.inputBlocked then
		currentSpeed = 0
		-- Make sure velocity is fixed to zero horizontally in ApplyVelocity; we still call it so vertical physics remain
		MovementManager.ApplyVelocity(dt, Vector3.zero)
		-- Skip rotation while blocked
		-- Update prev speed for decel detection
		State.prevSpeed = currentSpeed
		return
	end

	-- Stop if speed is very low
	if currentSpeed < 0.3 then
		currentSpeed = 0
	end

	-- Apply velocity
	MovementManager.ApplyVelocity(dt, moveDir)

	-- Apply rotation
	if State.lastMoveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
		MovementManager.ApplyRotation(dt)
	end

	-- Update prevSpeed for next-frame deceleration detection (used by HoverManager.AlignHoverboard)
	State.prevSpeed = currentSpeed

	-- -- Update last movement direction only if actually moving
	-- if moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
	-- 	State.lastMoveDir = moveDir.Unit
	-- end

	-- -- Calculate target speed with directional modifiers
	-- local isMoving = moveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD
	-- local targetSpeed = isMoving and MOVEMENT.MAX_SPEED or 0

	-- -- Apply speed calculation
	-- MovementManager.CalculateSpeed(targetSpeed, dt, isMoving)

	-- -- Handle wall collisions - pass the current move direction
	-- local probeDir = moveDir.Magnitude > 0 and moveDir or State.lastMoveDir
	-- local wallHit, wallNormal, wallDistance = CollisionManager.DetectWallCollision(humanoidRootPart, character, hoverboard, probeDir, currentSpeed, MOVEMENT.MAX_SPEED)
	-- CollisionManager.HandleWallCollision(humanoidRootPart, wallNormal, wallDistance, moveDir, State, bodyVelocity, currentSpeed, MOVEMENT, dt)  -- Pass moveDir here

	-- -- Update collision state for auto-reset
	-- CollisionManager.UpdateCollisionState(State, dt)

	-- -- Stop if speed is very low
	-- if currentSpeed < 0.3 then
	-- 	currentSpeed = 0
	-- end

	-- -- Apply velocity
	-- MovementManager.ApplyVelocity(dt, moveDir)  -- Pass moveDir here

	-- -- Apply rotation
	-- if State.lastMoveDir.Magnitude > MOVEMENT.MIN_MOVE_THRESHOLD then
	-- 	MovementManager.ApplyRotation(dt)
	-- end
end

function MovementManager.ApplyVelocity(dt, moveDir)
	if not bodyVelocity then
		return
	end

	-- If input is completely blocked, hold horizontal velocity to zero smoothly
	if State.inputBlocked then
		local currentVel = humanoidRootPart.AssemblyLinearVelocity
		local targetVel = Vector3.new(0, currentVel.Y, 0)
		local velT = math.clamp(dt * 5, 0, 1)
		bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(targetVel, velT)
		return
	end

	local effectiveDir = (currentSpeed > 0) and State.lastMoveDir or Vector3.zero
	local velocity = effectiveDir * currentSpeed
	local currentVel = humanoidRootPart.AssemblyLinearVelocity

	-- Check if we can move in the desired direction
	local canMove = CollisionManager.CanMoveInDirection(moveDir, State)

	-- Only apply movement if allowed and we have input
	if canMove and moveDir.Magnitude > 0 then
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = math.clamp(dt * 12, 0, 1)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	elseif moveDir.Magnitude == 0 then
		-- Allow coasting if no input, regardless of collision state
		local horiz = Vector3.new(velocity.X, 0, velocity.Z)
		local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
		local velT = math.clamp(dt * 12, 0, 1)
		local newHoriz = curHoriz:Lerp(horiz, velT)
		bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	else
		-- Only slow down when actively trying to move into a wall
		if not canMove then
			-- Gentle slowdown instead of hard stop
			local currentHorizVel = Vector3.new(currentVel.X, 0, currentVel.Z)
			local slowedHorizVel = currentHorizVel * (1 - dt * 5) -- Gradual slowdown
			bodyVelocity.Velocity = Vector3.new(slowedHorizVel.X, currentVel.Y, slowedHorizVel.Z)
		end
	end

	-- if not bodyVelocity then return end

	-- local effectiveDir = (currentSpeed > 0) and State.lastMoveDir or Vector3.zero
	-- local velocity = effectiveDir * currentSpeed
	-- local currentVel = humanoidRootPart.AssemblyLinearVelocity

	-- -- Check if we can move in the desired direction
	-- local canMove = CollisionManager.CanMoveInDirection(moveDir, State)

	-- -- Only apply movement if allowed and we have input
	-- if canMove and moveDir.Magnitude > 0 then
	-- 	local horiz = Vector3.new(velocity.X, 0, velocity.Z)
	-- 	local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
	-- 	local velT = math.clamp(dt * 12, 0, 1)
	-- 	local newHoriz = curHoriz:Lerp(horiz, velT)
	-- 	bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	-- elseif moveDir.Magnitude == 0 then
	-- 	-- Allow coasting if no input, regardless of collision state
	-- 	local horiz = Vector3.new(velocity.X, 0, velocity.Z)
	-- 	local curHoriz = Vector3.new(currentVel.X, 0, currentVel.Z)
	-- 	local velT = math.clamp(dt * 12, 0, 1)
	-- 	local newHoriz = curHoriz:Lerp(horiz, velT)
	-- 	bodyVelocity.Velocity = Vector3.new(newHoriz.X, currentVel.Y, newHoriz.Z)
	-- else
	-- 	-- Only stop movement when actively trying to move into a wall
	-- 	if not canMove then
	-- 		-- Gentle slowdown instead of hard stop
	-- 		local currentHorizVel = Vector3.new(currentVel.X, 0, currentVel.Z)
	-- 		local slowedHorizVel = currentHorizVel * (1 - dt * 5)  -- Gradual slowdown
	-- 		bodyVelocity.Velocity = Vector3.new(slowedHorizVel.X, currentVel.Y, slowedHorizVel.Z)
	-- 	end
	-- end
end

function MovementManager.ApplyRotation(dt)
	-- Do not rotate while input is blocked (player is stopped against wall)
	if State.inputBlocked then
		return
	end
	if not bodyGyro or State.lastMoveDir.Magnitude == 0 then
		return
	end

	-- Player should FACE 90° relative to movement
	local moveDir = State.lastMoveDir
	local candidateNormal = State.smoothedGroundNormal or Vector3.new(0, 1, 0)
	local forwardProj = Utilities.ProjectVectorOnPlane(State.lastMoveDir, candidateNormal)

	-- 90-degree facing offset (right side)
	local rightVector = candidateNormal:Cross(moveDir).Unit
	local facingDir = rightVector -- facing sideways instead of forward

	if facingDir.Magnitude < 1e-5 then
		facingDir = Vector3.new(0, 0, -1)
	end

	local targetPlayerCFrame =
		CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + facingDir, candidateNormal)
	local rotSmooth = math.clamp(dt * MOVEMENT.ROTATION_SPEED * MOVEMENT.ROTATION_SMOOTHNESS, 0, 1)

	local currentCF = bodyGyro.CFrame
	local newRot = (currentCF - currentCF.Position):Lerp(targetPlayerCFrame - targetPlayerCFrame.Position, rotSmooth)
	bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot

	-- if not bodyGyro or State.lastMoveDir.Magnitude == 0 then return end

	-- local candidateNormal = State.smoothedGroundNormal or Vector3.new(0, 1, 0)
	-- local forwardProj = Utilities.ProjectVectorOnPlane(State.lastMoveDir, candidateNormal)

	-- if forwardProj.Magnitude < 1e-5 then
	-- 	forwardProj = Vector3.new(0, 0, -1)
	-- end

	-- local targetPlayerCFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + forwardProj, candidateNormal)
	-- local rotSmooth = math.clamp(dt * MOVEMENT.ROTATION_SPEED * MOVEMENT.ROTATION_SMOOTHNESS, 0, 1)

	-- local currentCF = bodyGyro.CFrame
	-- local newRot = (currentCF - currentCF.Position):Lerp(targetPlayerCFrame - targetPlayerCFrame.Position, rotSmooth)
	-- bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRot
end

--[[
    Hover & Surface Alignment
]]
--
local HoverManager = {}

function HoverManager.AlignToSurface(dt)
	if not humanoidRootPart or not hoverboard then
		return
	end

	local origin = humanoidRootPart.Position
	local direction = Vector3.new(0, -1, 0) * HOVER.RAYCAST_DISTANCE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hoverboard }

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return
	end

	local surfaceNormal = result.Normal
	local rootForward = humanoidRootPart.CFrame.LookVector
	local forwardProj = Utilities.ProjectVectorOnPlane(rootForward, surfaceNormal)

	if forwardProj.Magnitude < 1e-5 then
		forwardProj = surfaceNormal:Cross(Vector3.new(0, 0, 1))
		if forwardProj.Magnitude < 1e-5 then
			forwardProj = surfaceNormal:Cross(Vector3.new(0, 1, 0))
		end
	end

	local orientSmooth = math.clamp(dt * HOVER.ORIENTATION_SMOOTHNESS, 0, 1)
	State.smoothedGroundNormal = State.smoothedGroundNormal
			and State.smoothedGroundNormal:Lerp(surfaceNormal, orientSmooth)
		or surfaceNormal

	local finalNormal = State.smoothedGroundNormal.Unit
	local finalForward = Utilities.ProjectVectorOnPlane(forwardProj, finalNormal)

	if finalForward.Magnitude < 1e-5 then
		finalForward = Vector3.new(0, 0, -1)
	end

	local targetCFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + finalForward, finalNormal)

	if bodyGyro then
		local currentOrient = bodyGyro.CFrame
		local currentPos = humanoidRootPart.Position
		local lerpT = orientSmooth
		local newRot = (currentOrient - currentOrient.Position):Lerp(targetCFrame - targetCFrame.Position, lerpT)
		bodyGyro.CFrame = CFrame.new(currentPos) * newRot
	else
		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(targetCFrame, orientSmooth)
	end
end

function HoverManager.UpdateHover(dt)
	if not hoverboard or not hoverboard.PrimaryPart or State.isJumping then
        return
    end

    local primary = hoverboard.PrimaryPart
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, hoverboard }

    local size = primary.Size
    local rayLength = HOVER.RAYCAST_DISTANCE
    local rayOffsets = {
        Vector3.new(size.X / 2, 0, size.Z / 2),
        Vector3.new(-size.X / 2, 0, size.Z / 2),
        Vector3.new(size.X / 2, 0, -size.Z / 2),
        Vector3.new(-size.X / 2, 0, -size.Z / 2),
    }

    local hitPositions, hitNormals = {}, {}

    for _, offset in ipairs(rayOffsets) do
        local origin = primary.CFrame:PointToWorldSpace(offset + Vector3.new(0, 0.2, 0))
        local direction = Vector3.new(0, -rayLength, 0)
        local result = workspace:Raycast(origin, direction, params)
        if result then
            table.insert(hitPositions, result.Position)
            table.insert(hitNormals, result.Normal)
        end
    end

    if #hitPositions > 0 then
        local avgPos, avgNormal = Vector3.zero, Vector3.zero
        for i = 1, #hitPositions do
            avgPos = avgPos + hitPositions[i]
            avgNormal = avgNormal + hitNormals[i]
        end
        avgPos = avgPos / #hitPositions
        avgNormal = avgNormal.Unit

        local hoverT = math.clamp(1 - math.exp(-HOVER.HOVER_SMOOTHNESS * dt * 10), 0, 1)
        State.smoothedGroundNormal = State.smoothedGroundNormal and State.smoothedGroundNormal:Lerp(avgNormal, hoverT)
            or avgNormal

        local finalNormal = State.smoothedGroundNormal.Unit
        
        -- ========== UPDATED BOBBING EFFECT CODE ==========
        -- Update bobbing time (very slow - 0.8 seconds per full cycle)
        State.bobTime = State.bobTime + (dt * 0.4)
        
        -- Calculate bobbing offset using sine wave
        -- Very subtle bobbing: 0.15 studs amplitude, slow frequency
        local bobOffset = math.sin(State.bobTime * math.pi * 2) * 0.15
        
        -- Apply bobbing ONLY to hoverboard, NOT to the player's position
        local targetY = avgPos.Y + State.baseHoverHeight + bobOffset
        
        if hoverBodyPosition then
            -- Only move the hoverboard with bobbing, keep player position stable
            local currentBP = hoverBodyPosition.Position
            local targetBP = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
            local posT = math.clamp(dt * 8, 0, 1) -- Slightly slower for smoother bobbing
            hoverBodyPosition.Position = currentBP:Lerp(targetBP, posT)
        end
        
        -- Keep player at stable height (no bobbing for player)
        local playerTargetY = avgPos.Y + State.baseHoverHeight
        if humanoidRootPart then
            -- Smoothly maintain player at stable height without bobbing
            local currentPlayerPos = humanoidRootPart.Position
            local targetPlayerPos = Vector3.new(currentPlayerPos.X, playerTargetY, currentPlayerPos.Z)
            local playerPosT = math.clamp(dt * 12, 0, 1)
            humanoidRootPart.Position = currentPlayerPos:Lerp(targetPlayerPos, playerPosT)
        end
        -- ========== END UPDATED CODE ==========

        HoverManager.AlignHoverboard(primary, finalNormal, dt)
    else
        if hoverBodyPosition then
            hoverBodyPosition.MaxForce = Vector3.zero
        end
    end



	-- if not hoverboard or not hoverboard.PrimaryPart or State.isJumping then
	-- 	return
	-- end

	-- local primary = hoverboard.PrimaryPart
	-- local params = RaycastParams.new()
	-- params.FilterType = Enum.RaycastFilterType.Exclude
	-- params.FilterDescendantsInstances = { character, hoverboard }

	-- local size = primary.Size
	-- local rayLength = HOVER.RAYCAST_DISTANCE
	-- local rayOffsets = {
	-- 	Vector3.new(size.X / 2, 0, size.Z / 2),
	-- 	Vector3.new(-size.X / 2, 0, size.Z / 2),
	-- 	Vector3.new(size.X / 2, 0, -size.Z / 2),
	-- 	Vector3.new(-size.X / 2, 0, -size.Z / 2),
	-- }

	-- local hitPositions, hitNormals = {}, {}

	-- for _, offset in ipairs(rayOffsets) do
	-- 	local origin = primary.CFrame:PointToWorldSpace(offset + Vector3.new(0, 0.2, 0))
	-- 	local direction = Vector3.new(0, -rayLength, 0)
	-- 	local result = workspace:Raycast(origin, direction, params)
	-- 	if result then
	-- 		table.insert(hitPositions, result.Position)
	-- 		table.insert(hitNormals, result.Normal)
	-- 	end
	-- end

	-- if #hitPositions > 0 then
	-- 	local avgPos, avgNormal = Vector3.zero, Vector3.zero
	-- 	for i = 1, #hitPositions do
	-- 		avgPos = avgPos + hitPositions[i]
	-- 		avgNormal = avgNormal + hitNormals[i]
	-- 	end
	-- 	avgPos = avgPos / #hitPositions
	-- 	avgNormal = avgNormal.Unit

	-- 	local hoverT = math.clamp(1 - math.exp(-HOVER.HOVER_SMOOTHNESS * dt * 10), 0, 1)
	-- 	State.smoothedGroundNormal = State.smoothedGroundNormal and State.smoothedGroundNormal:Lerp(avgNormal, hoverT)
	-- 		or avgNormal

	-- 	local finalNormal = State.smoothedGroundNormal.Unit

	-- 	-- ========== UPDATED BOBBING EFFECT CODE ==========
	-- 	-- Update bobbing time (very slow - 0.5 seconds per full cycle)
	-- 	State.bobTime = State.bobTime + (dt * HOVER.BOBBING_DURATION)

	-- 	-- Calculate bobbing offset using sine wave
	-- 	-- Very subtle bobbing: 0.1 studs amplitude, slow frequency
	-- 	local bobOffset = math.sin(State.bobTime * math.pi * 2) * HOVER.BOBBING_FREQUENCY

	-- 	-- Apply bobbing to hover height
	-- 	local targetY = avgPos.Y + State.baseHoverHeight + bobOffset
	-- 	-- ========== END UPDATED CODE ==========

	-- 	if hoverBodyPosition then
	-- 		local currentBP = hoverBodyPosition.Position
	-- 		local targetBP = Vector3.new(primary.Position.X, targetY, primary.Position.Z)
	-- 		local posT = math.clamp(dt * 10, 0, 1)
	-- 		hoverBodyPosition.Position = currentBP:Lerp(targetBP, posT)
	-- 	end

	-- 	HoverManager.AlignHoverboard(primary, finalNormal, dt)
	-- else
	-- 	if hoverBodyPosition then
	-- 		hoverBodyPosition.MaxForce = Vector3.zero
	-- 	end
	-- end
end

function HoverManager.AlignHoverboard(primary, finalNormal, dt)
	-- Ensure state fields exist
	State.smoothedLean = State.smoothedLean or 0
	State.prevSpeed = State.prevSpeed or 0
	State.smoothedTilt = State.smoothedTilt or 0 -- X-axis tilt state

	-- Compute forward on plane (what the board should look along)
	local playerForward = humanoidRootPart.CFrame.LookVector
	local forwardOnPlane = Utilities.ProjectVectorOnPlane(playerForward, finalNormal)

	if forwardOnPlane.Magnitude < 1e-5 then
		forwardOnPlane = State.lastMoveDir.Magnitude > 0
				and Utilities.ProjectVectorOnPlane(State.lastMoveDir, finalNormal)
			or Vector3.new(0, 0, -1)
	end
	forwardOnPlane = forwardOnPlane.Unit

	-- ---------- 1) Calculate X-axis tilt based on rotation ----------
	-- Track rotation direction and speed for tilt calculation
	local currentForward = Utilities.ProjectVectorOnPlane(primary.CFrame.LookVector, finalNormal)
	if currentForward.Magnitude < 1e-5 then
		currentForward = forwardOnPlane
	end
	currentForward = currentForward.Unit

	-- Calculate angular velocity for responsive tilt
	local angularVelocity = 0
	if State.lastForwardWanted then
		local dot = math.clamp(State.lastForwardWanted:Dot(forwardOnPlane), -1, 1)
		local angleDelta = math.acos(dot)
		local cross = State.lastForwardWanted:Cross(forwardOnPlane)
		local sign = (cross:Dot(finalNormal) >= 0) and 1 or -1
		angularVelocity = angleDelta * sign / math.max(1e-6, dt)
	end
	State.lastForwardWanted = forwardOnPlane

	-- Calculate target tilt based on angular velocity (plane-like banking)
	local maxTilt = math.rad(45) -- 30 degrees maximum tilt
	local tiltSensitivity = 0.8 -- How responsive the tilt is to rotation
	local targetTilt = -angularVelocity * tiltSensitivity -- Negative for natural banking
	targetTilt = math.clamp(targetTilt, -maxTilt, maxTilt)

	-- Smooth the tilt
	local tiltSmooth = math.clamp(dt * 8, 0, 1) -- Smoothing factor for tilt
	State.smoothedTilt = State.smoothedTilt + (targetTilt - State.smoothedTilt) * tiltSmooth

	-- ---------- 2) Build target hover CFrame with tilt ----------
	local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, finalNormal)

	-- Apply X-axis tilt (rotation around local X axis)
	if math.abs(State.smoothedTilt) > 1e-5 then
		local rightVector = finalNormal:Cross(forwardOnPlane)
		if rightVector.Magnitude > 1e-5 then
			rightVector = rightVector.Unit
			local tiltCF = CFrame.fromAxisAngle(rightVector, State.smoothedTilt)
			targetHoverCF = targetHoverCF * tiltCF
		end
	end

	-- ---------- 3) Apply player tilt to match hoverboard ----------
	-- This makes the player lean with the hoverboard for a more natural feel
	if bodyGyro and bodyGyro.Parent then
        local currentPlayerCF = bodyGyro.CFrame
        local playerTargetCF = CFrame.lookAt(
            humanoidRootPart.Position, 
            humanoidRootPart.Position + forwardOnPlane, 
            finalNormal
        )
        
        -- Apply the same tilt to the player (but NO vertical bobbing)
        if math.abs(State.smoothedTilt) > 1e-5 then
            local rightVector = finalNormal:Cross(forwardOnPlane)
            if rightVector.Magnitude > 1e-5 then
                rightVector = rightVector.Unit
                local playerTiltCF = CFrame.fromAxisAngle(rightVector, State.smoothedTilt * 0.7) -- Slightly less tilt for player
                playerTargetCF = playerTargetCF * playerTiltCF
            end
        end
        
        -- ========== UPDATED: Smoothly apply orientation WITHOUT affecting position ==========
        -- Only rotate the player, don't change their vertical position
        local playerSmooth = math.clamp(dt * 6, 0, 1)
        local currentRotation = (currentPlayerCF - currentPlayerCF.Position)
        local targetRotation = (playerTargetCF - playerTargetCF.Position)
        local newRotation = currentRotation:Lerp(targetRotation, playerSmooth)
        
        -- Maintain the player's current position (no bobbing transfer)
        bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position) * newRotation
        -- ========== END UPDATED CODE ==========
    end

    -- ---------- 4) Smoothly lerp hoverboard CFrame to target ----------
    local primaryT = math.clamp(dt * HOVER.HOVER_SMOOTHNESS, 0, 1)
    primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)

	--Old Code
	-- local playerForward = humanoidRootPart.CFrame.LookVector
	-- local forwardOnPlane = Utilities.ProjectVectorOnPlane(playerForward, finalNormal)

	-- if forwardOnPlane.Magnitude < 1e-5 then
	-- 	forwardOnPlane = State.lastMoveDir.Magnitude > 0
	-- 			and Utilities.ProjectVectorOnPlane(State.lastMoveDir, finalNormal)
	-- 		or Vector3.new(0, 0, -1)
	-- end

	-- local targetHoverCF = CFrame.lookAt(primary.Position, primary.Position + forwardOnPlane, finalNormal)
	-- local primaryT = math.clamp(dt * HOVER.HOVER_SMOOTHNESS, 0, 1)
	-- primary.CFrame = primary.CFrame:Lerp(targetHoverCF, primaryT)
end

--[[
    Mobile Controls
]]
--
local MobileManager = {}

function MobileManager.SetupMobileControls()
	if not UserInputService.TouchEnabled or mobileControls.JumpButton then
		return
	end

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
		if isOnHoverboard and not State.isJumping then
			JumpManager.AttemptJump()
		end
	end)

	mobileControls.JumpButton = jumpButton
end

function MobileManager.CleanupMobileControls()
	if mobileControls.JumpButton then
		if mobileControls.JumpButton.Parent then
			mobileControls.JumpButton.Parent:Destroy()
		end
		mobileControls.JumpButton = nil
	end
end

--[[
    Main Controller Functions
]]
--
function HoverboardController:SetActiveHoverboard(boardName)
	local config = Hoverboards.GetConfig(boardName)
	if not config then
		warn("[HoverboardController] Could not find hoverboard config for " .. tostring(boardName))
		return
	end
	self.ActiveConfig = config
end

function HoverboardController:WaitForHoverboard()
	if not character then
		return
	end

	local hb = character:WaitForChild("Hoverboard", 5)
	if hb then
		hoverboard = hb

		-- Extract hover offset from server Motor6D
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local motor6D = hrp and hrp:FindFirstChild("HoverboardMotor")
		if motor6D and motor6D:IsA("Motor6D") then
			local c0Pos = motor6D.C0.Position
			State.hoverOffset = -c0Pos.Y
		else
			State.hoverOffset = 0
		end

		PhysicsManager.CreateClientConstraints()
		isOnHoverboard = true
		AnimationManager.DisableAnimations()
		GUIManager.SetupSpeedGUI()
		MobileManager.SetupMobileControls()
	end
end

--[[
    State Management
]]
--
local function ResetStates()
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
	inputVector = Vector3.zero
	currentSpeed = 0
	isOnHoverboard = false

	State.canJump = false
	State.isJumping = false
	State.lastJumpTime = 0
	State.lastMoveDir = Vector3.zero
	State.braking = false
	State.hoverOffset = 0
	State.smoothedGroundNormal = nil
	State.isCollidingWithWall = false -- Ensure this resets
	State.collisionNormal = Vector3.zero
	State.collisionRecoveryTimer = 0

	State.smoothedTilt = 0
	State.lastForwardWanted = nil
	State.bobTime = 0
    State.baseHoverHeight = HOVER.HOVER_HEIGHT
end

local function CleanupHoverboard()
	isOnHoverboard = false
	PhysicsManager.CleanupConstraints()
	MobileManager.CleanupMobileControls()
	hoverboard = nil
end

--[[
    Character Setup
]]
--
local function SetupCharacter(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	humanoid.Died:Connect(function()
		CleanupHoverboard()
		ResetStates()
		AnimationManager.RestoreAnimations()
	end)

	task.defer(function()
		HoverboardController:WaitForHoverboard()
	end)
end

--[[
    Input Handling
]]
--
local InputManager = {}

function InputManager.HandleInputBegan(input, gameProcessed)
	if gameProcessed or not isOnHoverboard then
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.W then
			inputVector = Vector3.new(inputVector.X, 0, -INPUT.KEYBOARD_MOVE_SPEED)
		elseif input.KeyCode == Enum.KeyCode.S then
			inputVector = Vector3.new(inputVector.X, 0, INPUT.KEYBOARD_MOVE_SPEED)
		elseif input.KeyCode == Enum.KeyCode.A then
			inputVector = Vector3.new(-INPUT.KEYBOARD_MOVE_SPEED, 0, inputVector.Z)
		elseif input.KeyCode == Enum.KeyCode.D then
			inputVector = Vector3.new(INPUT.KEYBOARD_MOVE_SPEED, 0, inputVector.Z)
		elseif input.KeyCode == Enum.KeyCode.Space and not State.isJumping then
			JumpManager.AttemptJump()
		end
	end
end

function InputManager.HandleInputEnded(input)
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
end

function InputManager.HandleMobileInput()
	if UserInputService.TouchEnabled and isOnHoverboard then
		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude > INPUT.MOBILE_MOVE_THRESHOLD then
			inputVector = Vector3.new(moveDir.X, 0, -moveDir.Z)
		else
			inputVector = Vector3.zero
		end
	end
end

--[[
    Main Update Loop
]]
--
local function UpdateMovement(dt)
	if not isOnHoverboard then
		return
	end

	local camera = workspace.CurrentCamera
	local moveDir = Utilities.CalculateMoveDirection(camera, inputVector)

	MovementManager.ApplyMovement(moveDir, dt)
	HoverManager.UpdateHover(dt)
	GUIManager.UpdateSpeedDisplay()
end

local function UpdateLanding(dt)
	if State.isJumping then
		local grounded = JumpManager.IsGrounded()
		if grounded then
			State.isJumping = false
			State.canJump = true
		end
	end
	HoverManager.AlignToSurface(dt)
end

--[[
    Knit Lifecycle
]]
--
function HoverboardController:KnitInit()
	print("HoverboardController initialized")
end

function HoverboardController:KnitStart()
	HoverboardService = Knit.GetService("HoverboardService")

	-- Event connections
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner == player then
			self:SetActiveHoverboard(boardName)
			task.defer(function()
				self:WaitForHoverboard()
			end)
		end
	end)

	-- Character setup
	if player.Character then
		SetupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(SetupCharacter)
	player.CharacterRemoving:Connect(function()
		ResetStates()
		CleanupHoverboard()
	end)

	-- Input connections
	UserInputService.InputBegan:Connect(InputManager.HandleInputBegan)
	UserInputService.InputEnded:Connect(InputManager.HandleInputEnded)

	-- Update loops
	RunService.Heartbeat:Connect(function(dt)
		if isOnHoverboard then
			UpdateMovement(dt)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if isOnHoverboard then
			UpdateLanding(dt)
			InputManager.HandleMobileInput()
		end
	end)
end

return HoverboardController
