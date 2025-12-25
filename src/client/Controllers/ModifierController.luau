-- [Services]           -----
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- [Modules]            -----
local Packages: Folder  = ReplicatedStorage:WaitForChild("Packages")
local Knit: {}          = require(Packages:WaitForChild("Knit"))
local Observers: {}     = require(Packages:WaitForChild("Observers"))

local Controller = Knit.CreateController { Name = "ModifierController" }

-- [References]         ----
local LocalPlayer = Players.LocalPlayer
local Character
local HoverboardController

local DEBOUNCE_TIMER = 1

function CreateBoostObject(BoostHitbox: Part)

    if not BoostHitbox:IsA("Part") then return end
    
    BoostHitbox.Transparency = 1

    local debounce = false
    local boostPower = BoostHitbox:GetAttribute("Force")
    local lookVector = BoostHitbox.CFrame.LookVector

    local particle = BoostHitbox:FindFirstChildOfClass("ParticleEmitter")
    local emitCount = particle ~= nil and particle:GetAttribute("EmitCount") or 0
    local sound = BoostHitbox:FindFirstChildOfClass("Sound")

    BoostHitbox.Touched:Connect(function(otherPart)
        if Character and Character.Humanoid and Character.Humanoid.Health > 0 and otherPart.Parent == Character and not debounce then
            debounce = true
            HoverboardController:ApplyAssist(lookVector * boostPower)

            if particle then
                particle:Emit(emitCount)
            end

            task.delay(DEBOUNCE_TIMER, function()
                debounce = false
            end)
        end
    end)

    
    return function ()
        
    end
end

function CreateJumpPadObject(JumpPad: Part)
    
    warn("Create jump pad object")

    local debounce = false
    local boostPower = JumpPad:GetAttribute("Force")

    JumpPad.Touched:Connect(function(otherPart)
        if Character and Character.Humanoid and Character.Humanoid.Health > 0 and otherPart.Parent == Character and not debounce then
            debounce = true
            HoverboardController:ApplyJump(boostPower)

            warn("Apply force", boostPower)

            task.delay(DEBOUNCE_TIMER, function()
                debounce = false
            end)
        end
    end)

    return function ()
        
    end
end

function CreateSlowObject(SlowObject: Part)
    
    local debounce = false

    SlowObject.Touched:Connect(function(otherPart)
        if Character and Character.Humanoid and Character.Humanoid.Health > 0 and otherPart.Parent == Character and not debounce then
            debounce = true
            HoverboardController:Slow()

            task.delay(DEBOUNCE_TIMER, function()
                debounce = false
            end)
        end
    end)

    return function ()
        
    end
end

function BindTagWithFunction(Tag: string, Function: () -> ())
    for _, boostInstance: Part in CollectionService:GetTagged(Tag) do
        Function(boostInstance)
    end
end

function Controller:KnitStart()
    HoverboardController = Knit.GetController("NewController")

    -- have a character reference
    
    -- Character = LocalPlayer.Character
    -- LocalPlayer.CharacterAdded:Connect(function(character)
    --     Character = character
    -- end)
    Observers.observeLocalCharacter(function(character)
        Character = character

        return function ()
            Character = nil
        end
    end)

    -- bind observer
    Observers.observeTag("Boost", CreateBoostObject)
    Observers.observeTag("JumpPad", CreateJumpPadObject)
    Observers.observeTag("Slow", CreateSlowObject)
end

return Controller
