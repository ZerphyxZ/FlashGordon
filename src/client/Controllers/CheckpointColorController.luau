-- CheckpointColorController.luau (CLIENT)
-- Per-player colouring with persistence + slow net/streaming resilience:
--  * Reads VisitedCheckpointsBlob (csv) immediately; also falls back to GetVisitedCheckpointKeys().
--  * Long retry loops and periodic sweeps repaint flags as assets stream in.
--  * Reacts to LastVisitedCheckpointKey and ResetProgressColours (LOCAL PLAYER ONLY).
--  * NEVER paints from server; all color edits are local and not replicated.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "CheckpointColorController" }
local LOCAL_PLAYER = Players.LocalPlayer

-- Debug
local TAG = "[CheckpointColorController]"
local function dprint(...) print(TAG, ...) end
local function dwarn(...) warn(TAG, ...) end

-- Colours
local DEFAULT_FLAG_COLOR = Color3.fromRGB(82, 124, 174)
local VISITED_FLAG_COLOR = Color3.fromRGB(255, 0, 0)

-- Names
local CHECKPOINT_NAME_PATTERN = "^checkpoint_l%d+_i%d+$"

-- State
local visitedSet : {[string]: boolean} = {}
local checkpointsFolder : Instance?

-- === Utils ===

local function isCheckpointName(name: string?): boolean
	return name and tostring(name):lower():match(CHECKPOINT_NAME_PATTERN) ~= nil
end

-- Resolve a checkpoint "key" (lowercase name) to a BasePart to paint.
local function findCheckpointPartByKey(keyLower: string): BasePart?
	local folder = checkpointsFolder or Workspace:FindFirstChild("Checkpoints")
	if not (folder and keyLower) then return nil end

	local node = folder:FindFirstChild(keyLower)
	if node then
		if node:IsA("BasePart") then
			return node
		elseif node:IsA("Model") then
			local best
			for _, d in ipairs(node:GetDescendants()) do
				if d:IsA("BasePart") then
					if tostring(d.Name):lower() == keyLower then
						return d
					end
					best = best or d
				end
			end
			return best
		end
	end

	-- Fallback: deep scan by exact name
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and tostring(d.Name):lower() == keyLower then
			return d
		end
	end

	return nil
end

local function getFlagPiecesFromCheckpointPart(cp: BasePart): (BasePart?, BasePart?)
	if not cp then return nil, nil end
	-- Accept both: Flag (Model) parented directly under checkpoint part, or nearby in hierarchy.
	local container = cp:FindFirstChild("Flag")
	if not container then
		-- try parent model
		local p = cp.Parent
		if p and p:IsA("Model") then
			container = p:FindFirstChild("Flag")
		end
	end

	if container and container:IsA("Model") then
		local flagPart, flagCircle
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("BasePart") then
				local ln = tostring(d.Name):lower()
				if not flagPart and ln:find("flag") and ln:find("part") then
					flagPart = d
				elseif not flagCircle and ln:find("flag") and (ln:find("circle") or ln:find("ring") or ln:find("disc")) then
					flagCircle = d
				end
			end
		end
		return flagPart, flagCircle
	end

	-- Fallback: scan direct children (handles custom setups)
	for _, child in ipairs(cp:GetChildren()) do
		if child:IsA("BasePart") then
			local ln = tostring(child.Name):lower()
			if ln:find("flag") and ln:find("part") then
				return child, nil
			elseif ln:find("flag") and (ln:find("circle") or ln:find("ring") or ln:find("disc")) then
				return nil, child
			end
		elseif child:IsA("Model") then
			for _, d in ipairs(child:GetDescendants()) do
				if d:IsA("BasePart") then
					local ln = tostring(d.Name):lower()
					if ln:find("flag") and ln:find("part") then
						return d, nil
					elseif ln:find("flag") and (ln:find("circle") or ln:find("ring") or ln:find("disc")) then
						return nil, d
					end
				end
			end
		end
	end
	return nil, nil
end

local function paintPair(cp: BasePart, visited: boolean)
	local fp, fc = getFlagPiecesFromCheckpointPart(cp)
	if fp then fp.Color = visited and VISITED_FLAG_COLOR or DEFAULT_FLAG_COLOR end
	if fc then fc.Color = visited and VISITED_FLAG_COLOR or DEFAULT_FLAG_COLOR end
end

local function repaintAllVisitedOnce()
	local folder = checkpointsFolder or Workspace:FindFirstChild("Checkpoints")
	if not folder then return end
	for key, v in pairs(visitedSet) do
		if v then
			local cp = findCheckpointPartByKey(key)
			if cp then paintPair(cp, true) end
		end
	end
end

