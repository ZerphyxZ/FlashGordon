-- ObstacleStaticController.luau
-- Client-side Knit controller that detects local-player touches on
-- Static obstacles and triggers the local death sequence.
-- Updated to work under Workspace/World_###/Obstacles/Static
-- (also falls back to legacy Workspace/Obstacles/Static).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ===== Configs ===============================================================

local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local ObstacleConfigs = require(Configuration:WaitForChild("Obstacles"))
local Utility = ReplicatedStorage:WaitForChild("Utility")

local SimpleParticleEmit = require(Utility:WaitForChild("SimpleParticleEmit"))
local CubicBezier: (number) -> () = require(Utility:WaitForChild("CubicBezier"))

local FolderName: string = "Rocks"
-- ===== References	 ===============================================================

local Packages = ReplicatedStorage:WaitForChild("Packages")

-- local CameraShaker = require(Packages:WaitForChild("CameraShaker"))

-- local cam = workspace.CurrentCamera
-- local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(cframe)
--     cam.CFrame = cam.CFrame * cframe
-- end)

local Assets: Folder = ReplicatedStorage:WaitForChild("Assets")
local ObstacleTemplates: Folder = Assets:WaitForChild("Obstacle")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController({ Name = "RockController" })

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

local function scheduleAttack(Laser)
	local syncService = Knit.GetService("ObstacleSyncService")
	local serverTime = workspace:GetServerTimeNow()

	local nextAttackTick = serverTime % Laser.Config.Frequency
	task.delay(nextAttackTick, function()
		Attack(Laser)
	end)
end

local function attachToStaticFolder(staticFolder: Instance)
	if not (staticFolder and staticFolder:IsA("Folder")) then
		return
	end

	-- Live add/remove
	staticFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			local laserObject = makeRock(child)
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
			local laserObject = makeRock(child)

			monsters[child] = laserObject
		end
	end
end

local function wireWorld(world: Instance)
	if not (world and world.Parent == Workspace) then
		return
	end
	local obstacles = world:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local staticFolder = obstacles:FindFirstChild(FolderName)
		if staticFolder and staticFolder:IsA("Folder") then
			attachToStaticFolder(staticFolder)
		end
		-- Listen for Static being created later
		obstacles.ChildAdded:Connect(function(sub)
			if sub.Name == FolderName and sub:IsA("Folder") then
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
function Damage(Rock)
	local hitbox = Instance.new("Part")

	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Transparency = 1

	hitbox.Size = Rock.Size
	hitbox.Position = Rock.Model:GetPivot().Position

	hitbox.Parent = workspace

	local partList = workspace:GetPartBoundsInBox(Rock.Model:GetPivot(), Rock.Size)

	for _, part in partList do
		if hitBelongsToLocalCharacter(part) then
			local dieCtrl = Knit.GetController("DiePlayerController")

			
			if dieCtrl and dieCtrl.Die then
				dieCtrl:Die()
			elseif dieCtrl and dieCtrl.PlayDeath then
				dieCtrl:PlayDeath()
			end

			return
		end
	end
end

function Attack(Rock: {})
	--SimpleParticleEmit(Monster.Config.SpawnEffect, "Burst", CFrame.new(Monster.SpawnPoint.Position)) -- + (Vector3.yAxis * Monster.Size.Y / monsterSizeDivider)))

	local lerpIndex = 0
	local angle = 0
	local falling = true

	Rock.Model:PivotTo(Rock.StartCFrame)

	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if falling then
			lerpIndex = math.min(lerpIndex + deltaTime * Rock.Config.FallingSpeed, 1)
			angle += Rock.Config.RotationSpeed * deltaTime

			if lerpIndex == 1 then
				falling = false
				if connection then
					connection:Disconnect()
					connection = nil
				end

				Damage(Rock)
				return
			end

			local newCFrame = Rock.StartCFrame:Lerp(Rock.EndCFrame, CubicBezier(lerpIndex))
			Rock.Model:PivotTo(CFrame.new(newCFrame.Position) * CFrame.fromEulerAnglesXYZ(0, 0, math.rad(angle)))
		end
	end)
