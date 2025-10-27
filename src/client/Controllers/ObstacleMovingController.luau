-- MovingObstacleController.luau
-- Client-side Knit controller that animates moving obstacles and kills
-- the local player on contact. Designed for models under:
-- Workspace -> Obstacles -> Translation -> MovingObstacle_#
-- Each model should contain:
--   Moving_Obstacle_Part (Part)   -- kill brick
--   StartPoint (Attachment)       -- start position anchor
--   EndPoint (Attachment)         -- end position anchor
-- The Moving_Obstacle_Part may have a "Speed" number attribute.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local MovingObstacleController = Knit.CreateController { Name = "MovingObstacleController" }

local LocalPlayer = Players.LocalPlayer

-- How far away (studs) before we stop updating an obstacle to save CPU
local MAX_UPDATE_DISTANCE = 200
-- Default speed if no Speed attribute exists
local DEFAULT_SPEED = 5

-- Container for active moving obstacles
-- Keyed by the part; values contain movement data
local movingObstacles = {}

-- Helper: returns true if the hit belongs to the local player's character
local function hitBelongsToLocalCharacter(hit)
    if not hit then return false end
    local current = hit
    while current do
        if current.Parent == LocalPlayer.Character then
            return true
        end
        current = current.Parent
    end
    return false
end

-- Compute world position for attachments or parts
local function getWorldPosition(obj)
    if not obj then return nil end
    if obj:IsA("Attachment") then
        return obj.WorldPosition or (obj.WorldCFrame and obj.WorldCFrame.Position) or nil
    end
    if obj:IsA("BasePart") then
        return obj.Position
    end
    if obj:IsA("Model") then
        local pp = obj.PrimaryPart
        if pp then return pp.Position end
        local cf = obj:GetModelCFrame()
        return cf and cf.Position or nil
    end
    return nil
end

-- Initialize a moving obstacle model: extract endpoints, speed, and initial rotation
local function initMovingObstacle(model)
    if not model or not model:IsA("Model") then return end
    local part = model:FindFirstChild("Moving_Obstacle_Part")
    if not (part and part:IsA("BasePart")) then return end

    local startAttachment = model:FindFirstChild("StartPoint") or model:FindFirstChild("StartPoint", true)
    local endAttachment   = model:FindFirstChild("EndPoint")   or model:FindFirstChild("EndPoint",   true)

    local startPos = getWorldPosition(startAttachment)
    local endPos   = getWorldPosition(endAttachment)
    if not (startPos and endPos) then
        warn("[MovingObstacleController] Missing StartPoint or EndPoint on", model:GetFullName())
        return
    end

    local speedAttr = part:GetAttribute("Speed")
    local speed = (typeof(speedAttr) == "number" and speedAttr > 0) and speedAttr or DEFAULT_SPEED

    local distance = (endPos - startPos).Magnitude
    if distance <= 0 then
        warn("[MovingObstacleController] Start and End attachments are at the same position for", model:GetFullName())
        return
    end

    local travelTime = distance / speed
    local initialRotation = part.CFrame.Rotation

    part.Anchored = true

    movingObstacles[part] = {
        model        = model,
        part         = part,
        startPos     = startPos,
        endPos       = endPos,
        travelTime   = travelTime,
        initialRot   = initialRotation,
    }

    part.Touched:Connect(function(hit)
        if hitBelongsToLocalCharacter(hit) then
            local dieCtrl = Knit.GetController("DiePlayerController")
            if dieCtrl then
                if dieCtrl.Die then dieCtrl:Die() else dieCtrl:PlayDeath() end
            end
        end
    end)
end

-- Remove obstacle from table on part removal
local function removeMovingObstacle(part)
    movingObstacles[part] = nil
end

function MovingObstacleController:KnitStart()
    -- Fetch the moving start time from the server after Knit is started.
    local syncService = Knit.GetService("ObstacleSyncService")
    local startTimes  = (syncService and syncService:GetObstacleStartTimes()) or {}
    local movingStartTime = startTimes.Moving or Workspace:GetServerTimeNow()

    local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
    local translationFolder = obstaclesFolder and obstaclesFolder:FindFirstChild("Translation")

    -- Initialize and watch for new obstacles
    local function initFolder(folder)
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "Moving_Obstacle_Part" then
                initMovingObstacle(obj.Parent)
            end
        end
        folder.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") and desc.Name == "Moving_Obstacle_Part" then
                initMovingObstacle(desc.Parent)
            end
        end)
        folder.DescendantRemoving:Connect(function(desc)
            if desc:IsA("BasePart") and movingObstacles[desc] then
                removeMovingObstacle(desc)
            end
        end)
    end

    if translationFolder then
        initFolder(translationFolder)
    else
        Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Obstacles" then
                obstaclesFolder = child
                child.ChildAdded:Connect(function(subchild)
                    if subchild.Name == "Translation" and subchild:IsA("Folder") then
                        translationFolder = subchild
                        initFolder(subchild)
                    end
                end)
            end
        end)
    end

    RunService.Heartbeat:Connect(function(dt)
        local serverTime = Workspace:GetServerTimeNow()
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local playerPos = hrp and hrp.Position

        for _, obstacle in pairs(movingObstacles) do
            local part       = obstacle.part
            local startPos   = obstacle.startPos
            local endPos     = obstacle.endPos
            local travelTime = obstacle.travelTime
            if part and part.Parent and travelTime > 0 then
                local skip = false
                if playerPos then
                    local midpoint = (startPos + endPos) / 2
                    if (playerPos - midpoint).Magnitude > MAX_UPDATE_DISTANCE then
                        skip = true
                    end
                end
                if not skip then
                    local cycle = (serverTime - movingStartTime) / travelTime
                    local phase = cycle % 2
                    local alpha = math.abs(phase - 1)
                    local newPos = startPos:Lerp(endPos, alpha)
                    part.CFrame = CFrame.new(newPos) * obstacle.initialRot
                end
            end
        end
    end)
end

return MovingObstacleController
