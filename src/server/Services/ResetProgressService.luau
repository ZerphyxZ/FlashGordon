-- ServerScriptService/Server/Services/ResetProgressService.luau
-- Place-only reset: clears *current world's* checkpoint + visited set.
-- Opens ResetProgress UI when the player touches ResetProgress_%d+ parts
-- under Workspace.World_###.Reset (and compatible fallbacks).
-- Distinct attributes from global reset:
--   ResetProgressUI, ResetProgressResult, ResetProgressResultMsg

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local ResetProgressService = Knit.CreateService({
	Name = "ResetProgressService",
	Client = {},
})

print("[ResetProgressService] Loaded (server, place-only)")

-- ---------- Helpers ----------------------------------------------------------

local TOUCH_DEBOUNCE = 0.6
local UI_TIMEOUT = 30
local uiDebounce: { [Player]: number } = {}
local touchMap: { [Player]: { [string]: number } } = {}

local function isWorldContainer(inst: Instance?): boolean
	return inst and (inst:IsA("Folder") or inst:IsA("Model")) and tostring(inst.Name):match("^World_%d+")
end

local function isResetProgressPart(inst: Instance?): boolean
	return inst and inst:IsA("BasePart") and tostring(inst.Name):match("^ResetProgress_%d+$") ~= nil
end

local function getCurrentWorldIndex(player: Player): number
	local idx = player and player:GetAttribute("WorldIndex")
	if typeof(idx) ~= "number" then
		idx = ReplicatedStorage:GetAttribute("WorldIndex")
	end
	if typeof(idx) ~= "number" or idx < 1 then
		idx = 1
	end
	return idx
end

local function showUI(player: Player, partName: string)
	-- guard tiny re-open spam
	local now = os.clock()
	if uiDebounce[player] and now - uiDebounce[player] < 0.25 then
		print("[ResetProgressService] UI reopen debounced for", player.Name)
		return
	end
	uiDebounce[player] = now

	print(("[ResetProgressService] Opening ResetProgress UI for %s (from %s)"):format(player.Name, partName))

	player:SetAttribute("ResetProgressUI", true)
	player:SetAttribute("ResetProgressResult", nil)
	player:SetAttribute("ResetProgressResultMsg", nil)

	task.delay(UI_TIMEOUT, function()
		if player and player.Parent and player:GetAttribute("ResetProgressUI") == true then
			print("[ResetProgressService] Auto-closing ResetProgress UI for", player.Name)
			player:SetAttribute("ResetProgressUI", false)
		end
	end)
end

local function bindResetProgressPart(part: BasePart)
	if not part or not part:IsA("BasePart") then
		return
	end
	print("[ResetProgressService] Binding part:", part:GetFullName())

	part.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		if not (char and char:FindFirstChildOfClass("Humanoid")) then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end

		-- per-player *per-part* debounce
		local map = touchMap[player]
		if not map then
			map = {}
			touchMap[player] = map
		end
		local key = part:GetFullName()
		local last = map[key]
		local now = os.clock()
		if last and (now - last) < TOUCH_DEBOUNCE then
			return
		end
		map[key] = now

		showUI(player, part.Name)
	end)
end

local function scanWorld(world: Instance)
	-- look for a "Reset" folder and parts named ResetProgress_%d+
	local resetFolder = world:FindFirstChild("Reset")
	if resetFolder then
		print("[ResetProgressService] Reset folder added:", resetFolder:GetFullName())
		for _, d in ipairs(resetFolder:GetDescendants()) do
			if isResetProgressPart(d) then
				bindResetProgressPart(d :: BasePart)
			end
		end
		resetFolder.DescendantAdded:Connect(function(desc)
			if isResetProgressPart(desc) then
				bindResetProgressPart(desc :: BasePart)
			end
		end)
	end

	-- also bind any stray ResetProgress_%d+ anywhere inside the world
	for _, d in ipairs(world:GetDescendants()) do
		if isResetProgressPart(d) then
			bindResetProgressPart(d :: BasePart)
		end
	end
	world.DescendantAdded:Connect(function(desc)
		if isResetProgressPart(desc) then
			bindResetProgressPart(desc :: BasePart)
		end
	end)
