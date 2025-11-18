-- ObstacleSyncService.luau
-- Server-side Knit service used to synchronize obstacle start times across clients.
-- It records a session-based start time for each obstacle category (Moving, Rotation, Swing)
-- when Knit starts, and exposes them to clients via GetObstacleStartTimes.

local Workspace = game:GetService("Workspace")
local Knit      = require(game:GetService("ReplicatedStorage").Packages:WaitForChild("Knit"))

local ObstacleSyncService = Knit.CreateService {
    Name = "ObstacleSyncService";
    Client = {};
}

function ObstacleSyncService:KnitStart()
    print("[ObstacleSyncService] KnitStart")
    -- Record the session start time for each category.  If you need per-model times, add logic here.
    local now = Workspace:GetServerTimeNow()
    self.MovingStartTime   = now
    self.RotationStartTime = now
    self.SwingStartTime    = now
    print("[ObstacleSyncService] Start times set:",
        self.MovingStartTime, self.RotationStartTime, self.SwingStartTime)
end

-- Client-callable method to retrieve start times
function ObstacleSyncService.Client:GetObstacleStartTimes(player)
    return {
        Moving   = self.MovingStartTime,
        Rotation = self.RotationStartTime,
        Swing    = self.SwingStartTime,
    }
end

return ObstacleSyncService