-- Periodic sweeps to catch streamed parts; backoff to be light
local function repaintSweepSchedule()
	-- early aggressive passes
	for _ = 1, 16 do  task.wait(0.5)  repaintAllVisitedOnce()  end
	-- medium passes
	for _ = 1, 12 do  task.wait(1.0)  repaintAllVisitedOnce()  end
	-- long tail passes (handles very slow streaming/connections)
	for _ = 1, 12 do  task.wait(5.0)  repaintAllVisitedOnce()  end
end

local function parseBlob(csv: any): {[string]: boolean}
	local set = {}
	if type(csv) ~= "string" or #csv == 0 then return set end
	for key in string.gmatch(csv, "([^,]+)") do
		set[tostring(key):lower()] = true
	end
	return set
end

local function mergeVisited(newSet: {[string]: boolean})
	for k, v in pairs(newSet) do
		if v then visitedSet[k] = true end
	end
end

function Controller:KnitStart()
	dprint("KnitStart")
	local checkpointService = Knit.GetService("CheckpointService")

	-- Ensure folder reference (and keep watching if created later)
	checkpointsFolder = Workspace:FindFirstChild("Checkpoints")
	if not checkpointsFolder then
		Workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "Checkpoints" then
				dprint("Detected Workspace.Checkpoints (late).")
				checkpointsFolder = ch
				ch.DescendantAdded:Connect(function(d)
					if d:IsA("BasePart") and isCheckpointName(d.Name) then
						local key = tostring(d.Name):lower()
						if visitedSet[key] then paintPair(d, true) end
					end
				end)
			end
		end)
	else
		checkpointsFolder.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and isCheckpointName(d.Name) then
				local key = tostring(d.Name):lower()
				if visitedSet[key] then paintPair(d, true) end
			end
		end)
	end

	-- 1) Instant read from blob attribute (fast, no remote wait)
	local blob = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
	mergeVisited(parseBlob(blob))
	repaintAllVisitedOnce()
	task.spawn(repaintSweepSchedule)

	-- Keep synced if blob updates later (e.g., profile loaded after join, or a new visit persisted)
	LOCAL_PLAYER:GetAttributeChangedSignal("VisitedCheckpointsBlob"):Connect(function()
		local csv = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
		visitedSet = parseBlob(csv)  -- replace with authoritative set
		dprint("VisitedCheckpointsBlob changed; repainting …")
		repaintAllVisitedOnce()
		task.spawn(repaintSweepSchedule)
	end)

	-- 2) Fallback: also try remote fetch with generous retries in case attributes lag
	task.spawn(function()
		local tries, maxTries = 0, 80  -- up to ~20 seconds
		while tries < maxTries do
			local ok, list = pcall(function() return checkpointService:GetVisitedCheckpointKeys() end)
			if ok and type(list) == "table" then
				local tmp = {}
				for _, key in ipairs(list) do tmp[tostring(key):lower()] = true end
				mergeVisited(tmp)
				repaintAllVisitedOnce()
				dprint("Fetched visited keys via service; merged & repainted.")
				break
			end
			tries += 1
			task.wait(0.25)
		end
	end)

	-- 3) New single visit (fast local paint)
	LOCAL_PLAYER:GetAttributeChangedSignal("LastVisitedCheckpointKey"):Connect(function()
		local key = LOCAL_PLAYER:GetAttribute("LastVisitedCheckpointKey")
		if type(key) == "string" and #key > 0 then
			local k = key:lower()
			visitedSet[k] = true
			local cp = findCheckpointPartByKey(k)
			if cp then
				paintPair(cp, true)
				dprint("Painted visited", k)
			else
				dwarn("Could not resolve part for", k, "— will resweep.")
				task.spawn(repaintSweepSchedule)
			end
		end
	end)

	-- 4) Reset pulse (server clears blob + sets ResetProgressColours)
	-- IMPORTANT: this listens ONLY to the LOCAL player's attribute.
	LOCAL_PLAYER:GetAttributeChangedSignal("ResetProgressColours"):Connect(function()
		local pulse = LOCAL_PLAYER:GetAttribute("ResetProgressColours")
		dprint("ResetProgressColours changed on LOCAL player →", tostring(pulse))
		if pulse == true then
			-- Clear local set and repaint all to default (LOCAL EFFECT ONLY)
			visitedSet = {}
			local folder = checkpointsFolder or Workspace:FindFirstChild("Checkpoints")
			if folder then
				for _, d in ipairs(folder:GetDescendants()) do
					if d:IsA("BasePart") and isCheckpointName(d.Name) then
						paintPair(d, false)
					end
				end
			end

			-- Honour current blob (should be empty right after reset, but handle future updates)
			local csv = LOCAL_PLAYER:GetAttribute("VisitedCheckpointsBlob")
			visitedSet = parseBlob(csv)
			repaintAllVisitedOnce()
			task.spawn(repaintSweepSchedule)
		end
	end)
end

return Controller
