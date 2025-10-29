-- ObstacleRotationController.luau
-- Client-side controller that animates rotational obstacles and kills
-- the local player on contact. Updated to support worlds under
-- Workspace/World_###/Obstacles/Rotational while keeping legacy
-- Workspace/Obstacles/Rotational fallback. Also preserves streaming
-- resilience, start-time sync, and fuzzy part name matching.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "ObstacleRotationController" }

-- Debug printing configuration
local DEBUG = false
local LPFX  = "[ObstacleRotationController]"
local function dprint(...) if DEBUG then print(LPFX, ...) end end
local function dwarn(...)  if DEBUG then warn (LPFX, ...) end end

-- Tunables
local LocalPlayer = Players.LocalPlayer
local MAX_UPDATE_DISTANCE = 200
local DEFAULT_ROT_DEG     = 90
local DEFAULT_MOVE_SPEED  = 20
local PENDING_RECHECK_INTERVAL = 0.5
local MAX_PENDING_AGE      = 60

-- Active and pending obstacle tracking
local Active  = {}
local Pending = {}

-- Track attached folders so we don't double-bind
local attachedFolders = setmetatable({}, { __mode = "k" })

-- ===== Fuzzy name helpers ====================================================

local function contains(h, n) return h:lower():find(n:lower(), 1, true) ~= nil end

local function isBasePartCandidate(inst)
	return inst:IsA("BasePart") and
		(inst.Name == "Rotational_Base_Part" or
		 (contains(inst.Name, "rotational") and contains(inst.Name, "base") and contains(inst.Name, "part")))
end

local function isDamagePartCandidate(inst)
	if not inst:IsA("BasePart") then return false end
	local n = inst.Name:lower()
	return (n == "rotational_damage_part_1"
	    or  n == "rotational_damage_part_2"
	    or (contains(n, "rotational") and contains(n, "damage") and contains(n, "part")))
end

local function findBasePart(model)
	local exact = model:FindFirstChild("Rotational_Base_Part", true)
	if exact and exact:IsA("BasePart") then return exact end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
	for _, d in ipairs(model:GetDescendants()) do
		if isBasePartCandidate(d) then return d end
	end
	return nil
end

local function findDamageParts(model)
	local p1, p2
	local e1 = model:FindFirstChild("Rotational_Damage_Part_1", true)
	local e2 = model:FindFirstChild("Rotational_Damage_Part_2", true)
	if e1 and e1:IsA("BasePart") then p1 = e1 end
	if e2 and e2:IsA("BasePart") then p2 = e2 end
	if not (p1 and p2) then
		for _, d in ipairs(model:GetDescendants()) do
			if isDamagePartCandidate(d) then
				if not p1 then p1 = d
				elseif not p2 then
					p2 = d
					break
				end
			end
		end
	end
	return p1, p2
end

local function getAttrNumber(obj, name)
	local v = obj:GetAttribute(name)
	if typeof(v) == "number" then return v end
	return nil
end

local function bindKill(part, modelName, tag)
	if not part then return end
	part.Touched:Connect(function(hit)
		if not hit then return end
		local parent = hit.Parent
		if not parent then return end
		if Players:GetPlayerFromCharacter(parent) == LocalPlayer then
			dprint(("HIT %s on '%s' by local player"):format(tag, modelName))
			local die = Knit.GetController("DiePlayerController")
			if die then
				if die.Die then die:Die() else die:PlayDeath() end
			else
				dwarn("DiePlayerController not available")
			end
		end
	end)
end

-- ===== Init / pending ========================================================

local function initActive(model)
	local basePart = findBasePart(model)
	if not basePart then return false, "no-base" end

	local rotDeg = getAttrNumber(model, "RotationSpeed") or getAttrNumber(basePart, "RotationSpeed") or DEFAULT_ROT_DEG
	local moveSp = getAttrNumber(model, "MovingSpeed")   or getAttrNumber(basePart, "MovingSpeed")   or 0
	local angularSpeed = math.rad(rotDeg ~= 0 and rotDeg or DEFAULT_ROT_DEG)

	local startAttachment = model:FindFirstChild("StartPoint", true)
	local endAttachment   = model:FindFirstChild("EndPoint",   true)

	local hasPoints = false
	local startPos, endPos, travelTime, pivotPos, midPoint
	local initialRotCF = model:GetPivot()

	if startAttachment and endAttachment and startAttachment:IsA("Attachment") and endAttachment:IsA("Attachment") and moveSp > 0 then
		startPos  = startAttachment.WorldPosition
		endPos    = endAttachment.WorldPosition
		local dist = (endPos - startPos).Magnitude
		if dist >= 0.05 then
			hasPoints = true
			travelTime = dist / moveSp
			midPoint   = (startPos + endPos) / 2
		else
			dwarn(("Model '%s' Start/End distance < 0.05; translation disabled."):format(model:GetFullName()))
		end
	end
	if not hasPoints then
		pivotPos = basePart.Position
		midPoint = pivotPos
	end

	Active[model] = {
		model        = model,
		basePart     = basePart,
		hasPoints    = hasPoints,
		startPos     = startPos,
		endPos       = endPos,
		travelTime   = travelTime,
		initialRotCF = initialRotCF,
		pivotPos     = pivotPos,
		angularSpeed = angularSpeed,
		midPoint     = midPoint,
		_dbg         = {},
	}

	local dmg1, dmg2 = findDamageParts(model)
	bindKill(dmg1, model.Name, "Rotational_Damage_Part_1")
	bindKill(dmg2, model.Name, "Rotational_Damage_Part_2")

	dprint(("INIT '%s' rotSpeed=%.2fdeg/s moveSpeed=%.2f hasPoints=%s"):format(
		model.Name, rotDeg, moveSp, tostring(hasPoints)))
	return true
