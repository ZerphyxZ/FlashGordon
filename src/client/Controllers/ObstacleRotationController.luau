-- ObstacleRotationController.luau
-- Client-side controller that animates rotational obstacles and kills
-- the local player on contact with their damage parts.  These
-- obstacles live under Workspace.Obstacles.Rotational.  This version
-- waits until parts stream in, supports optional translation with MovingSpeed,
-- and synchronizes rotation start time via ObstacleSyncService.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "ObstacleRotationController" }

-- Debug printing configuration
local DEBUG = false
local LPFX  = "[ObstacleRotationController]"
local function dprint(...) if DEBUG then print(LPFX, ...) end end
local function dwarn(...)  if DEBUG then warn (LPFX, ...) end end

-- Tunables
local LocalPlayer = Players.LocalPlayer
local MAX_UPDATE_DISTANCE = 200
local DEFAULT_ROT_DEG     = 90
local DEFAULT_MOVE_SPEED  = 20
local PENDING_RECHECK_INTERVAL = 0.5
local MAX_PENDING_AGE      = 60

-- Active and pending obstacle tracking
local Active  = {}
local Pending = {}

-- Fuzzy name helpers
local function lower(s) return s:lower() end
local function contains(h, n) return h:lower():find(n:lower(), 1, true) ~= nil end

-- Candidate base part names
local function isBasePartCandidate(inst)
    return inst:IsA("BasePart") and
        (inst.Name == "Rotational_Base_Part" or
         (contains(inst.Name, "rotational") and contains(inst.Name, "base") and contains(inst.Name, "part")))
end

local function isDamagePartCandidate(inst)
    if not inst:IsA("BasePart") then return false end
    local n = inst.Name:lower()
    return (n == "rotational_damage_part_1" or
            n == "rotational_damage_part_2" or
            (contains(n, "rotational") and contains(n, "damage") and contains(n, "part")))
end

-- Fuzzy finders
local function findBasePart(model)
    local exact = model:FindFirstChild("Rotational_Base_Part", true)
    if exact and exact:IsA("BasePart") then return exact end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, d in ipairs(model:GetDescendants()) do
        if isBasePartCandidate(d) then return d end
    end
    return nil
end

local function findDamageParts(model)
    local p1, p2
    local e1 = model:FindFirstChild("Rotational_Damage_Part_1", true)
    local e2 = model:FindFirstChild("Rotational_Damage_Part_2", true)
    if e1 and e1:IsA("BasePart") then p1 = e1 end
    if e2 and e2:IsA("BasePart") then p2 = e2 end
    if not (p1 and p2) then
        for _, d in ipairs(model:GetDescendants()) do
            if isDamagePartCandidate(d) then
                if not p1 then p1 = d
                elseif not p2 then
                    p2 = d
                    break
                end
            end
        end
    end
    return p1, p2
end

local function getAttrNumber(obj, name)
    local v = obj:GetAttribute(name)
    if typeof(v) == "number" then return v end
    return nil
end

local function bindKill(part, modelName, tag)
    if not part then return end
    part.Touched:Connect(function(hit)
        if not hit then return end
        local parent = hit.Parent
        if not parent then return end
        if Players:GetPlayerFromCharacter(parent) == LocalPlayer then
            dprint(("HIT %s on '%s' by local player"):format(tag, modelName))
            local die = Knit.GetController("DiePlayerController")
            if die then
                if die.Die then die:Die() else die:PlayDeath() end
            else
                dwarn("DiePlayerController not available")
            end
        end
    end)
end

-- Initialize active model (once parts available)
local function initActive(model)
    local basePart = findBasePart(model)
    if not basePart then return false, "no-base" end

    local rotDeg = getAttrNumber(model, "RotationSpeed") or getAttrNumber(basePart, "RotationSpeed") or DEFAULT_ROT_DEG
    local moveSp = getAttrNumber(model, "MovingSpeed")   or getAttrNumber(basePart, "MovingSpeed")   or 0
    local angularSpeed = math.rad(rotDeg ~= 0 and rotDeg or DEFAULT_ROT_DEG)

    local startAttachment = model:FindFirstChild("StartPoint", true)
    local endAttachment   = model:FindFirstChild("EndPoint",   true)

    local hasPoints = false
    local startPos, endPos, travelTime, pivotPos, midPoint
    local initialRotCF = model:GetPivot()

    if startAttachment and endAttachment and startAttachment:IsA("Attachment") and endAttachment:IsA("Attachment") and moveSp > 0 then
        startPos  = startAttachment.WorldPosition
        endPos    = endAttachment.WorldPosition
        local dist = (endPos - startPos).Magnitude
        if dist >= 0.05 then
            hasPoints = true
            travelTime = dist / moveSp
            midPoint   = (startPos + endPos) / 2
        else
            dwarn(("Model '%s' Start/End distance < 0.05; translation disabled."):format(model:GetFullName()))
        end
    end
    if not hasPoints then
        pivotPos = basePart.Position
        midPoint = pivotPos
    end

    Active[model] = {
        model        = model,
        basePart     = basePart,
        hasPoints    = hasPoints,
        startPos     = startPos,
        endPos       = endPos,
        travelTime   = travelTime,
        initialRotCF = initialRotCF,
        pivotPos     = pivotPos,
        angularSpeed = angularSpeed,
        midPoint     = midPoint,
        _dbg         = {},
    }

    local dmg1, dmg2 = findDamageParts(model)
    bindKill(dmg1, model.Name, "Rotational_Damage_Part_1")
    bindKill(dmg2, model.Name, "Rotational_Damage_Part_2")

    dprint(("INIT '%s' rotSpeed=%.2fdeg/s moveSpeed=%.2f hasPoints=%s"):format(
        model.Name, rotDeg, moveSp, tostring(hasPoints)))
    return true
