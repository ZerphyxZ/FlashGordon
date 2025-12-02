-- CheckpointColorController.luau
-- Per-player colouring with persistence + streaming resilience.
-- Works with new structure: Workspace.World_###.Checkpoints

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController({ Name = "CheckpointColorController" })

local LOCAL_PLAYER = Players.LocalPlayer
local TAG = "[CheckpointColorController]"
local function dprint(...)
	print(TAG, ...)
end
local function dwarn(...)
	warn(TAG, ...)
end

local DEFAULT_FLAG_COLOR = Color3.fromRGB(82, 124, 174)
local VISITED_FLAG_COLOR = Color3.fromRGB(255, 0, 0)
local CHECKPOINT_NAME_PATTERN = "^checkpoint_l%d+_i%d+$"

local visitedSet: { [string]: boolean } = {}
local checkpointsFolder: Instance?

-- ===== Helper: locate the correct Checkpoints folder inside current world =====
local function locateCheckpointsFolder(): Instance?
	-- prefer folder inside any World_###
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			if tostring(child.Name):match("^World_%d+") then
				local f = child:FindFirstChild("Checkpoints")
				if f then
					return f
				end
			end
		end
	end
	-- fallback to legacy Workspace.Checkpoints
	return Workspace:FindFirstChild("Checkpoints")
end

local function isCheckpointName(name: string?): boolean
	return name and tostring(name):lower():match(CHECKPOINT_NAME_PATTERN) ~= nil
end

-- find BasePart for checkpoint key
local function findCheckpointPartByKey(keyLower: string): BasePart?
	local folder = checkpointsFolder or locateCheckpointsFolder()
	if not (folder and keyLower) then
		return nil
	end
	local node = folder:FindFirstChild(keyLower)
	if node and node:IsA("BasePart") then
		return node
	end
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and tostring(d.Name):lower() == keyLower then
			return d
		end
	end
	return nil
end

local function getFlagPiecesFromCheckpointPart(cp: BasePart): (BasePart?, BasePart?)
	if not cp then
		return nil, nil
	end
	local container = cp:FindFirstChild("Flag")
	if not container and cp.Parent and cp.Parent:IsA("Model") then
		container = cp.Parent:FindFirstChild("Flag")
	end
	if container and container:IsA("Model") then
		local part, circle
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("BasePart") then
				local ln = d.Name:lower()
				if ln:find("flag") and ln:find("part") then
					part = d
				end
				if ln:find("flag") and (ln:find("circle") or ln:find("ring") or ln:find("disc")) then
					circle = d
				end
			end
		end
		return part, circle
	end
	for _, child in ipairs(cp:GetChildren()) do
		if child:IsA("BasePart") then
			local ln = child.Name:lower()
			if ln:find("flag") and ln:find("part") then
				return child, nil
			end
			if ln:find("flag") and (ln:find("circle") or ln:find("ring") or ln:find("disc")) then
				return nil, child
			end
		end
	end
	return nil, nil
end

local function paintPair(cp: BasePart, visited: boolean)
	local fp, fc = getFlagPiecesFromCheckpointPart(cp)
	if fp then
		fp.Color = visited and VISITED_FLAG_COLOR or DEFAULT_FLAG_COLOR
	end
	if fc then
		fc.Color = visited and VISITED_FLAG_COLOR or DEFAULT_FLAG_COLOR
	end
end

local function repaintAllVisitedOnce()
	local folder = checkpointsFolder or locateCheckpointsFolder()
	if not folder then
		return
	end
	for key, v in pairs(visitedSet) do
		if v then
			local cp = findCheckpointPartByKey(key)
			if cp then
				paintPair(cp, true)
			end
		end
	end
end

local function repaintSweepSchedule()
	for _ = 1, 16 do
		task.wait(0.5)
		repaintAllVisitedOnce()
	end
	for _ = 1, 12 do
		task.wait(1.0)
		repaintAllVisitedOnce()
	end
	for _ = 1, 12 do
		task.wait(5.0)
		repaintAllVisitedOnce()
	end
end

local function parseBlob(csv: any)
	local set = {}
	if type(csv) ~= "string" or #csv == 0 then
		return set
	end
	for key in string.gmatch(csv, "([^,]+)") do
		set[key:lower()] = true
	end
	return set
end

local function mergeVisited(newSet)
	for k, v in pairs(newSet) do
		if v then
			visitedSet[k] = true
		end
	end
end

function Controller:KnitStart()
	dprint("KnitStart")
	local checkpointService = Knit.GetService("CheckpointService")
	checkpointsFolder = locateCheckpointsFolder()
	if not checkpointsFolder then
		Workspace.ChildAdded:Connect(function(ch)
			if tostring(ch.Name):match("^World_%d+") then
				local f = ch:FindFirstChild("Checkpoints")
				if f then
					checkpointsFolder = f
					dprint("Detected Checkpoints in", ch.Name)
				end
			elseif ch.Name == "Checkpoints" then
				checkpointsFolder = ch
			end
		end)
	end

	local blob = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
	mergeVisited(parseBlob(blob))
	repaintAllVisitedOnce()
	task.spawn(repaintSweepSchedule)

	LOCAL_PLAYER:GetAttributeChangedSignal("VisitedCheckpointsBlob"):Connect(function()
		local csv = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
		visitedSet = parseBlob(csv)
		repaintAllVisitedOnce()
		task.spawn(repaintSweepSchedule)
	end)

	task.spawn(function()
		for i = 1, 80 do
			local ok, list = pcall(function()
				return checkpointService:GetVisitedCheckpointKeys()
			end)
			if ok and type(list) == "table" then
				local tmp = {}
				for _, k in ipairs(list) do
					tmp[k:lower()] = true
				end
				mergeVisited(tmp)
				repaintAllVisitedOnce()
				break
			end
			task.wait(0.25)
		end
	end)

	LOCAL_PLAYER:GetAttributeChangedSignal("LastVisitedCheckpointKey"):Connect(function()
		local key = LOCAL_PLAYER:GetAttribute("LastVisitedCheckpointKey")
		if type(key) == "string" and #key > 0 then
			local k = key:lower()
			visitedSet[k] = true
			local cp = findCheckpointPartByKey(k)
			if cp then
				paintPair(cp, true)
			else
				task.spawn(repaintSweepSchedule)
			end
		end
	end)

	LOCAL_PLAYER:GetAttributeChangedSignal("ResetProgressColours"):Connect(function()
		if LOCAL_PLAYER:GetAttribute("ResetProgressColours") == true then
			visitedSet = {}
			local folder = checkpointsFolder or locateCheckpointsFolder()
			if folder then
				for _, d in ipairs(folder:GetDescendants()) do
					if d:IsA("BasePart") and isCheckpointName(d.Name) then
						paintPair(d, false)
					end
				end
			end
			local csv = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
			visitedSet = parseBlob(csv)
			repaintAllVisitedOnce()
			task.spawn(repaintSweepSchedule)
		end
	end)
end

return Controller
