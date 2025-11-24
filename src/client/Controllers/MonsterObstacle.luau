-- ObstacleStaticController.luau
-- Client-side Knit controller that detects local-player touches on
-- Static obstacles and triggers the local death sequence.
-- Updated to work under Workspace/World_###/Obstacles/Static
-- (also falls back to legacy Workspace/Obstacles/Static).

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "ObstacleStaticController" }

local LocalPlayer = Players.LocalPlayer

-- Track which parts we've already bound (avoid duplicate connections)
local boundParts = setmetatable({}, { __mode = "k" })

-- ===== Helpers ===============================================================

local function hitBelongsToLocalCharacter(hit: Instance?): boolean
	if not hit then return false end
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
	if not part or not part:IsA("BasePart") then return end
	if boundParts[part] then return end
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
	return inst
		and (inst:IsA("Folder") or inst:IsA("Model"))
		and tostring(inst.Name):match("^World_%d+")
end

local function attachToStaticFolder(staticFolder: Instance)
	if not (staticFolder and staticFolder:IsA("Folder")) then return end

	-- Existing parts
	for _, desc in ipairs(staticFolder:GetDescendants()) do
		if desc:IsA("BasePart") then
			connectObstaclePart(desc)
		end
	end

	-- Live add/remove
	staticFolder.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			connectObstaclePart(desc)
		end
	end)

	staticFolder.DescendantRemoving:Connect(function(desc)
		if desc:IsA("BasePart") then
			boundParts[desc] = nil
		end
	end)
end

local function wireWorld(world: Instance)
	if not (world and world.Parent == Workspace) then return end
	local obstacles = world:FindFirstChild("Obstacles")
	if obstacles and obstacles:IsA("Folder") then
		local staticFolder = obstacles:FindFirstChild("Static")
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

local function wireLegacyRootFallback()
	local obstaclesFolder = Workspace:FindFirstChild("Obstacles")
	if not (obstaclesFolder and obstaclesFolder:IsA("Folder")) then return end
	local staticFolder = obstaclesFolder:FindFirstChild("Static")
	if staticFolder and staticFolder:IsA("Folder") then
		attachToStaticFolder(staticFolder)
	end
	obstaclesFolder.ChildAdded:Connect(function(sub)
		if sub.Name == "Static" and sub:IsA("Folder") then
			attachToStaticFolder(sub)
		end
	end)
end

-- ===== Knit lifecycle ========================================================

function Controller:KnitStart()
	-- Bind existing worlds
	for _, ch in ipairs(Workspace:GetChildren()) do
		if isWorldContainer(ch) then
			wireWorld(ch)
		end
	end
	-- Bind future worlds
	Workspace.ChildAdded:Connect(function(ch)
		if isWorldContainer(ch) then
			wireWorld(ch)
		end
	end)
	-- Legacy fallback
	wireLegacyRootFallback()
end

return Controller
