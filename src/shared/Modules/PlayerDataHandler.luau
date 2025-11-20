-- ReplicatedStorage/Shared/Modules/PlayerDataHandler.luau
-- Per-world checkpoint/visited handling with legacy field mirroring.
-- Adds spin helpers used by SpinService (non-breaking).
-- DEBUG prints added.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")

local PlayerDataTemplate = require(script.Parent:WaitForChild("PlayerDataTemplate"))
local ProfileStoreModule = require(ServerPackages:WaitForChild("Profilestore"))

local Configuration = ServerStorage:WaitForChild("Configuration")
local DataStoreName = Configuration:WaitForChild("DataStoreName")
local DataStoreVersion = Configuration:WaitForChild("DataStoreVersion")

local DataStoreKey: string = `{DataStoreName.Value}_{DataStoreVersion.Value}`
local PlayerStore = ProfileStoreModule.New(DataStoreKey, PlayerDataTemplate)

local PlayerDataHandler = {}

local Profiles: { [Player]: typeof(PlayerStore:StartSessionAsync()) } = {}
local JoinTimes: { [Player]: number } = {}

-- Internal key used to tag which world the *flat snapshot* reflects.
-- This field is stored inside profile.Data and keeps migrations world-safe.
local FLAT_MIRROR_WORLD_KEY = "_FlatMirrorWorldIndex"

-- === helpers ================================================================

local function getCurrentWorldIndex(player: Player): number
	-- Prefer per-player attribute (set by WorldRouterService), else global.
	local idx = player:GetAttribute("WorldIndex")
	if typeof(idx) ~= "number" then
		idx = ReplicatedStorage:GetAttribute("WorldIndex")
	end
	if typeof(idx) ~= "number" then
		idx = 1
	end
	if idx < 1 then
		idx = 1
	end
	return idx
end

local function ensurePerWorldContainers(profileData: table)
	profileData.LastCheckpointByWorld = profileData.LastCheckpointByWorld or {}
	profileData.VisitedCheckpointsByWorld = profileData.VisitedCheckpointsByWorld or {}
end

-- Copy the *current* world's per-world data into legacy flat fields for
-- back-compat with existing systems (ProgressBarService, CheckpointService, etc.)
-- Also tag which world those flat fields represent so we can migrate safely later.
function PlayerDataHandler:SyncFlatToWorldSnapshot(player: Player)
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then
		return
	end
	local data = profile.Data
	ensurePerWorldContainers(data)

	local w = getCurrentWorldIndex(player)
	local worldVisited = data.VisitedCheckpointsByWorld[w] or {}
	local worldCP = data.LastCheckpointByWorld[w]

	-- mirror to legacy keys
	data.VisitedCheckpoints = {}
	for k, v in pairs(worldVisited) do
		if v then
			data.VisitedCheckpoints[k] = true
		end
	end
	data.LastCheckpoint = worldCP and { worldCP[1], worldCP[2], worldCP[3] } or nil

	-- Tag which world these flat fields belong to
	data[FLAT_MIRROR_WORLD_KEY] = w
	print(("[PlayerDataHandler] SyncFlatToWorldSnapshot → world %d mirrored to flat for %s"):format(w, player.Name))
end

-- When some older system writes to the legacy flat fields, this pushes those
-- values back into the *current* world’s slot. To avoid cross-place bleed,
-- we ONLY migrate if the flat snapshot is tagged for the same world.
function PlayerDataHandler:MigrateFlatToWorldForCurrent(player: Player)
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then
		return
	end
	local data = profile.Data
	ensurePerWorldContainers(data)

	local w = getCurrentWorldIndex(player)

	-- World-safe guard: only migrate if the flat mirror matches current world.
	-- If there is no tag, we *skip migration* to avoid accidental bleed across worlds.
	local flatWorld = data[FLAT_MIRROR_WORLD_KEY]
	if typeof(flatWorld) ~= "number" or flatWorld ~= w then
		print(
			string.format(
				"[PlayerDataHandler] Skip migrate: flat belongs to world %s, current is %d (player=%s)",
				tostring(flatWorld),
				w,
				player.Name
			)
		)
		return
	end

	-- migrate LastCheckpoint
	if data.LastCheckpoint ~= nil then
		local lc = data.LastCheckpoint
		if type(lc) == "table" and lc[1] ~= nil then
			data.LastCheckpointByWorld[w] = { lc[1], lc[2], lc[3] }
		else
			data.LastCheckpointByWorld[w] = nil
		end
	end

	-- migrate VisitedCheckpoints
	if data.VisitedCheckpoints ~= nil then
		local byWorld = {}
		for k, v in pairs(data.VisitedCheckpoints) do
			if v then
				byWorld[string.lower(k)] = true
			end
		end
		data.VisitedCheckpointsByWorld[w] = byWorld
	end

	print(("[PlayerDataHandler] MigrateFlatToWorldForCurrent OK → world %d for %s"):format(w, player.Name))
