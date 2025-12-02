-- ServerScriptService/Server/Services/ResetGameDataService.luau
-- GLOBAL reset: clears ALL player data across the experience.
-- Opens ResetGameData UI when the player touches ResetGameData_%d+ parts.
-- Distinct attributes (global flow):
--   ResetGameDataUI, ResetGameDataResult, ResetGameDataResultMsg

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local PlayerDataTemplate = require(ReplicatedStorage.Shared.Modules.PlayerDataTemplate)

local ResetGameDataService = Knit.CreateService({
	Name = "ResetGameDataService",
	Client = {},
})

print("[ResetGameDataService] Loaded (server, GLOBAL)")

-- ---------- Helpers ----------------------------------------------------------

local TOUCH_DEBOUNCE = 0.6
local UI_TIMEOUT = 30
local uiDebounce: { [Player]: number } = {}
local touchMap: { [Player]: { [string]: number } } = {}

local function isWorldContainer(inst: Instance?): boolean
	return inst and (inst:IsA("Folder") or inst:IsA("Model")) and tostring(inst.Name):match("^World_%d+")
end

local function isResetGameDataPart(inst: Instance?): boolean
	if not (inst and inst:IsA("BasePart")) then
		return false
	end
	local n = inst.Name:lower()
	-- Accept common shapes: "ResetGameData_1", "resetgamedata", or anything containing the token
	return n:match("^resetgamedata_%d+$") ~= nil or n == "resetgamedata" or (n:find("resetgamedata", 1, true) ~= nil)
end

local function showUI(player: Player, partName: string)
	local now = os.clock()
	if uiDebounce[player] and now - uiDebounce[player] < 0.25 then
		print("[ResetGameDataService] UI reopen debounced for", player.Name)
		return
	end
	uiDebounce[player] = now

	print(("[ResetGameDataService] Opening GLOBAL Reset UI for %s (from %s)"):format(player.Name, partName))

	player:SetAttribute("ResetGameDataUI", true)
	player:SetAttribute("ResetGameDataResult", nil)
	player:SetAttribute("ResetGameDataResultMsg", nil)

	task.delay(UI_TIMEOUT, function()
		if player and player.Parent and player:GetAttribute("ResetGameDataUI") == true then
			print("[ResetGameDataService] Auto-closing GLOBAL Reset UI for", player.Name)
			player:SetAttribute("ResetGameDataUI", false)
		end
	end)
end

local function bindResetGameDataPart(part: BasePart)
	if not part or not part:IsA("BasePart") then
		return
	end
	print("[ResetGameDataService] Binding part:", part:GetFullName())

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
	local resetFolder = world:FindFirstChild("Reset")
	if resetFolder then
		print("[ResetGameDataService] Reset folder found:", resetFolder:GetFullName())
		local count = 0
		for _, d in ipairs(resetFolder:GetDescendants()) do
			if isResetGameDataPart(d) then
				count += 1
				bindResetGameDataPart(d :: BasePart)
			end
		end
		print(("[ResetGameDataService] Bound %d ResetGameData parts under %s"):format(count, world.Name))
		resetFolder.DescendantAdded:Connect(function(desc)
			if isResetGameDataPart(desc) then
				bindResetGameDataPart(desc :: BasePart)
			end
		end)
	end

	-- Also catch any stray parts anywhere under the world
	for _, d in ipairs(world:GetDescendants()) do
		if isResetGameDataPart(d) then
			bindResetGameDataPart(d :: BasePart)
		end
	end
	world.DescendantAdded:Connect(function(desc)
		if isResetGameDataPart(desc) then
			bindResetGameDataPart(desc :: BasePart)
		end
	end)
end

-- ---------- Knit lifecycle ---------------------------------------------------

function ResetGameDataService:KnitStart()
	print("[ResetGameDataService] KnitStart → scanning Workspace for ResetGameData parts …")

	for _, ch in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(ch) then
			scanWorld(ch)
		end
	end

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

-- Client confirms GLOBAL reset
function ResetGameDataService.Client:ConfirmGlobalReset(player: Player)
	if not (player and player:IsA("Player")) then
		print("[ResetGameDataService] ConfirmGlobalReset without valid player")
		return false
	end

	print("[ResetGameDataService] GLOBAL reset requested by", player.Name)

	local profile = PlayerDataHandler:GetProfile(player)
	if not (profile and profile:IsActive()) then
		print("[ResetGameDataService] No active profile for", player.Name)
		player:SetAttribute("ResetGameDataResult", "Failure")
		player:SetAttribute("ResetGameDataResultMsg", "Profile not active")
		player:SetAttribute("ResetGameDataUI", false)
		return false
	end

	-- Wipe all known data to template + clear *per-world* maps
	profile.Data.Coins = PlayerDataTemplate.Coins or 0
	profile.Data.Playtime = PlayerDataTemplate.Playtime or 0
	profile.Data.LastCheckpoint = nil
	profile.Data.VisitedCheckpoints = {}

	profile.Data.LastCheckpointByWorld = {}
	profile.Data.VisitedCheckpointsByWorld = {}

	-- Save (no pcall to keep logs loud during dev)
	profile:Save()

	-- *** LIVE REFRESH so UI updates immediately ***
	-- Coins attribute + leaderstats.Coins
	local coinsNow = profile.Data.Coins or 0
	player:SetAttribute("Coins", coinsNow)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local coinsVal = leaderstats:FindFirstChild("Coins")
	if not coinsVal then
		coinsVal = Instance.new("IntValue")
		coinsVal.Name = "Coins"
		coinsVal.Parent = leaderstats
	end
	coinsVal.Value = coinsNow
	print(("[ResetGameDataService] Coins live-updated → %d for %s"):format(coinsNow, player.Name))

	-- Clear place-facing attrs so every world starts fresh
	player:SetAttribute("CheckpointX", nil)
	player:SetAttribute("CheckpointY", nil)
	player:SetAttribute("CheckpointZ", nil)
	player:SetAttribute("VisitedCheckpointsBlob", "")
	player:SetAttribute("LastVisitedCheckpointKey", nil)
	player:SetAttribute("ProgressPercent", 0)
	player:SetAttribute("VisitedCount", 0)

	-- Repaint flags for the local player
	player:SetAttribute("ResetProgressColours", true)
	task.delay(0.1, function()
		if player and player.Parent == Players then
			player:SetAttribute("ResetProgressColours", false)
		end
	end)

	-- Recompute progress bar (current place)
	local progressService = Knit.GetService("ProgressBarService")
	if progressService and progressService.UpdatePlayerNow then
		progressService:UpdatePlayerNow(player)
	end

	-- Make sure death flag is cleared
	local deathService = Knit.GetService("DeathService")
	if deathService and deathService.SetAlive then
		deathService:SetAlive(player)
	end

	-- Optional: reload character to avoid stale physics state
	player:LoadCharacter()

	-- Close UI, mark success
	player:SetAttribute("ResetGameDataUI", false)
	player:SetAttribute("ResetGameDataResult", "Success")
	player:SetAttribute("ResetGameDataResultMsg", "All game data reset")

	print("[ResetGameDataService] GLOBAL reset OK for", player.Name)
	return true
end

return ResetGameDataService
