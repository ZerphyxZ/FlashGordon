-- ObstacleSwingController.luau
-- Client-side Knit controller that animates Swing obstacles under
-- Workspace.Obstacles.Swing.  Each Swing model must contain a
-- Ball_Collider_Part and Swing_Rop_Part.  Only the ball kills the
-- player if its material is Neon.  Swing arcs ±55° around the Z-axis
-- and optionally moves between StartPoint and EndPoint with MovingSpeed.
-- SwingSpeed attribute (degrees/sec) is required.  MovingSpeed
-- attribute (studs/sec) is optional.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local ObstacleSwingController = Knit.CreateController { Name = "ObstacleSwingController" }

local LocalPlayer = Players.LocalPlayer

-- Constants
local SWING_MAX_ANGLE_DEG = 55
local DEFAULT_SWING_SPEED_DEG = 70
local DEFAULT_MOVING_SPEED = 6
local MAX_UPDATE_DISTANCE = 220
local RECHECK_ATTEMPTS = 20
local RECHECK_DELAY    = 0.15

local swingMap = {}

-- Detect if a hit belongs to the local player's character
local function belongsToLocalCharacter(hit)
    if not hit then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local p = hit
    while p do
        if p == char then return true end
        p = p.Parent
    end
    return false
end

-- Bind kill on ball if it's Neon material
local function bindKill(ball)
    if not (ball and ball:IsA("BasePart")) then return end
    if ball.Material ~= Enum.Material.Neon then
        print("[SwingCtrl] Ball not neon → harmless:", ball:GetFullName())
        return
    end
    print("[SwingCtrl] Bind kill on NEON ball:", ball:GetFullName())
    ball.Touched:Connect(function(hit)
        if belongsToLocalCharacter(hit) then
            local dieCtrl = Knit.GetController("DiePlayerController")
            if dieCtrl then
                if dieCtrl.Die then dieCtrl:Die() else dieCtrl:PlayDeath() end
            end
        end
    end)
end

-- Wait for Ball_Collider_Part and Swing_Rop_Part
local function waitForParts(model)
    for i = 1, RECHECK_ATTEMPTS do
        local ball = model:FindFirstChild("Ball_Collider_Part", true)
        local rope = model:FindFirstChild("Swing_Rop_Part", true)
        if ball or rope then
            return ball, rope
        end
        task.wait(RECHECK_DELAY)
    end
    return nil, nil
end

-- Initialize a swing obstacle model
local function initSwingModel(model)
    if swingMap[model] then return end
    if not model:IsDescendantOf(Workspace) then return end

    local ball, rope = waitForParts(model)
    print(("[SwingCtrl] Checking '%s' → ball=%s rope=%s"):format(model.Name, tostring(ball), tostring(rope)))

    if not (ball or rope) then
        warn("[SwingCtrl] Skipping model (still missing parts after waiting):", model.Name)
        return
    end

    local swingSpeedDeg = model:GetAttribute("SwingSpeed") or DEFAULT_SWING_SPEED_DEG
    local swingSpeed    = math.rad(swingSpeedDeg)
    local movingSpeed   = model:GetAttribute("MovingSpeed") or 0

    local startA = model:FindFirstChild("StartPoint", true)
    local endA   = model:FindFirstChild("EndPoint",   true)
    local hasPoints = startA and endA and startA:IsA("Attachment") and endA:IsA("Attachment") and movingSpeed > 0

    local startPos, endPos, travelTime, midPoint
    if hasPoints then
        startPos  = startA.WorldPosition
        endPos    = endA.WorldPosition
        local dist = (endPos - startPos).Magnitude
        if dist > 0.05 then
            travelTime = dist / movingSpeed
            midPoint   = (startPos + endPos) * 0.5
        else
            hasPoints = false
        end
    else
        midPoint = model:GetPivot().Position
    end

    swingMap[model] = {
        model      = model,
        ball       = ball,
        rope       = rope,
        swingSpeed = swingSpeed,
        hasPoints  = hasPoints,
        startPos   = startPos,
        endPos     = endPos,
        travelTime = travelTime,
        initialRot = model:GetPivot().Rotation,
        pivotPos   = model:GetPivot().Position,
        midPoint   = midPoint,
    }

    bindKill(ball)

    print(("[SwingCtrl] INIT '%s' SwingSpeed=%.1f°/s MovingSpeed=%.1f hasPoints=%s")
        :format(model.Name, swingSpeedDeg, movingSpeed, tostring(hasPoints)))
end

-- Remove model from map
local function forgetSwingModel(model)
    if swingMap[model] then
        swingMap[model] = nil
        print("[SwingCtrl] Removed model:", model.Name)
    end
end

-- Per-frame update (Z-axis swing)
local function updateAll(swingStartTime)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position
    local t   = Workspace:GetServerTimeNow()

    for model, info in pairs(swingMap) do
        if not (model and model.Parent) then
            forgetSwingModel(model)
        else
            if playerPos and info.midPoint and (playerPos - info.midPoint).Magnitude > MAX_UPDATE_DISTANCE then
                -- skip distant obstacles
            else
                local angleZ = math.rad(SWING_MAX_ANGLE_DEG) * math.sin(info.swingSpeed * (t - swingStartTime))
                local posCF
                if info.hasPoints and info.startPos and info.endPos and info.travelTime then
                    local phase  = ((t - swingStartTime) / info.travelTime) % 2
                    local alpha  = math.abs(phase - 1)
                    local pos    = info.startPos:Lerp(info.endPos, alpha)
                    posCF = CFrame.new(pos)
                else
                    posCF = CFrame.new(info.pivotPos)
                end
                local cf = posCF * CFrame.Angles(0, 0, angleZ) * info.initialRot
                model:PivotTo(cf)
            end
        end
    end
end

function ObstacleSwingController:KnitStart()
    print("[SwingCtrl] KnitStart → looking for Workspace.Obstacles.Swing …")

    local syncService = Knit.GetService("ObstacleSyncService")
    local times = (syncService and syncService:GetObstacleStartTimes()) or {}
    local swingStartTime = times.Swing or Workspace:GetServerTimeNow()

    local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
    local swingFolder     = obstaclesFolder and obstaclesFolder:FindFirstChild("Swing")

    local function connectFolder(folder)
        if not folder then return end
        print("[SwingCtrl] Swing folder found; scanning now …")
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Model") then
                task.defer(initSwingModel, child)
            end
        end
        folder.ChildAdded:Connect(function(child)
            if child:IsA("Model") then
                print("[SwingCtrl] Child model added:", child.Name)
                task.defer(initSwingModel, child)
            end
        end)
        folder.ChildRemoved:Connect(function(child)
            if child:IsA("Model") then forgetSwingModel(child) end
        end)
    end

    if swingFolder then
        connectFolder(swingFolder)
    else
        Workspace.ChildAdded:Connect(function(c)
            if c.Name == "Obstacles" then
                obstaclesFolder = c
                local sw = obstaclesFolder:FindFirstChild("Swing")
                if sw then connectFolder(sw) else
                    obstaclesFolder.ChildAdded:Connect(function(sub)
                        if sub.Name == "Swing" then connectFolder(sub) end
                    end)
                end
            end
        end)
    end

    RunService.Heartbeat:Connect(function()
        updateAll(swingStartTime)
    end)

    print("[SwingCtrl] KnitStart complete; controller active.")
end

return ObstacleSwingController
