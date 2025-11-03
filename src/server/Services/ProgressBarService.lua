-- ServerScriptService/Server/Services/ProgressBarService.luau
-- Computes per-player progress; supports Workspace.World_### structure
-- and reads the *current world's* visited set (per-world aware).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local ProgressBarService = Knit.CreateService {
	Name = "ProgressBarService";
	Client = {};
}

local CHECKPOINT_PATTERN = "^checkpoint_l%d+_i%d+$"

local function isCheckpointPart(part)
	return part and part:IsA("BasePart") and part.Name:lower():match(CHECKPOINT_PATTERN) ~= nil
end

local function locateCheckpointsFolder()
	for _, child in ipairs(Workspace:GetChildren()) do
		if tostring(child.Name):match("^World_%d+") then
			local f = child:FindFirstChild("Checkpoints")
			if f then return f end
		end
	end
	return Workspace:FindFirstChild("Checkpoints")
end

local function countCheckpoints()
	local folder = locateCheckpointsFolder()
	if not folder then return 0 end
	local total = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if isCheckpointPart(d) then total += 1 end
	end
	return total
end

local function getCurrentWorldIndex(player: Player): number
	local idx = player and player:GetAttribute("WorldIndex")
	if typeof(idx) ~= "number" then
		idx = ReplicatedStorage:GetAttribute("WorldIndex")
	end
	if typeof(idx) ~= "number" or idx < 1 then idx = 1 end
	return idx
end

function ProgressBarService:UpdatePlayerNow(player)
	if not player then return end
	local total = self.TotalCheckpoints or countCheckpoints()
	local data = PlayerDataHandler:GetData(player)

	-- Read visited ONLY for the current world (fallback to legacy)
	local visited = 0
	if data then
		local w = getCurrentWorldIndex(player)
		local set = (data.VisitedCheckpointsByWorld and data.VisitedCheckpointsByWorld[w]) or data.VisitedCheckpoints
		if set then
			for _, v in pairs(set) do if v then visited += 1 end end
		end
	end

	local percent = 0
	if total > 0 then
		percent = math.clamp(math.floor((visited / total) * 100 + 0.5), 0, 100)
	end
	player:SetAttribute("ProgressPercent", percent)
	player:SetAttribute("VisitedCount", visited)
	player:SetAttribute("TotalCheckpoints", total)
end

function ProgressBarService:UpdateAllNow()
	local _ = self.TotalCheckpoints or countCheckpoints()
	for _, pl in ipairs(Players:GetPlayers()) do
		self:UpdatePlayerNow(pl)
	end
end

function ProgressBarService:KnitStart()
	print("[ProgressBarService] KnitStart called")
	local total = countCheckpoints()
	self.TotalCheckpoints = total
	print("[ProgressBarService] Total checkpoints:", total)

	local folder = locateCheckpointsFolder()
	if folder then
		local function refresh()
			self.TotalCheckpoints = countCheckpoints()
			self:UpdateAllNow()
			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("TotalCheckpoints", self.TotalCheckpoints)
			end
			print("[ProgressBarService] Recounted checkpoints →", self.TotalCheckpoints)
		end
		folder.DescendantAdded:Connect(refresh)
		folder.DescendantRemoving:Connect(refresh)
	else
		warn("[ProgressBarService] No Checkpoints folder found; progress = 0 until available.")
	end

	Players.PlayerAdded:Connect(function(p)
		task.delay(0.2, function() self:UpdatePlayerNow(p) end)
	end)

	task.spawn(function()
		while true do
			self:UpdateAllNow()
			task.wait(0.6)
		end
	end)
end

return ProgressBarService
