-- ProgressBarService.luau
-- Server-side Knit service that computes per-player progress (percentage) from visited checkpoints.
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
    if not part or not part:IsA("BasePart") then return false end
    return tostring(part.Name):lower():match(CHECKPOINT_PATTERN) ~= nil
end

local function countCheckpoints()
    local folder = Workspace:FindFirstChild("Checkpoints")
    if not folder then return 0 end
    local total = 0
    for _, desc in ipairs(folder:GetDescendants()) do
        if isCheckpointPart(desc) then total = total + 1 end
    end
    return total
end

function ProgressBarService:UpdatePlayerNow(player)
    if not player or not player:IsA("Player") then return end
    local total = self.TotalCheckpoints or countCheckpoints()
    local data = PlayerDataHandler:GetData(player)
    local visited = 0
    if data and data.VisitedCheckpoints then
        for _ in pairs(data.VisitedCheckpoints) do visited = visited + 1 end
    end

    local percent = 0
    if total > 0 then
        percent = math.floor((visited / total) * 100 + 0.000001)
        if percent < 0 then percent = 0 end
        if percent > 100 then percent = 100 end
    end

    player:SetAttribute("ProgressPercent", percent)
    player:SetAttribute("VisitedCount", visited)
    player:SetAttribute("TotalCheckpoints", total)
end

function ProgressBarService:UpdateAllNow()
    local total = self.TotalCheckpoints or countCheckpoints()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = PlayerDataHandler:GetData(player)
        local visited = 0
        if data and data.VisitedCheckpoints then
            for _ in pairs(data.VisitedCheckpoints) do visited = visited + 1 end
        end
        local percent = 0
        if total > 0 then
            percent = math.floor((visited / total) * 100 + 0.000001)
            if percent < 0 then percent = 0 end
            if percent > 100 then percent = 100 end
        end
        player:SetAttribute("ProgressPercent", percent)
        player:SetAttribute("VisitedCount", visited)
        player:SetAttribute("TotalCheckpoints", total)
    end
end

function ProgressBarService:KnitStart()
    print("[ProgressBarService] KnitStart called")
    local totalCheckpoints = countCheckpoints()
    self.TotalCheckpoints = totalCheckpoints
    print("[ProgressBarService] Total checkpoints:", totalCheckpoints)

    local function refreshTotal()
        totalCheckpoints = countCheckpoints()
        self.TotalCheckpoints = totalCheckpoints
        for _, player in ipairs(Players:GetPlayers()) do
            player:SetAttribute("TotalCheckpoints", totalCheckpoints)
        end
        print("[ProgressBarService] Recounted checkpoints ->", totalCheckpoints)
        self:UpdateAllNow()
    end

    local folder = Workspace:FindFirstChild("Checkpoints")
    if folder then
        folder.DescendantAdded:Connect(refreshTotal)
        folder.DescendantRemoving:Connect(refreshTotal)
    else
        warn("[ProgressBarService] workspace.Checkpoints not found. Progress will show 0 until created.")
    end

    Players.PlayerAdded:Connect(function(player)
        task.delay(0.1, function()
            self:UpdatePlayerNow(player)
        end)
    end)

    task.spawn(function()
        while true do
            if not self.TotalCheckpoints then self.TotalCheckpoints = countCheckpoints() end
            self:UpdateAllNow()
            task.wait(0.6)
        end
    end)
end

return ProgressBarService
