-- CheckpointService.luau
-- Server-side logic for checkpoints.
-- Works with new structure: Workspace.World_###.Checkpoints
-- Never paints flags; only updates player data & attributes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local CheckpointService = Knit.CreateService {
	Name = "CheckpointService";
	Client = {};
}

print("[CheckpointService] Service module loaded")

local sessionCheckpointFlags = {}

local function vectorToTable(v) return {v.X,v.Y,v.Z} end

local function awardCoins(player, amount)
	local ok, cs = pcall(function() return Knit.GetService("CurrencyService") end)
	if ok and cs and cs.AwardCoins then
		cs:AwardCoins(player, amount)
	end
end

function CheckpointService:ClearPlayerSessionFlags(player)
	sessionCheckpointFlags[player] = nil
end

local function isCheckpointName(name)
	return name and name:lower():match("^checkpoint_l%d+_i%d+$") ~= nil
end

-- === Locate current world's Checkpoints folder ==============================
local function locateCheckpointsFolder(): Instance?
	for _, ch in ipairs(Workspace:GetChildren()) do
		if tostring(ch.Name):match("^World_%d+") then
			local f = ch:FindFirstChild("Checkpoints")
			if f then return f end
		end
	end
	return Workspace:FindFirstChild("Checkpoints")
end

-- === Find checkpoint part by key ===========================================
local function findCheckpointPartByKey(key)
	if not key then return nil end
	local folder = locateCheckpointsFolder()
	if not folder then return nil end
	local lowerKey = key:lower()
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:lower() == lowerKey then
			return d
		end
	end
	return nil
end

-- === Data persistence =======================================================
local function persistMarkCheckpointVisited(player, checkpointKey)
	if PlayerDataHandler.MarkCheckpointVisited then
		PlayerDataHandler:MarkCheckpointVisited(player, checkpointKey)
		return
	end
	local profile = PlayerDataHandler:GetProfile(player)
	if profile and profile:IsActive() then
		profile.Data.VisitedCheckpoints = profile.Data.VisitedCheckpoints or {}
		profile.Data.VisitedCheckpoints[checkpointKey] = true
		pcall(function() profile:Save() end)
	end
end

local function publishVisitedBlobForPlayer(player)
	local data = PlayerDataHandler:GetData(player)
	local csv = ""
	if data and data.VisitedCheckpoints then
		local keys = {}
		for k,v in pairs(data.VisitedCheckpoints) do if v then table.insert(keys,k:lower()) end end
		table.sort(keys)
		csv = table.concat(keys,",")
	end
	player:SetAttribute("VisitedCheckpointsBlob", csv)
	local count = 0
	for _ in string.gmatch(csv,"([^,]+)") do count += 1 end
	player:SetAttribute("VisitedCount", count)
end

-- === Client fallback ========================================================
function CheckpointService.Client:GetVisitedCheckpointKeys(player)
	local data = PlayerDataHandler:GetData(player)
	local t = {}
	if data and data.VisitedCheckpoints then
		for k,v in pairs(data.VisitedCheckpoints) do
			if v then table.insert(t,k:lower()) end
		end
	end
	table.sort(t)
	return t
end

-- === Connect checkpoint touch ==============================================
function CheckpointService:ConnectCheckpointPart(part)
	if not part:IsA("BasePart") then return end
	part.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		if not (char and char:FindFirstChild("Humanoid")) then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local data = PlayerDataHandler:GetData(player)
		if not data then return end
		local checkpointKey = part.Name:lower()
		sessionCheckpointFlags[player] = sessionCheckpointFlags[player] or {}
		if sessionCheckpointFlags[player][checkpointKey] then return end

		if (data.VisitedCheckpoints and data.VisitedCheckpoints[checkpointKey]) then return end
		sessionCheckpointFlags[player][checkpointKey] = true

		local pos = vectorToTable(part.Position)
		persistMarkCheckpointVisited(player, checkpointKey)
		PlayerDataHandler:SetLastCheckpoint(player, pos)

		player:SetAttribute("CheckpointX", pos[1])
		player:SetAttribute("CheckpointY", pos[2])
		player:SetAttribute("CheckpointZ", pos[3])

		publishVisitedBlobForPlayer(player)
		player:SetAttribute("LastVisitedCheckpointKey", checkpointKey)
		awardCoins(player, 5)
	end)
end

-- === Initialization =========================================================
function CheckpointService:KnitStart()
	local folder = locateCheckpointsFolder()
	if not folder then
		warn("[CheckpointService] No Checkpoints folder found in current world.")
		return
	end
	print("[CheckpointService] Found Checkpoints at", folder:GetFullName())

	local function connectAll()
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and isCheckpointName(d.Name) then
				self:ConnectCheckpointPart(d)
			end
		end
	end
	connectAll()
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and isCheckpointName(d.Name) then
			self:ConnectCheckpointPart(d)
		end
	end)

	Players.PlayerAdded:Connect(function(p)
		task.spawn(function()
			for _=1,40 do
				local data = PlayerDataHandler:GetData(p)
				if data then publishVisitedBlobForPlayer(p) return end
				task.wait(0.25)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(p)
		sessionCheckpointFlags[p] = nil
	end)
end

-- === Respawn API ============================================================
function CheckpointService.Client:RequestRespawn(player)
	if not player then return false end
	local x=player:GetAttribute("CheckpointX")
	local y=player:GetAttribute("CheckpointY")
	local z=player:GetAttribute("CheckpointZ")
	local teleported=false
	if x and y and z then
		local char=player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.CFrame = CFrame.new(x,y,z)
			teleported=true
		end
	end
	if not teleported then
		-- fallback to StartSpawn inside the current world
		local spawn
		for _, w in ipairs(Workspace:GetChildren()) do
			if tostring(w.Name):match("^World_%d+") then
				spawn = w:FindFirstChild("StartSpawn")
				if spawn then break end
			end
		end
		if spawn and spawn:IsA("BasePart") then
			local char=player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0,3,0)
				teleported=true
			end
		end
	end
	return teleported
end

return CheckpointService
