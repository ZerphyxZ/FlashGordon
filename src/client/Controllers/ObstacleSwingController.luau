-- ObstacleSwingController.luau
-- Client-side Knit controller that animates Swing obstacles and kills
-- the player if the ball collider (Neon) is touched.
-- Updated to work under Workspace/World_###/Obstacles/Swing
-- (also falls back to legacy Workspace/Obstacles/Swing).
-- Preserves original swing math, optional translation, culling, and kill logic.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "ObstacleSwingController" }

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character

LocalPlayer.CharacterAdded:Connect(function(char)
	Character = char
end)

-- ===== Tunables (preserved) ==================================================
local SWING_MAX_ANGLE_DEG     = 55
local DEFAULT_SWING_SPEED_DEG = 70
local DEFAULT_MOVING_SPEED    = 6
local MAX_UPDATE_DISTANCE     = 500
local RECHECK_ATTEMPTS        = 20
local RECHECK_DELAY           = 0.15

-- Active swings (key = model)
local swingMap: {[Model]: any} = {}

-- Track which Swing folders we've already bound
local boundFolders = setmetatable({}, { __mode = "k" })

-- ===== Helpers ===============================================================

local function belongsToLocalCharacter(hit: Instance?): boolean
	if not hit then return false end
	local char = LocalPlayer.Character
	if not char then return false end
	local p = hit
	while p do
		if p == char then return true end
		p = p.Parent
	end
	return false
end

local function bindKill(ball: BasePart?)
	if not (ball and ball:IsA("BasePart")) then return end
	if ball.Material ~= Enum.Material.Neon then
		-- Non-neon ball is harmless by design
		return
	end
	ball.Touched:Connect(function(hit)
		if belongsToLocalCharacter(hit) then
			local dieCtrl = Knit.GetController("DiePlayerController")
			if dieCtrl then
				if dieCtrl.Die then dieCtrl:Die() else dieCtrl:PlayDeath() end
			end
		end
	end)
end

local function waitForParts(model: Model): (BasePart?, BasePart?)
	for i = 1, RECHECK_ATTEMPTS do
		local ball = model:FindFirstChild("Ball_Collider_Part", true)
		local rope = model:FindFirstChild("Swing_Rop_Part", true)
		if (ball and ball:IsA("BasePart")) or (rope and rope:IsA("BasePart")) then
			return ball :: BasePart?, rope :: BasePart?
		end
		task.wait(RECHECK_DELAY)
	end
	return nil, nil
end

-- ===== Init / remove =========================================================

local function initSwingModel(model: Model)
	if swingMap[model] then return end
	if not model:IsDescendantOf(Workspace) then return end

	local ball, rope = waitForParts(model)
	if not (ball or rope) then
		warn("[SwingCtrl] Skipping model (parts missing):", model:GetFullName())
		return
	end

	local swingSpeedDeg = model:GetAttribute("SwingSpeed") or DEFAULT_SWING_SPEED_DEG
	local swingSpeed    = math.rad(swingSpeedDeg)
	local movingSpeed   = model:GetAttribute("MovingSpeed") or 0

	local startA = model:FindFirstChild("StartPoint", true)
	local endA   = model:FindFirstChild("EndPoint",   true)
	local hasPoints = startA and endA and startA:IsA("Attachment") and endA:IsA("Attachment") and movingSpeed > 0

	local startPos, endPos, travelTime, midPoint, pivotPos
	local initialPivot = model:GetPivot()
	local initialRot   = initialPivot.Rotation

	if hasPoints then
		startPos = startA.WorldPosition
		endPos   = endA.WorldPosition
		local dist = (endPos - startPos).Magnitude
		if dist > 0.05 then
			travelTime = dist / movingSpeed
			midPoint   = (startPos + endPos) * 0.5
		else
			hasPoints = false
		end
	end

	if not hasPoints then
		pivotPos = initialPivot.Position
		midPoint = pivotPos
	end

	swingMap[model] = {
		model      = model,
		ball       = ball,
		rope       = rope,
		swingSpeed = swingSpeed,
		hasPoints  = hasPoints,
		startPos   = startPos,
		endPos     = endPos,
		travelTime = travelTime,
		initialRot = initialRot,
		pivotPos   = pivotPos,
		midPoint   = midPoint,
	}

	bindKill(ball)
