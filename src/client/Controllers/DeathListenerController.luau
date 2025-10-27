-- DeathListenerController.luau
-- Listens for LastDeathTick attribute changes on all players and renders:
--  - spawn of DeathSmoke at the reported ground position
--  - local hide of the dead player's visuals for the vanish time
-- Place under StarterPlayer -> StarterPlayerScripts -> Client -> Controllers

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local DeathListenerController = Knit.CreateController { Name = "DeathListenerController" }

local LOCAL_PLAYER = Players.LocalPlayer
local DEATH_TEMPLATE_NAME = "DeathSmoke"
local PARTICLE_EMIT_COUNT = 1

local hideRestoreTasks = {}

local function findGroundPosition(originPos, ignoreInstances)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = ignoreInstances or {}
    local result = Workspace:Raycast(originPos, Vector3.new(0, -200, 0), rayParams)
    if result and result.Position then
        return result.Position
    end
    return originPos - Vector3.new(0, 3, 0)
end

local function spawnDeathEffectAtPosition(position, vanishTime)
    if not position then return end
    local template = ReplicatedStorage:FindFirstChild(DEATH_TEMPLATE_NAME)
    if not template or not template:IsA("BasePart") then return end

    local groundPos = findGroundPosition(position, {}) + Vector3.new(0, 0.5, 0)
    local clone = template:Clone()
    clone.Name = "DeathSmoke_Effect"
    clone.Anchored = true
    clone.CanCollide = false
    clone.CFrame = CFrame.new(groundPos)
    clone.Parent = Workspace

    local sound = clone:FindFirstChildOfClass("Sound")
    if sound then
        sound:Play()
        local tween = TweenService:Create(sound, TweenInfo.new(math.max(0.1, vanishTime or 1.8), Enum.EasingStyle.Linear), {Volume = 0})
        tween:Play()
        tween.Completed:Connect(function() sound:Stop() end)
    end

    local emitter = clone:FindFirstChildWhichIsA("ParticleEmitter")
    if emitter then
        local initialRate = emitter.Rate or 0
        if initialRate > 0 then
            emitter.Enabled = true
            local tweenE = TweenService:Create(emitter, TweenInfo.new(math.max(0.1, vanishTime or 1.8), Enum.EasingStyle.Linear), {Rate = 0})
            tweenE:Play()
            tweenE.Completed:Connect(function() emitter.Enabled = false end)
        else
            if emitter.Emit then emitter:Emit(PARTICLE_EMIT_COUNT) end
            task.delay(math.max(0.1, vanishTime or 1.8), function() if emitter then emitter.Enabled = false end end)
        end
    end

    Debris:AddItem(clone, math.max(2.5, (vanishTime or 1.8) + 0.8))
end

local function hideCharacterVisualsLocal(character)
    if not character then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if typeof(obj.LocalTransparencyModifier) == "number" then
                obj.LocalTransparencyModifier = 1
            else
                obj.Transparency = 1
            end
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = false
        end
    end
end

local function restoreCharacterVisualsLocal(character)
    if not character then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if typeof(obj.LocalTransparencyModifier) == "number" then
                obj.LocalTransparencyModifier = 0
            else
                obj.Transparency = 0
            end
        elseif obj:IsA("Decal") then
            obj.Transparency = 0
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            obj.Enabled = true
        end
    end
end

local function onPlayerDeathAttribute(player)
    if not player or player == LOCAL_PLAYER then return end
    local pos = player:GetAttribute("LastDeathPosition")
    local vanish = player:GetAttribute("LastDeathVanish") or 1.8
    if typeof(pos) ~= "Vector3" then return end

    spawnDeathEffectAtPosition(pos, vanish)

    if player.Character then
        if hideRestoreTasks[player] then
            hideRestoreTasks[player].cancelled = true
            hideRestoreTasks[player] = nil
        end

        hideCharacterVisualsLocal(player.Character)

        local info = { cancelled = false }
        hideRestoreTasks[player] = info
        task.delay(vanish + 0.8, function()
            if info.cancelled then return end
            if player and player.Character then
                restoreCharacterVisualsLocal(player.Character)
            end
            hideRestoreTasks[player] = nil
        end)
    end
end

function DeathListenerController:KnitStart()
    -- Attach listeners to all players (existing + future)
    for _, pl in ipairs(Players:GetPlayers()) do
        pl:GetAttributeChangedSignal("LastDeathTick"):Connect(function()
            onPlayerDeathAttribute(pl)
        end)
        local lastTick = pl:GetAttribute("LastDeathTick")
        if lastTick and type(lastTick) == "number" and (tick() - lastTick) <= 10 then
            task.delay(0.05, function() onPlayerDeathAttribute(pl) end)
        end
    end

    Players.PlayerAdded:Connect(function(pl)
        pl:GetAttributeChangedSignal("LastDeathTick"):Connect(function()
            onPlayerDeathAttribute(pl)
        end)
        local lastTick = pl:GetAttribute("LastDeathTick")
        if lastTick and type(lastTick) == "number" and (tick() - lastTick) <= 10 then
            task.delay(0.05, function() onPlayerDeathAttribute(pl) end)
        end
    end)

    Players.PlayerRemoving:Connect(function(pl)
        if hideRestoreTasks[pl] then
            hideRestoreTasks[pl].cancelled = true
            hideRestoreTasks[pl] = nil
        end
    end)
end

return DeathListenerController