end

-- Ensure pending list is created
local function ensurePending(model)
    if Active[model] or Pending[model] then return end
    Pending[model] = { model = model, createdAt = Workspace:GetServerTimeNow(), _dbg = {} }

    model.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") or inst:IsA("Attachment") then
            if Active[model] then return end
            local ok = initActive(model)
            if ok then Pending[model] = nil end
        end
    end)
end

-- Periodically recheck pending models
task.spawn(function()
    while true do
        local now = Workspace:GetServerTimeNow()
        for model, entry in pairs(Pending) do
            if not model.Parent then
                Pending[model] = nil
            else
                local ok, reason = initActive(model)
                if ok then
                    Pending[model] = nil
                else
                    local last = entry._dbg.lastPending or 0
                    if now - last >= 2 then
                        entry._dbg.lastPending = now
                        dprint(("PENDING '%s' waiting for streaming: %s"):format(model:GetFullName(), tostring(reason)))
                    end
                    if now - (entry.createdAt or now) > MAX_PENDING_AGE then
                        dwarn(("PENDING TIMEOUT '%s' after %.1fs"):format(model:GetFullName(), now - entry.createdAt))
                        Pending[model] = nil
                    end
                end
            end
        end
        task.wait(PENDING_RECHECK_INTERVAL)
    end
end)

-- Remove model from maps
local function removeModel(model)
    Active[model] = nil
    Pending[model] = nil
end

-- KNIT START
function Controller:KnitStart()
    dprint("KnitStart → scanning Workspace.Obstacles.Rotational …")

    -- Fetch rotation start time from ObstacleSyncService
    local syncService   = Knit.GetService("ObstacleSyncService")
    local startTimes    = (syncService and syncService:GetObstacleStartTimes()) or {}
    local rotationStart = startTimes.Rotation or Workspace:GetServerTimeNow()

    local obstaclesFolder   = Workspace:FindFirstChild("Obstacles")
    local rotationalFolder  = obstaclesFolder and obstaclesFolder:FindFirstChild("Rotational")

    local function initExisting(folder)
        if not folder then return end
        local m, p, a = 0, 0, 0
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("Model") then m += 1 end
            if d:IsA("BasePart") then p += 1 end
            if d:IsA("Attachment") then a += 1 end
        end
        dprint(("Counts → Models=%d Parts=%d Atts=%d"):format(m, p, a))

        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("Model") then
                ensurePending(d)
                local ok = initActive(d)
                if ok then Pending[d] = nil end
            end
        end
    end

    local function attachWatchers(folder)
        folder.DescendantAdded:Connect(function(desc)
            if desc:IsA("Model") then
                ensurePending(desc)
                task.defer(function()
                    if initActive(desc) then Pending[desc] = nil end
                end)
            end
        end)
        folder.DescendantRemoving:Connect(function(desc)
            if desc:IsA("Model") then removeModel(desc) end
        end)
    end

    if rotationalFolder then
        dprint("Rotational folder found; init existing …")
        initExisting(rotationalFolder)
        attachWatchers(rotationalFolder)
    else
        Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Obstacles" and child:IsA("Folder") then
                obstaclesFolder = child
                child.ChildAdded:Connect(function(sub)
                    if sub.Name == "Rotational" and sub:IsA("Folder") then
                        rotationalFolder = sub
                        dprint("Found Rotational folder later; init …")
                        initExisting(rotationalFolder)
                        attachWatchers(rotationalFolder)
                    end
                end)
            end
        end)
    end

    dprint("KnitStart complete; controller active.")

    RunService.Heartbeat:Connect(function()
        local now = Workspace:GetServerTimeNow()
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local playerPos = hrp and hrp.Position

        for model, info in pairs(Active) do
            if not (info.model and info.model.Parent and info.basePart and info.basePart.Parent) then
                Active[model] = nil
            else
                if playerPos and info.midPoint and (playerPos - info.midPoint).Magnitude > MAX_UPDATE_DISTANCE then
                    -- culled
                else
                    local angle = ((now - rotationStart) * info.angularSpeed) % (2 * math.pi)
                    local rotCF = CFrame.Angles(0, angle, 0)

                    if info.hasPoints and info.startPos and info.endPos and info.travelTime and info.initialRotCF then
                        local phase = ((now - rotationStart) / info.travelTime) % 2
                        local alpha = math.abs(phase - 1)
                        local pos   = info.startPos:Lerp(info.endPos, alpha)
                        local cf    = CFrame.new(pos) * rotCF * (info.initialRotCF - info.initialRotCF.Position)
                        info.model:PivotTo(cf)
                    elseif info.pivotPos and info.initialRotCF then
                        local cf = CFrame.new(info.pivotPos) * rotCF * (info.initialRotCF - info.initialRotCF.Position)
                        info.model:PivotTo(cf)
                    end
                end
            end
        end
    end)
end

return Controller