end

-- ---------- Knit lifecycle ---------------------------------------------------

function ResetProgressService:KnitStart()
	print("[ResetProgressService] KnitStart → scanning Workspace for ResetProgress_%d+ parts …")

	-- Bind existing worlds
	for _, ch in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(ch) then
			scanWorld(ch)
		end
	end

	-- Bind future worlds
	Workspace.ChildAdded:Connect(function(child)
		if isWorldContainer(child) then
			scanWorld(child)
		end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		touchMap[plr] = nil
		uiDebounce[plr] = nil
	end)
end

-- ---------- Client API -------------------------------------------------------

-- Called by ResetProgressController when the player confirms the place-only reset
function ResetProgressService.Client:RequestReset(player: Player)
	if not (player and player:IsA("Player")) then
		print("[ResetProgressService] RequestReset called without valid player")
		return false
	end

	print("[ResetProgressService] RequestReset by", player.Name)

	local profile = PlayerDataHandler:GetProfile(player)
	if not (profile and profile:IsActive()) then
		print("[ResetProgressService] No active profile for", player.Name)
		player:SetAttribute("ResetProgressResult", "Failure")
		player:SetAttribute("ResetProgressResultMsg", "Profile not active")
		player:SetAttribute("ResetProgressUI", false)
		return false
	end

	-- Clear ONLY the *current world* progress
	local data = profile.Data
	data.LastCheckpointByWorld = data.LastCheckpointByWorld or {}
	data.VisitedCheckpointsByWorld = data.VisitedCheckpointsByWorld or {}

	local w = getCurrentWorldIndex(player)
	data.LastCheckpointByWorld[w] = nil
	data.VisitedCheckpointsByWorld[w] = {}

	-- Mirror legacy view to reflect the current (now-empty) world
	if PlayerDataHandler.SyncFlatToWorldSnapshot then
		PlayerDataHandler:SyncFlatToWorldSnapshot(player)
	else
		data.LastCheckpoint = nil
		data.VisitedCheckpoints = {}
	end

	-- Save
	local ok, err = pcall(function()
		profile:Save()
	end)
	if not ok then
		warn("[ResetProgressService] Save failed:", err)
		player:SetAttribute("ResetProgressResult", "Failure")
		player:SetAttribute("ResetProgressResultMsg", "Save failed")
		player:SetAttribute("ResetProgressUI", false)
		return false
	end

	-- Clear session flags so next checkpoint awards again
	local cpService = Knit.GetService("CheckpointService")
	if cpService and cpService.ClearPlayerSessionFlags then
		cpService:ClearPlayerSessionFlags(player)
	end

	-- Clear UI-facing attributes for this place
	player:SetAttribute("CheckpointX", nil)
	player:SetAttribute("CheckpointY", nil)
	player:SetAttribute("CheckpointZ", nil)
	player:SetAttribute("VisitedCheckpointsBlob", "")
	player:SetAttribute("LastVisitedCheckpointKey", nil)
	player:SetAttribute("ProgressPercent", 0)
	player:SetAttribute("VisitedCount", 0)

	-- Tell color controller to repaint flags (per-player)
	player:SetAttribute("ResetProgressColours", true)
	task.delay(0.1, function()
		if player and player.Parent == Players then
			player:SetAttribute("ResetProgressColours", false)
		end
	end)

	-- Recompute progress bar for this place
	local progressService = Knit.GetService("ProgressBarService")
	if progressService and progressService.UpdatePlayerNow then
		progressService:UpdatePlayerNow(player)
	end

	-- Ensure IsDead is cleared if they had died previously
	local deathService = Knit.GetService("DeathService")
	if deathService and deathService.SetAlive then
		deathService:SetAlive(player)
	end

	-- Optionally refresh character to remove any physics state
	player:LoadCharacter()

	-- Close UI, report success
	player:SetAttribute("ResetProgressUI", false)
	player:SetAttribute("ResetProgressResult", "Success")
	player:SetAttribute("ResetProgressResultMsg", "Progress reset for this world")

	print("[ResetProgressService] Place-only reset OK for", player.Name, "in world", w)
	return true
end

return ResetProgressService