end

-- === lifecycle ===============================================================
function PlayerDataHandler:LoadProfile(player)
	-- Start a profile session for this player's data:

	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	-- Handling new profile session or failure to start it:

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)
		ensurePerWorldContainers(profile.Data)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			JoinTimes[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			JoinTimes[player] = os.time()
			print(`Profile loaded for {player.DisplayName}!`)
		else
			-- The player has left before the profile session started
			profile:EndSession()
		end
	else
		-- This condition should only happen when the Roblox server is shutting down
		player:Kick(`Profile load fail - Please rejoin`)
	end
end

function PlayerDataHandler:ReleaseProfile(player: Player)
	print("[PlayerDataHandler] Releasing profile for", player.Name)
	local profile = Profiles[player]
	if profile ~= nil then
		local joinStamp = JoinTimes[player]
		if joinStamp then
			local elapsed = os.time() - joinStamp
			profile.Data.Playtime = (profile.Data.Playtime or 0) + elapsed
			print("[PlayerDataHandler] Added playtime", elapsed, "seconds for", player.Name)
		end
		JoinTimes[player] = nil

		profile:EndSession()
	end
end

function PlayerDataHandler:GetProfile(player: Player)
	return Profiles[player]
end

function PlayerDataHandler:GetData(player: Player)
	local profile = Profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

function PlayerDataHandler:SetPlayerData(player: Player, dataTable: { [string]: any })
	if not player then
		warn("Player doesn't exists while getting data")
		return
	end

	local playerProfile = Profiles[player]
	if playerProfile then
		for valueName: string, value: any in dataTable do
			local playerValueHolder = player:FindFirstChild("PlayerValues")

			-- Check if the value exists in PlayerValues folder and is an IntValue
			if playerValueHolder and playerValueHolder:FindFirstChild(valueName) then
				playerValueHolder[valueName].Value = value
			else
				-- If not found in PlayerValues, update the profile data
				if playerProfile.Data[valueName] ~= nil then
					playerProfile.Data[valueName] = value
				else
					warn(`Value {valueName} doesn't exist in player's data table`)
				end
			end
		end
	else
		warn("Profile not found while setting data")
	end
end

-- === currency ================================================================
function PlayerDataHandler:IncrementCoins(player: Player, amountEarned: number)
	local playerData = self:GetData(player)
	if playerData then
		local prevCoins = playerData.Coins
		local updatedCoins = prevCoins + amountEarned
		--print(updatedCoins,"updatedCoins")
		self:SetPlayerData(player, { Coins = updatedCoins })
		player:SetAttribute("Coins", updatedCoins)
	end
end

-- === checkpoints (per-world, with legacy mirror) =============================

function PlayerDataHandler:SetLastCheckpoint(player: Player, positionTable: { number })
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		ensurePerWorldContainers(profile.Data)
		local w = getCurrentWorldIndex(player)
		profile.Data.LastCheckpointByWorld[w] = { positionTable[1], positionTable[2], positionTable[3] }

		-- mirror to legacy field for back-compat AND tag which world it mirrors
		profile.Data.LastCheckpoint = { positionTable[1], positionTable[2], positionTable[3] }
		profile.Data[FLAT_MIRROR_WORLD_KEY] = w

		print(
			"[PlayerDataHandler] SetLastCheckpoint (world",
			w,
			") for",
			player.Name,
			"to",
			positionTable[1],
			positionTable[2],
			positionTable[3]
		)
		pcall(function()
			profile:Save()
		end)
	end
end

function PlayerDataHandler:HasVisitedCheckpoint(player: Player, checkpointKey: string)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		ensurePerWorldContainers(profile.Data)
		local w = getCurrentWorldIndex(player)
		profile.Data.VisitedCheckpointsByWorld[w] = profile.Data.VisitedCheckpointsByWorld[w] or {}
		return profile.Data.VisitedCheckpointsByWorld[w][string.lower(checkpointKey)] == true
	end
	return false
end

function PlayerDataHandler:MarkCheckpointVisited(player: Player, checkpointKey: string)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		ensurePerWorldContainers(profile.Data)
		local w = getCurrentWorldIndex(player)
		local key = string.lower(checkpointKey)

		profile.Data.VisitedCheckpointsByWorld[w] = profile.Data.VisitedCheckpointsByWorld[w] or {}
		profile.Data.VisitedCheckpointsByWorld[w][key] = true

		-- mirror to legacy set for *current* world and tag it
		profile.Data.VisitedCheckpoints = {}
		for k, v in pairs(profile.Data.VisitedCheckpointsByWorld[w]) do
			if v then
				profile.Data.VisitedCheckpoints[k] = true
			end
		end
		profile.Data[FLAT_MIRROR_WORLD_KEY] = w

		print("[PlayerDataHandler] MarkCheckpointVisited (world", w, "):", player.Name, key)
		pcall(function()
			profile:Save()
		end)
	end
end

-- === full reset to template (experience-wide) =================================
-- (kept API; now also clears per-world stores)
function PlayerDataHandler:ResetProfileToTemplate(player: Player)
	local profile = Profiles[player]
	if not profile or not profile:IsActive() then
		return false, "Profile not active"
	end

	profile.Data.Coins = PlayerDataTemplate.Coins or 0
	profile.Data.Playtime = PlayerDataTemplate.Playtime or 0

	-- Clear *all* worlds
	profile.Data.LastCheckpointByWorld = {}
	profile.Data.VisitedCheckpointsByWorld = {}

	-- Mirror legacy (current world view cleared) and clear the tag
	profile.Data.LastCheckpoint = nil
	profile.Data.VisitedCheckpoints = {}
	profile.Data[FLAT_MIRROR_WORLD_KEY] = nil

	local ok, err = pcall(function()
		profile:Save()
	end)
	if not ok then
		return false, ("Save failed: %s"):format(tostring(err))
	end

	print("[PlayerDataHandler] Profile reset to template for", player.Name)
	return true
end

-- === Hoverboard storage ================================================

function PlayerDataHandler:GetEquippedHoverboard(player: Player): string
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		return profile.Data.HoverboardName or "Default"
	end
	return "Default"
end

function PlayerDataHandler:SetEquippedHoverboard(player: Player, boardName: string)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile.Data.HoverboardName = boardName
		pcall(function()
			profile:Save()
		end)
		print("[PlayerDataHandler] Hoverboard saved for", player.Name, "→", boardName)
	end
end

--[Daily Reward Helpers]
function PlayerDataHandler:SetLastDailyClaim(player: Player)
	local now = os.time()
	local playerData = self:GetData(player)
	if playerData then
		self:SetPlayerData(player, { LastDailyReward = now })
	end
end

function PlayerDataHandler:IncrementStreak(player: Player, incrementValue: number)
	local playerData = self:GetData(player)
	if playerData then
		local oldValue = playerData.DailyStreak
		local newValue = oldValue + math.clamp(tonumber(incrementValue) or 0, 0, 1)
		self:SetPlayerData(player, { DailyStreak = newValue })
	end
end

function PlayerDataHandler:ResetStreak(player: Player)
	local playerData = self:GetData(player)

	if playerData then
		self:SetPlayerData(player, { DailyStreak = 0 })
	end
end

--[Daily Reward Helpers]
function PlayerDataHandler:IncrementSpins(player: Player, incrementValue: number)
	local playerData = self:GetData(player)
	--print(playerData,"Increment spin player data")
	if playerData then
		local oldValue = playerData.AvailableSpin
		local newValue = oldValue + math.clamp(incrementValue, 0, 10)
		--print("New value",newValue)
		self:SetPlayerData(player, { AvailableSpin = newValue })
	end
end

function PlayerDataHandler:DeductSpins(player: Player, detectValue: number)
	local playerData = self:GetData(player)

	if playerData then
		local oldValue = playerData.AvailableSpin

		--print("DeductSpins", oldValue, detectValue)
		local newValue = oldValue - detectValue

		if newValue < 0 then
			warn(`Player doesn't have enough coins. Can't deduct {detectValue} from {oldValue}`)
			return
		end

		self:SetPlayerData(player, { AvailableSpin = newValue })
	end
end

function PlayerDataHandler:SetLastSpinnerClaim(player: Player)
	local now = os.time()
	local playerData = self:GetData(player)
	if playerData then
		self:SetPlayerData(player, { LastSpinReward = now })
	end
end

return PlayerDataHandler
