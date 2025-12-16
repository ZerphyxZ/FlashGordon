-- DiePlayerController.luau
-- Handles the full local death sequence (stop, hide, play DeathSmoke, notify, respawn)
-- Compatible with Workspace.World_### structure.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local DiePlayerController = Knit.CreateController { Name = "DiePlayerController" }

local LocalPlayer = Players.LocalPlayer

local RESPAWN_DELAY       = 1
local PARTICLE_EMIT_COUNT = 1
local PARTICLE_DURATION   = 1.8
local DEBRIS_CLEANUP      = 2
local DEATH_TEMPLATE_NAME = "DeathSmoke"

local isDying = false

local function hideCharacterVisuals(character)
	if not character then return end
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 1
		elseif obj:IsA("Decal") then
			obj.Transparency = 1
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
			obj.Enabled = false
		end
	end
end

local function stopCharacterMovement(character)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.PlatformStand = true
		hum.AutoRotate = false
		if hum:GetState() ~= Enum.HumanoidStateType.Dead then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end

	if hrp then
		hrp.Anchored = true
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function restoreCharacterMovement(character)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hum then
		--hum.PlatformStand = false
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.AutoRotate = true
	end
	if hrp then hrp.Anchored = false end
end

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

local function requestServerRespawn()
	local respawnService = Knit.GetService("RespawnService")
	if respawnService and respawnService.Respawn then
		respawnService:Respawn()
	end
end

function DiePlayerController:Die()
	if isDying then return end
	isDying = true

	local player = LocalPlayer
	if not player then isDying = false return end
	local char = player.Character
	if not (char and char:FindFirstChildOfClass("Humanoid")) then
		isDying = false
		return
	end

	stopCharacterMovement(char)
	hideCharacterVisuals(char)

	local deathService = Knit.GetService("DeathService")
	if deathService and deathService.NotifyDeath then
		deathService:NotifyDeath()
	end

	playDeathEffectAtCharacter(char)

	task.delay(RESPAWN_DELAY, function()
		requestServerRespawn()
		task.delay(1.2, function() isDying = false end)
	end)
end

function DiePlayerController:PlayDeath()
	return self:Die()
end

function DiePlayerController:KnitStart()
	LocalPlayer.CharacterAdded:Connect(function(char)
		task.defer(function()
			local hum = char:WaitForChild("Humanoid", 3)
			if hum then
				restoreCharacterMovement(char)
			end
		end)
	end)
end

return DiePlayerController