end

local function ensurePending(model)
	if Active[model] or Pending[model] then return end
	Pending[model] = { model = model, createdAt = Workspace:GetServerTimeNow(), _dbg = {} }

	model.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") or inst:IsA("Attachment") then
			if Active[model] then return end
			local ok = initActive(model)
			if ok then Pending[model] = nil end
		end
	end)
end

task.spawn(function()
	while true do
		local now = Workspace:GetServerTimeNow()
		for model, entry in pairs(Pending) do
			if not model.Parent then
				Pending[model] = nil
			else
				local ok, reason = initActive(model)
				if ok then
					Pending[model] = nil
				else
					local last = entry._dbg.lastPending or 0
					if now - last >= 2 then
						entry._dbg.lastPending = now
						dprint(("PENDING '%s' waiting: %s"):format(model:GetFullName(), tostring(reason)))
					end
					if now - (entry.createdAt or now) > MAX_PENDING_AGE then
						dwarn(("PENDING TIMEOUT '%s' after %.1fs"):format(model:GetFullName(), now - entry.createdAt))
						Pending[model] = nil
					end
				end
			end
		end
		task.wait(PENDING_RECHECK_INTERVAL)
	end
end)

local function removeModel(model)
	Active[model] = nil
	Pending[model] = nil
end

-- ===== World/Folder binding ==================================================

local function bindRotationalFolder(rotFolder)
	if not (rotFolder and rotFolder:IsA("Folder")) then return end
	if attachedFolders[rotFolder] then return end
	attachedFolders[rotFolder] = true

	-- Init existing
	for _, d in ipairs(rotFolder:GetDescendants()) do
		if d:IsA("Model") then
			ensurePending(d)
			local ok = initActive(d)
			if ok then Pending[d] = nil end
		end
	end

	rotFolder.DescendantAdded:Connect(function(desc)
		if desc:IsA("Model") then
			ensurePending(desc)
			task.defer(function()
				if initActive(desc) then Pending[desc] = nil end
			end)
		end
	end)

	rotFolder.DescendantRemoving:Connect(function(desc)
		if desc:IsA("Model") then removeModel(desc) end
	end)
end

local function bindWorldFolder(worldFolder)
	if not (worldFolder and worldFolder.Parent == Workspace) then return end
	local obstacles = worldFolder:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local rotational = obstacles:FindFirstChild("Rotational")
		if rotational and rotational:IsA("Folder") then
			bindRotationalFolder(rotational)
		end
		obstacles.ChildAdded:Connect(function(sub)
			if sub.Name == "Rotational" and sub:IsA("Folder") then
				bindRotationalFolder(sub)
			end
		end)
	end
end

local function bindLegacyRoot()
	local obstaclesFolder   = Workspace:FindFirstChild("Obstacles")
	local rotationalFolder  = obstaclesFolder and obstaclesFolder:FindFirstChild("Rotational")
	if rotationalFolder and rotationalFolder:IsA("Folder") then
		bindRotationalFolder(rotationalFolder)
	end
	if obstaclesFolder and obstaclesFolder:IsA("Folder") then
		obstaclesFolder.ChildAdded:Connect(function(sub)
			if sub.Name == "Rotational" and sub:IsA("Folder") then
				bindRotationalFolder(sub)
			end
		end)
	end
end

-- ===== Knit lifecycle ========================================================

function Controller:KnitStart()
	dprint("KnitStart → scanning for Rotational obstacles …")

	-- Fetch rotation start time from ObstacleSyncService
	local syncService   = Knit.GetService("ObstacleSyncService")
	local startTimes    = (syncService and syncService:GetObstacleStartTimes()) or {}
	local rotationStart = startTimes.Rotation or Workspace:GetServerTimeNow()

	-- Bind any existing worlds
	for _, ch in ipairs(Workspace:GetChildren()) do
		if (ch:IsA("Folder") or ch:IsA("Model")) and tostring(ch.Name):match("^World_%d+") then
			bindWorldFolder(ch)
		end
	end

	-- Watch for worlds being added later
	Workspace.ChildAdded:Connect(function(child)
		if (child:IsA("Folder") or child:IsA("Model")) and tostring(child.Name):match("^World_%d+") then
			bindWorldFolder(child)
		end
	end)

	-- Legacy fallback
	bindLegacyRoot()

	dprint("KnitStart complete; controller active.")

	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local char = LocalPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local playerPos = hrp and hrp.Position

		for model, info in pairs(Active) do
			if not (info.model and info.model.Parent and info.basePart and info.basePart.Parent) then
				Active[model] = nil
			else
				if playerPos and info.midPoint and (playerPos - info.midPoint).Magnitude > MAX_UPDATE_DISTANCE then
					-- culled
				else
					local angle = ((now - rotationStart) * info.angularSpeed) % (2 * math.pi)
					local rotCF = CFrame.Angles(0, angle, 0)

					if info.hasPoints and info.startPos and info.endPos and info.travelTime and info.initialRotCF then
						local phase = ((now - rotationStart) / info.travelTime) % 2
						local alpha = math.abs(phase - 1)
						local pos   = info.startPos:Lerp(info.endPos, alpha)
						local cf    = CFrame.new(pos) * rotCF * (info.initialRotCF - info.initialRotCF.Position)
						info.model:PivotTo(cf)
					elseif info.pivotPos and info.initialRotCF then
						local cf = CFrame.new(info.pivotPos) * rotCF * (info.initialRotCF - info.initialRotCF.Position)
						info.model:PivotTo(cf)
					end
				end
			end
		end
	end)
end

return Controller
