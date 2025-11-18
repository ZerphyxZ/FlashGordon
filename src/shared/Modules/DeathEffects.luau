-- DeathEffects.luau
-- Utility for spawning DeathSmoke effect under Workspace.World_### layout

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local DEATH_TEMPLATE_NAME = "DeathSmoke"
local PARTICLE_DURATION   = 1.8
local PARTICLE_EMIT_COUNT = 1
local DEBRIS_CLEANUP      = 2

local function findGroundPosition(originPos, ignoreInstances)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist

	local ignore = ignoreInstances or {}
	for _, inst in ipairs(Workspace:GetChildren()) do
		if tostring(inst.Name):match("^World_%d+") then
			table.insert(ignore, inst)
		end
	end
	rayParams.FilterDescendantsInstances = ignore

	local result = Workspace:Raycast(originPos, Vector3.new(0, -200, 0), rayParams)
	if result and result.Position then
		return result.Position
	end
	return originPos - Vector3.new(0, 3, 0)
end

local function playDeathEffectAtCharacter(character)
	if not character then return end
	local template = ReplicatedStorage:FindFirstChild(DEATH_TEMPLATE_NAME)
	if not (template and template:IsA("BasePart")) then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local groundPos = findGroundPosition(hrp.Position, { character })
	local spawnPos = groundPos + Vector3.new(0, 0.5, 0)

	local clone = template:Clone()
	clone.Name = "DeathSmoke_Effect"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CFrame = CFrame.new(spawnPos)
	clone.Parent = Workspace

	local sound = clone:FindFirstChildOfClass("Sound")
	if sound then
		sound:Play()
		local tween = TweenService:Create(sound, TweenInfo.new(PARTICLE_DURATION, Enum.EasingStyle.Linear), { Volume = 0 })
		tween:Play()
		tween.Completed:Connect(function() sound:Stop() end)
	end

	local emitter = clone:FindFirstChild("ParticleEmitterSmoke") or clone:FindFirstChildWhichIsA("ParticleEmitter")
	if emitter then
		local rate = emitter.Rate or 0
		if rate > 0 then
			emitter.Enabled = true
			local tweenE = TweenService:Create(emitter, TweenInfo.new(PARTICLE_DURATION, Enum.EasingStyle.Linear), { Rate = 0 })
			tweenE:Play()
			tweenE.Completed:Connect(function() emitter.Enabled = false end)
		else
			if emitter.Emit then emitter:Emit(PARTICLE_EMIT_COUNT) end
			task.delay(PARTICLE_DURATION, function() emitter.Enabled = false end)
		end
	end

	Debris:AddItem(clone, DEBRIS_CLEANUP)
end

return {
	playDeathEffectAtCharacter = playDeathEffectAtCharacter
}
