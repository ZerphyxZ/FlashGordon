-- ObstacleStaticController.luau
-- Client-side Knit controller that detects local-player touches on
-- Static obstacles and triggers the local death sequence.
-- Updated to work under Workspace/World_###/Obstacles/Static
-- (also falls back to legacy Workspace/Obstacles/Static).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ===== Configs ===============================================================

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local ObstacleConfigs = require(Configuration:WaitForChild("Obstacles"))
local Utility = ReplicatedStorage:WaitForChild("Utility")

local SimpleParticleEmit = require(Utility:WaitForChild("SimpleParticleEmit"))

-- ===== References	 ===============================================================

local Assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local MonsterTemplates: Folder = Assets:WaitForChild("Obstacle")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController({ Name = "MonsterObstacleController" })

-- Track which parts we've already bound (avoid duplicate connections)
local boundParts = setmetatable({}, { __mode = "k" })
local monsters = {}

-- constants
local monsterSizeDivider = 2

-- ===== Helpers ===============================================================

local function hitBelongsToLocalCharacter(hit: Instance?): boolean
	if not hit then
		return false
	end
	local cur = hit
	while cur and cur.Parent do
		if cur.Parent == LocalPlayer.Character then
			return true
		end
		cur = cur.Parent
	end
	return false
end

local function connectObstaclePart(part: BasePart)
	if not part or not part:IsA("BasePart") then
		return
	end
	if boundParts[part] then
		return
	end
	boundParts[part] = true

	part.Touched:Connect(function(hit)
		if hitBelongsToLocalCharacter(hit) then
			local dieCtrl = Knit.GetController("DiePlayerController")
			if dieCtrl and dieCtrl.Die then
				dieCtrl:Die()
			elseif dieCtrl and dieCtrl.PlayDeath then
				dieCtrl:PlayDeath()
			end
		end
	end)
end

-- ===== World-aware binding ===================================================

local function isWorldContainer(inst: Instance?): boolean
	return inst and (inst:IsA("Folder") or inst:IsA("Model")) and tostring(inst.Name):match("^World_%d+")
end

local function scheduleAttack(Monster)
	-- local syncService = Knit.GetService("ObstacleSyncService")

	local nextAttackTick = workspace:GetServerTimeNow() % Monster.Config.Frequency
	print("Next attack tick: ", nextAttackTick)
	task.delay(nextAttackTick, function()
		Attack(Monster)
	end)
end

local function attachToStaticFolder(staticFolder: Instance)
	if not (staticFolder and staticFolder:IsA("Folder")) then
		return
	end

	-- Live add/remove
	staticFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			local monsterObject = MakeMonster(child)
			scheduleAttack(monsterObject)
		end
	end)

	staticFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			if monsters[child] then
				if monsters[child].NextAttack ~= nil then
					task.cancel(monsters[child].NextAttack.cancel())
					monsters[child].Model:Destroy()
					monsters[child] = nil
				end
			end
		end
	end)

	-- Existing parts
	for _, child in ipairs(staticFolder:GetChildren()) do
		if child:IsA("Model") then
			local monsterObject = MakeMonster(child)
			scheduleAttack(monsterObject)

			monsters[child] = monsterObject
		end
	end
end

local function wireWorld(world: Instance)
	if not (world and world.Parent == Workspace) then
		return
	end
	local obstacles = world:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local staticFolder = obstacles:FindFirstChild("Monster")
		if staticFolder and staticFolder:IsA("Folder") then
			attachToStaticFolder(staticFolder)
		end
		-- Listen for Static being created later
		obstacles.ChildAdded:Connect(function(sub)
			if sub.Name == "Static" and sub:IsA("Folder") then
				attachToStaticFolder(sub)
			end
		end)
	end
end

