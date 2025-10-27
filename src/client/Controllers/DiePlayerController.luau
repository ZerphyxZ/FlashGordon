-- DiePlayerController.luau
-- Client-side Knit controller that runs the entire "die" sequence for the local player.
-- (stop movement, hide, play DeathSmoke, notify server, request respawn)
-- Place under StarterPlayer → StarterPlayerScripts → Client → Controllers

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local DiePlayerController = Knit.CreateController { Name = "DiePlayerController" }

local LocalPlayer = Players.LocalPlayer

-- Config
local RESPAWN_DELAY       = 1
local PARTICLE_EMIT_COUNT = 1
local PARTICLE_DURATION   = 1.8
local DEBRIS_CLEANUP      = 2
local DEATH_TEMPLATE_NAME = "DeathSmoke"

-- State
local isDying = false

---------------------------------------------------------------------
-- Helper: hide visuals
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- Stop all motion completely
---------------------------------------------------------------------
local function stopCharacterMovement(character)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if humanoid then
		-- Freeze all humanoid control
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		-- Force Roblox into a Dead state to stop physics animation movement
		if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end

	if hrp then
		-- Fully anchor to prevent drifting/falling after death
		hrp.Anchored = true
		hrp.Velocity = Vector3.zero
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

---------------------------------------------------------------------
-- Restore movement when new character spawns
---------------------------------------------------------------------
local function restoreCharacterMovement(character)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if humanoid then
		humanoid.PlatformStand = false
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
	end

	if hrp then
		hrp.Anchored = false
		hrp.Velocity = Vector3.zero
	end
end

---------------------------------------------------------------------
-- Find ground for effect placement
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- Play Death Smoke effect
---------------------------------------------------------------------
local function playDeathEffectAtCharacter(character)
	if not character then return end
	local template = ReplicatedStorage:FindFirstChild(DEATH_TEMPLATE_NAME)
	if not (template and template:IsA("BasePart")) then
		warn("[DiePlayerController] DeathSmoke template not found:", DEATH_TEMPLATE_NAME)
		return
	end

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

---------------------------------------------------------------------
-- Ask server for respawn
---------------------------------------------------------------------
local function requestServerRespawn()
	local respawnService = Knit.GetService("RespawnService")
	if respawnService and respawnService.Respawn then
		respawnService:Respawn()
	else
		warn("[DiePlayerController] RespawnService or Respawn method not available")
	end
end

---------------------------------------------------------------------
-- Main death logic
---------------------------------------------------------------------
function DiePlayerController:Die()
	if isDying then return end
	isDying = true

	local player = LocalPlayer
	if not player then
		isDying = false
		return
	end

	local character = player.Character
	if not (character and character:FindFirstChildOfClass("Humanoid")) then
		isDying = false
		return
	end

	print("[DiePlayerController] Triggered Die()")

	stopCharacterMovement(character)
	hideCharacterVisuals(character)

	-- Replicate death to others
	local deathService = Knit.GetService("DeathService")
	if deathService and deathService.NotifyDeath then
		deathService:NotifyDeath()
	end

	playDeathEffectAtCharacter(character)

	-- Wait then ask for respawn
	task.delay(RESPAWN_DELAY, function()
		requestServerRespawn()
		task.delay(1.2, function()
			isDying = false
		end)
	end)
end

function DiePlayerController:PlayDeath()
	return self:Die()
end

---------------------------------------------------------------------
-- Knit lifecycle
---------------------------------------------------------------------
function DiePlayerController:KnitStart()
	print("[DiePlayerController] KnitStart initialized")

	-- Re-enable movement when new character spawns
	LocalPlayer.CharacterAdded:Connect(function(char)
		task.defer(function()
			local hum = char:WaitForChild("Humanoid", 3)
			if hum then
				print("[DiePlayerController] Respawn detected → restoring movement")
				restoreCharacterMovement(char)
			end
		end)
	end)
end

return DiePlayerController
