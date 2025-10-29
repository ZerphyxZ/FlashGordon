-- ObstacleMovingController.luau
-- Client-side Knit controller that animates moving obstacles and kills
-- the local player on contact. Works under Workspace/World_###/Obstacles/Translation
-- (also falls back to legacy Workspace/Obstacles/Translation).
-- CHANGE: world-aware folder discovery + live listeners; core behavior unchanged.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "ObstacleMovingController" }

local LocalPlayer = Players.LocalPlayer

-- Tunables (unchanged)
local MAX_UPDATE_DISTANCE = 200
local DEFAULT_SPEED       = 5

-- Active movers map (unchanged shape)
local movingObstacles = {}

-- ===== Helpers (existing behavior preserved) =================================

local function hitBelongsToLocalCharacter(hit)
	if not hit then return false end
	local current = hit
	while current do
		if current.Parent == LocalPlayer.Character then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getWorldPosition(obj)
	if not obj then return nil end
	if obj:IsA("Attachment") then
		return obj.WorldPosition or (obj.WorldCFrame and obj.WorldCFrame.Position) or nil
	end
	if obj:IsA("BasePart") then
		return obj.Position
	end
	if obj:IsA("Model") then
		local pp = obj.PrimaryPart
		if pp then return pp.Position end
		local cf = obj:GetModelCFrame()
		return cf and cf.Position or nil
	end
	return nil
end

local function initMovingObstacle(model)
	if not model or not model:IsA("Model") then return end
	local part = model:FindFirstChild("Moving_Obstacle_Part")
	if not (part and part:IsA("BasePart")) then return end

	local startAttachment = model:FindFirstChild("StartPoint") or model:FindFirstChild("StartPoint", true)
	local endAttachment   = model:FindFirstChild("EndPoint")   or model:FindFirstChild("EndPoint",   true)

	local startPos = getWorldPosition(startAttachment)
	local endPos   = getWorldPosition(endAttachment)
	if not (startPos and endPos) then
		warn("[ObstacleMovingController] Missing StartPoint or EndPoint on", model:GetFullName())
		return
	end

	local speedAttr = part:GetAttribute("Speed")
	local speed = (typeof(speedAttr) == "number" and speedAttr > 0) and speedAttr or DEFAULT_SPEED

	local distance = (endPos - startPos).Magnitude
	if distance <= 0 then
		warn("[ObstacleMovingController] Start and End attachments coincide on", model:GetFullName())
		return
	end

	local travelTime      = distance / speed
	local initialRotation = part.CFrame.Rotation

	part.Anchored = true

	movingObstacles[part] = {
		model        = model,
		part         = part,
		startPos     = startPos,
		endPos       = endPos,
		travelTime   = travelTime,
		initialRot   = initialRotation,
	}

	part.Touched:Connect(function(hit)
		if hitBelongsToLocalCharacter(hit) then
			local dieCtrl = Knit.GetController("DiePlayerController")
			if dieCtrl then
				if dieCtrl.Die then dieCtrl:Die() else dieCtrl:PlayDeath() end
			end
		end
	end)
end

local function removeMovingObstacle(part)
	movingObstacles[part] = nil
end

-- ===== NEW: robust discovery under World_### ================================

local function isWorldContainer(inst)
	return inst and (inst:IsA("Folder") or inst:IsA("Model")) and tostring(inst.Name):match("^World_%d+")
end

local function eachWorld(callback)
	-- existing worlds
	for _, child in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(child) then
			callback(child)
		end
	end
	-- future worlds
	Workspace.ChildAdded:Connect(function(ch)
		if isWorldContainer(ch) then
			callback(ch)
		end
	end)
end

local function attachToTranslationFolder(folder)
	-- Scan existing descendants
	for _, desc in ipairs(folder:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Moving_Obstacle_Part" then
			initMovingObstacle(desc.Parent)
		end
	end
	-- Live add/remove
	folder.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc.Name == "Moving_Obstacle_Part" then
			initMovingObstacle(desc.Parent)
		end
	end)
	folder.DescendantRemoving:Connect(function(desc)
		if desc:IsA("BasePart") and movingObstacles[desc] then
			removeMovingObstacle(desc)
		end
	end)
end

local function wireWorld(world)
	-- Preferred: World_###/Obstacles/Translation
	local obstacles = world:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local translation = obstacles:FindFirstChild("Translation")
		if translation and translation:IsA("Folder") then
			attachToTranslationFolder(translation)
		end
		-- Also listen for (re)creation of Translation
		obstacles.ChildAdded:Connect(function(c)
			if c.Name == "Translation" and c:IsA("Folder") then
				attachToTranslationFolder(c)
			end
		end)
	end
end

local function wireLegacyRootFallback()
	-- Legacy fallback: Workspace/Obstacles/Translation
	local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
	local translationFolder = obstaclesFolder and obstaclesFolder:FindFirstChild("Translation")
	if translationFolder and translationFolder:IsA("Folder") then
		attachToTranslationFolder(translationFolder)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Obstacles" and child:IsA("Folder") then
			child.ChildAdded:Connect(function(sub)
				if sub.Name == "Translation" and sub:IsA("Folder") then
					attachToTranslationFolder(sub)
				end
			end)
			local tf = child:FindFirstChild("Translation")
			if tf and tf:IsA("Folder") then attachToTranslationFolder(tf) end
		end
	end)
end

-- ===== KNIT START ===========================================================

function Controller:KnitStart()
	-- Sync time (unchanged)
	local syncService = Knit.GetService("ObstacleSyncService")
	local startTimes  = (syncService and syncService:GetObstacleStartTimes()) or {}
	local movingStartTime = startTimes.Moving or Workspace:GetServerTimeNow()

	-- World-aware wiring
	eachWorld(wireWorld)
	-- Legacy fallback to root if someone still has that layout
	wireLegacyRootFallback()

	-- Per-frame update (unchanged math)
	RunService.Heartbeat:Connect(function()
		local serverTime = Workspace:GetServerTimeNow()
		local char = LocalPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local playerPos = hrp and hrp.Position

		for _, obstacle in pairs(movingObstacles) do
			local part       = obstacle.part
			local startPos   = obstacle.startPos
			local endPos     = obstacle.endPos
			local travelTime = obstacle.travelTime
			if part and part.Parent and travelTime and travelTime > 0 then
				local skip = false
				if playerPos then
					local midpoint = (startPos + endPos) * 0.5
					if (playerPos - midpoint).Magnitude > MAX_UPDATE_DISTANCE then
						skip = true
					end
				end
				if not skip then
					local cycle = (serverTime - movingStartTime) / travelTime
					local phase = cycle % 2
					local alpha = math.abs(phase - 1)
					local newPos = startPos:Lerp(endPos, alpha)
					part.CFrame = CFrame.new(newPos) * obstacle.initialRot
				end
			end
		end
	end)
end

return Controller