end

local function forgetSwingModel(model: Model)
	if swingMap[model] then
		swingMap[model] = nil
	end
end

-- ===== World-aware binding ===================================================

local function isWorldContainer(inst: Instance?): boolean
	return inst
		and (inst:IsA("Folder") or inst:IsA("Model"))
		and tostring(inst.Name):match("^World_%d+")
end

local function attachToSwingFolder(folder: Instance)
	if not (folder and folder:IsA("Folder")) then return end
	if boundFolders[folder] then return end
	boundFolders[folder] = true

	-- Existing children
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			task.defer(initSwingModel, child)
		end
	end

	-- Live add/remove
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(initSwingModel, child)
		end
	end)

	-- Use DescendantRemoving to catch model deletion anywhere below
	folder.DescendantRemoving:Connect(function(desc)
		if desc:IsA("Model") then
			forgetSwingModel(desc)
		end
	end)
end

local function wireWorld(world: Instance)
	if not (world and world.Parent == Workspace) then return end
	local obstacles = world:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local swingFolder = obstacles:FindFirstChild("Swing")
		if swingFolder and swingFolder:IsA("Folder") then
			attachToSwingFolder(swingFolder)
		end
		-- Listen for Swing being created later
		obstacles.ChildAdded:Connect(function(sub)
			if sub.Name == "Swing" and sub:IsA("Folder") then
				attachToSwingFolder(sub)
			end
		end)
	end
end

local function wireLegacyRootFallback()
	local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
	if obstaclesFolder and obstaclesFolder:IsA("Folder") then
		local swingFolder = obstaclesFolder:FindFirstChild("Swing")
		if swingFolder and swingFolder:IsA("Folder") then
			attachToSwingFolder(swingFolder)
		end
		obstaclesFolder.ChildAdded:Connect(function(sub)
			if sub.Name == "Swing" and sub:IsA("Folder") then
				attachToSwingFolder(sub)
			end
		end)
	end
end

-- ===== Per-frame update ======================================================

local function updateAll(swingStartTime: number)
	local hrp  = Character and Character:FindFirstChild("HumanoidRootPart")
	local playerPos = hrp and hrp.Position
	local t   = Workspace:GetServerTimeNow()

	for model, info in pairs(swingMap) do
		if not (model and model.Parent) then
			forgetSwingModel(model)
		else
			if playerPos and info.midPoint and (playerPos - info.midPoint).Magnitude > MAX_UPDATE_DISTANCE then
				-- culled to save perf
			else
				local angleZ = math.rad(SWING_MAX_ANGLE_DEG) * math.sin(info.swingSpeed * (t - swingStartTime))
				local posCF
				if info.hasPoints and info.startPos and info.endPos and info.travelTime then
					local phase  = ((t - swingStartTime) / info.travelTime) % 2
					local alpha  = math.abs(phase - 1)
					local pos    = info.startPos:Lerp(info.endPos, alpha)
					posCF = CFrame.new(pos)
				else
					posCF = CFrame.new(info.pivotPos)
				end
				local cf = posCF * CFrame.Angles(0, 0, angleZ) * info.initialRot
				model:PivotTo(cf)
			end
		end
	end
end

-- ===== Knit lifecycle ========================================================

function Controller:KnitStart()
	-- Get synchronized start time from server
	local syncService = Knit.GetService("ObstacleSyncService")
	local times = (syncService and syncService:GetObstacleStartTimes()) or {}
	local swingStartTime = times.Swing or Workspace:GetServerTimeNow()

	-- Bind existing worlds
	for _, ch in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(ch) then
			wireWorld(ch)
		end
	end
	-- Bind future worlds
	Workspace.ChildAdded:Connect(function(ch)
		if isWorldContainer(ch) then
			wireWorld(ch)
		end
	end)
	-- Legacy root fallback
	wireLegacyRootFallback()

	-- Heartbeat updates
	RunService.Heartbeat:Connect(function()
		updateAll(swingStartTime)
	end)
end

return Controller