end

function CreateLaserPart(Monster)
	local cylinder: Part = Instance.new("Part")
	cylinder.Shape = "Cylinder"

	local startPosition = Monster.StartAttachment.WorldCFrame.Position
	local endPosition = Monster.HitAttachment.WorldCFrame.Position

	local desiredVector = endPosition - startPosition
	cylinder.CFrame = CFrame.new(startPosition + desiredVector / 2, endPosition)
		* CFrame.fromEulerAngles(0, math.rad(90), 0)
	cylinder.Size =
		Vector3.new((startPosition - endPosition).Magnitude, Monster.Config.LaserWidth, Monster.Config.LaserWidth)
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.CanTouch = false
	cylinder.CanQuery = false
	cylinder.Transparency = 1
	cylinder.Material = Enum.Material.Neon
	cylinder.Color = Color3.fromRGB(255, 0, 0)
	cylinder.Parent = Monster.Model
	cylinder.CastShadow = false

	Monster.HitboxCFrame = cylinder.CFrame
	Monster.HitboxSize = cylinder.Size

	return cylinder
end

function createLaserTween(Monster)
	Monster.AppearTween = TweenService:Create(Monster.Hitbox, TweenInfo.new(0.2), {
		CFrame = Monster.HitboxCFrame,
		Size = Monster.HitboxSize,
	})

	Monster.DisappearTween = TweenService:Create(Monster.Hitbox, TweenInfo.new(Monster.Config.LaserFadeOut), {
		Transparency = 1,
		--Size = Vector3.new(1, Monster.Config.LaserWidth, Monster.Config.LaserWidth),
		--Position = Monster.HitboxAttachment.WorldCFrame.Position
	})
end

function makeRock(RockPlaceholder: Model)
	print("Creating laser alien")
	local config = ObstacleConfigs.Rock

	local rock = nil
	if config then
		rock = {}

		rock.Config = config
		rock.HitAttachment = RockPlaceholder.Hit
		rock.StartAttachment = RockPlaceholder.Start

		local model = ObstacleTemplates:FindFirstChild("Rock")

		if not model then
			warn("No monster model")
			return
		end

		rock.Model = model:Clone()
		rock.Size = rock.Model:GetExtentsSize()
		rock.Delay = RockPlaceholder:GetAttribute("Delay") or 0
		rock.Model.Parent = workspace

		rock.StartCFrame = rock.StartAttachment.WorldCFrame
		rock.StartCFrame += rock.StartCFrame.UpVector * rock.Size.Y / 2
		rock.EndCFrame = rock.HitAttachment.WorldCFrame
		rock.EndCFrame += rock.EndCFrame.UpVector * rock.Size.Y / 2

		-- rock.Model:PivotTo(CFrame.new(
		-- 	rockPosition,
		-- 	Vector3.new(
		-- 		rock.HitAttachment.WorldCFrame.Position.X,
		-- 		rockPosition.Y,
		-- 		rock.HitAttachment.WorldCFrame.Position.Z
		-- 	)
		-- ))

		if not rock.HitAttachment or not rock.StartAttachment or not rock.Model then
			return nil
		end

		-- rock.Hitbox.CanTouch = false
		rock.Hitbox = CreateLaserPart(rock)

		connectObstaclePart(rock.Model.PrimaryPart)

		local serverTime = workspace:GetServerTimeNow()
		local attackDelay = rock.Config.Frequency + rock.Delay
		rock.NextAttack = serverTime - (serverTime % attackDelay) + attackDelay

		rock.AttackConnection = RunService.RenderStepped:Connect(function(deltaTime)
			local now = workspace:GetServerTimeNow()

			if now >= rock.NextAttack then
				rock.NextAttack = now + attackDelay
				Attack(rock)
			end
		end)
	end

	return rock
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
