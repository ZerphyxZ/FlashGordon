-- LobbyReturnController.luau
-- Teleport the local player to SpawnLocation or StartSpawn inside the active World_### folder.
-- Compatible with new Workspace.World_### structure.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "LobbyReturnController" }

local LOCAL_PLAYER = Players.LocalPlayer

local BUTTON_PATH = { "MainGui", "LobbyRetureFrame", "LobbyRetureButton" }
local UPWARD_OFFSET = Vector3.new(0, 5, 0)
local _bound = false

-- ===== Find button recursively =====
local function findButton(): TextButton?
	local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if not pg then return nil end
	local node: Instance? = pg:FindFirstChild(BUTTON_PATH[1])
	for i = 2, #BUTTON_PATH do
		if not node then return nil end
		node = node:FindFirstChild(BUTTON_PATH[i])
	end
	return (node and node:IsA("TextButton")) and node or nil
end

-- ===== Locate spawn part inside current world =====
local function locateSpawnPart(): BasePart?
	-- Check all World_### folders
	for _, world in ipairs(Workspace:GetChildren()) do
		if tostring(world.Name):match("^World_%d+") then
			local spawn = world:FindFirstChild("SpawnLocation") or world:FindFirstChild("StartSpawn")
			if spawn and spawn:IsA("BasePart") then
				return spawn
			end
		end
	end
	-- Fallback to legacy Workspace parts
	local top = Workspace:FindFirstChild("SpawnLocation") or Workspace:FindFirstChild("StartSpawn")
	if top and top:IsA("BasePart") then return top end
	return nil
end

-- ===== Teleport local player =====
local function teleportToSpawn()
	local char = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum) then return end

	local spawnPart = locateSpawnPart()
	if not spawnPart then
		warn("[LobbyReturnController] No SpawnLocation or StartSpawn found in world.")
		return
	end

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	local dest = spawnPart.CFrame + UPWARD_OFFSET
	local oldAuto = hum.AutoRotate
	hum.AutoRotate = false
	hrp.CFrame = dest
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	task.delay(0.1, function()
		if hum and hum.Parent then
			hum.AutoRotate = oldAuto
		end
	end)

	print("[LobbyReturnController] Teleported to spawn:", spawnPart:GetFullName())
end

local function bindButtonIfPresent()
	if _bound then return end
	local btn = findButton()
	if not btn then return end
	btn.MouseButton1Click:Connect(teleportToSpawn)
	_bound = true
	print("[LobbyReturnController] Bound LobbyRetureButton.")
end

function Controller:KnitStart()
	bindButtonIfPresent()
	local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	if pg then
		pg.ChildAdded:Connect(function(child)
			if child.Name == "MainGui" then
				task.delay(0.05, function() _bound = false; bindButtonIfPresent() end)
			end
		end)
	else
		task.spawn(function()
			local gui = LOCAL_PLAYER:WaitForChild("PlayerGui")
			gui.ChildAdded:Connect(function(child)
				if child.Name == "MainGui" then
					task.delay(0.05, function() _bound = false; bindButtonIfPresent() end)
				end
			end)
			task.delay(0.05, function() _bound = false; bindButtonIfPresent() end)
		end)
	end

	task.delay(0.25, function() _bound = false; bindButtonIfPresent() end)
	task.delay(1.0,  function() _bound = false; bindButtonIfPresent() end)
end

return Controller