-- local function wireLegacyRootFallback()
-- 	local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
-- 	if not (obstaclesFolder and obstaclesFolder:IsA("Folder")) then return end
-- 	local staticFolder = obstaclesFolder:FindFirstChild("Static")
-- 	if staticFolder and staticFolder:IsA("Folder") then
-- 		attachToStaticFolder(staticFolder)
-- 	end
-- 	obstaclesFolder.ChildAdded:Connect(function(sub)
-- 		if sub.Name == "Static" and sub:IsA("Folder") then
-- 			attachToStaticFolder(sub)
-- 		end
-- 	end)
-- end

-- ===== Knit lifecycle ========================================================

function Attack(Monster: {})
	--print("Attack", Monster)

	SimpleParticleEmit(Monster.Config.SpawnEffect, "Burst", CFrame.new(Monster.SpawnPoint.Position)) -- + (Vector3.yAxis * Monster.Size.Y / monsterSizeDivider)))
	Monster.Model.Parent = workspace
	Monster.Model:PivotTo(CFrame.new(Monster.SpawnPoint:GetPivot().Position, Monster.Hitbox:GetPivot().Position))
	-- Monster.AnimationTrack:Play()

	local hitboxPos = Monster.Hitbox:GetPivot().Position
	local startPos = Monster.SpawnPoint.Position
	local translation = TweenService:Create(
		Monster.Model.PrimaryPart,
		TweenInfo.new(Monster.Config.AnimationTime),
		{
			CFrame = CFrame.new(
				hitboxPos + (Vector3.yAxis * Monster.Size.Y / 2),
				hitboxPos + (hitboxPos - startPos).Unit + (Vector3.yAxis * Monster.Size.Y / 2)
			),
		}
	)

	-- play animation
	local animation = Instance.new("Animation")
	animation.AnimationId = Monster.Config.AnimationId

	animation = Monster.Model.AnimationController.Animator:LoadAnimation(animation)
	animation:Play()

	-- play attack sequence
	translation:Play()
	translation.Completed:Wait()

	SimpleParticleEmit(Monster.Config.ImpactEffect, "Burst", Monster.Hitbox:GetPivot())
	SimpleParticleEmit(Monster.Config.HitEffect, "Burst", Monster.Hitbox.Position)

	Monster.Hitbox.CanTouch = true

	task.delay(Monster.Config.ImpactDuration, function()
		Monster.Hitbox.Transparency = 0.5
		Monster.Hitbox.CanTouch = false
		Monster.Model.Parent = ReplicatedStorage
	end)
end

function MakeMonster(MonsterPlaceholder: Model)
	local config = ObstacleConfigs[MonsterPlaceholder.Name]

	local monster = nil
	if config then
		monster = {}

		monster.Config = config
		monster.Hitbox = MonsterPlaceholder.Hitbox
		monster.SpawnPoint = MonsterPlaceholder.Spawn
		monster.Model = MonsterTemplates:WaitForChild(MonsterPlaceholder.Name):Clone()
		monster.Size = monster.Model:GetExtentsSize()

		monster.Delay = MonsterPlaceholder:GetAttribute("Delay") or 0

		if not monster.Hitbox or not monster.SpawnPoint or not monster.Model then
			return nil
		end

		monster.Hitbox.CanTouch = false
		connectObstaclePart(monster.Hitbox)

		local serverTime = workspace:GetServerTimeNow()
		local attackDelay = monster.Config.Frequency + monster.Delay
		monster.NextAttack = serverTime - (serverTime % attackDelay) + attackDelay

		monster.AttackConnection = RunService.RenderStepped:Connect(function(deltaTime)
			local now = workspace:GetServerTimeNow()

			if now >= monster.NextAttack then
				monster.NextAttack = now + attackDelay
				Attack(monster)
			end
		end)
	end

	return monster
end

function Controller:KnitStart()
	-- Bind existing worlds
	for _, ch in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(ch) then
			wireWorld(ch)
		end
	end

	-- Legacy fallback
	-- wireLegacyRootFallback()
end

return Controller
