-- ObstacleStaticController.luau
-- Client-side Knit controller that detects local-player touches on Workspace.Obstacles.Static parts
-- and delegates the death sequence to DiePlayerController (no death logic here).
-- Place under StarterPlayer -> StarterPlayerScripts -> Client -> Controllers

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local ObstacleStaticController = Knit.CreateController { Name = "ObstacleStaticController" }

local LocalPlayer = Players.LocalPlayer

-- Helper: returns true if the hit belongs to local player's character (walks up parent chain)
local function hitBelongsToLocalCharacter(hit)
    if not hit then return false end
    local cur = hit
    while cur and cur.Parent do
        if cur.Parent == LocalPlayer.Character then
            return true
        end
        cur = cur.Parent
    end
    return false
end

-- Connect a single obstacle part to call DiePlayerController when touched by local player
local function connectObstaclePart(part)
    if not part or not part:IsA("BasePart") then return end
    part.Touched:Connect(function(hit)
        if hitBelongsToLocalCharacter(hit) then
            local dieCtrl = nil
            if Knit.GetController then
                dieCtrl = Knit.GetController("DiePlayerController")
            end
            if dieCtrl and dieCtrl.Die then
                dieCtrl:Die()
            elseif dieCtrl and dieCtrl.PlayDeath then
                dieCtrl:PlayDeath()
            else
                warn("[ObstacleStaticController] DiePlayerController not available to handle death.")
            end
        end
    end)
end

function ObstacleStaticController:KnitStart()
    print("[ObstacleStaticController] KnitStart - connecting static obstacles")

    local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
    if not obstaclesFolder then
        -- If folder appears later, attach listener
        Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Obstacles" and child:IsA("Folder") then
                obstaclesFolder = child
            end
        end)
    end

    local staticFolder = obstaclesFolder and obstaclesFolder:FindFirstChild("Static")
    if staticFolder then
        -- Connect existing static obstacle parts
        for _, desc in ipairs(staticFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                connectObstaclePart(desc)
            end
        end
        -- Connect newly added parts
        staticFolder.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") then
                connectObstaclePart(desc)
            end
        end)
    else
        -- Listen for Static folder creation later
        if obstaclesFolder then
            obstaclesFolder.ChildAdded:Connect(function(child)
                if child.Name == "Static" and child:IsA("Folder") then
                    staticFolder = child
                    for _, d in ipairs(staticFolder:GetDescendants()) do
                        if d:IsA("BasePart") then connectObstaclePart(d) end
                    end
                    staticFolder.DescendantAdded:Connect(function(desc)
                        if desc:IsA("BasePart") then connectObstaclePart(desc) end
                    end)
                end
            end)
        end
    end
end

return ObstacleStaticController
