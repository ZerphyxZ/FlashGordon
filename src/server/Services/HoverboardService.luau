-- Server: HoverboardService.lua
local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local RunService = Global.RunService
local Hoverboards = require(ReplicatedStorage.Shared.Modules.Hoverboards)
local Players = Global.Players

local HoverboardModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Hoverboards")
local DEFAULT_BOARD = "BoostRider" -- Fallback hoverboard model name
local playerHoverboards = {}
local hoverboardDataService
local hoverboard

local HoverboardService = Knit.CreateService({
	Name = "HoverboardService",
	Client = {
		EquipHoverboard = Knit.CreateSignal(),
		HoverboardSpawned = Knit.CreateSignal(),
		HoverboardRemoved = Knit.CreateSignal(),
		SpawnOtherHoverboard = Knit.CreateSignal(),
	},
})

-- Utility: clean up existing hoverboard and constraints on a character
local function cleanupCharacterHoverboard(character)
	if not character then
		return
	end
	-- Destroy hoverboard model if present
	local existing = character:FindFirstChild("Hoverboard")
	if existing then
		existing:Destroy()
	end

	-- -- Destroy server-owned constraints on HRP
	-- local hrp = character:FindFirstChild("HumanoidRootPart")
	-- if hrp then
	-- 	local bv = hrp:FindFirstChild("HoverBodyVelocity")
	-- 	if bv then
	-- 		bv:Destroy()
	-- 	end
	-- 	local bg = hrp:FindFirstChild("HoverBodyGyro")
	-- 	if bg then
	-- 		bg:Destroy()
	-- 	end
	-- 	local motor = hrp:FindFirstChild("HoverboardMotor")
	-- 	if motor then
	-- 		motor:Destroy()
	-- 	end
	-- end
end

-- Calculate offset such that the hoverboard sits flush to player's feet
local function calculateBoardOffset(character, boardModel)
	if not character or not boardModel then
		return 0
	end

	-- Try to base on actual feet parts first (LeftFoot / RightFoot)
	local leftFoot = character:FindFirstChild("LeftFoot")
		or character:FindFirstChild("Left Leg")
		or character:FindFirstChild("LeftLowerLeg")
	local rightFoot = character:FindFirstChild("RightFoot")
		or character:FindFirstChild("Right Leg")
		or character:FindFirstChild("RightLowerLeg")

	local lowestY = math.huge
	if leftFoot or rightFoot then
		if leftFoot and leftFoot:IsA("BasePart") then
			local bottomY = (leftFoot.Position - Vector3.new(0, leftFoot.Size.Y / 2, 0)).Y
			lowestY = math.min(lowestY, bottomY)
		end
		if rightFoot and rightFoot:IsA("BasePart") then
			local bottomY = (rightFoot.Position - Vector3.new(0, rightFoot.Size.Y / 2, 0)).Y
			lowestY = math.min(lowestY, bottomY)
		end
	end

	-- If no explicit foot parts found, fallback to previous character bottom calculation
	if lowestY == math.huge then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				local bottomY = (part.Position - Vector3.new(0, part.Size.Y / 2, 0)).Y
				if bottomY < lowestY then
					lowestY = bottomY
				end
			end
		end
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or lowestY == math.huge then
		return 0
	end

	local rootY = hrp.Position.Y
	local footOffset = rootY - lowestY
	local boardSizeY = boardModel:GetExtentsSize().Y

	-- Keep the same visual tweak as client (-0.7)
	return (footOffset + (boardSizeY / 2)) - 0.7
end

-- Create server-owned physics constraints on HRP & BodyPosition on the board primary part
local function createServerConstraints(character, primaryPart)
	if not character or not primaryPart then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- BodyPosition on the board primary part to maintain hover height (server-owned)
	local bp = primaryPart:FindFirstChild("HoverPosition")
	if bp then
		bp:Destroy()
	end
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.Name = "HoverPosition"
	bodyPosition.MaxForce = Vector3.new(0, 1e6, 0)
	bodyPosition.Position = primaryPart.Position
	bodyPosition.P = 7000
	bodyPosition.D = 500
	bodyPosition.Parent = primaryPart

	-- BodyVelocity on HRP (server-owned authority; client will update .Velocity)
	local bv = hrp:FindFirstChild("HoverBodyVelocity")
	if bv then
		bv:Destroy()
	end
	bv = Instance.new("BodyVelocity")
	bv.Name = "HoverBodyVelocity"
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.P = 8e3
	bv.Parent = hrp

	-- BodyGyro on HRP (server-owned)
	local bg = hrp:FindFirstChild("HoverBodyGyro")
	if bg then
		bg:Destroy()
	end
	bg = Instance.new("BodyGyro")
	bg.Name = "HoverBodyGyro"
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bg.P = 8e3
	bg.D = 300
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	return true
end

----------------------------------------------------------
-- Give Default Hoverboard (only if player doesn't already have one)
----------------------------------------------------------
function HoverboardService:GiveDefaultHoverboard(player)
	-- Only set default if no record exists (so we don't overwrite purchased choices)
	if playerHoverboards[player.UserId] and playerHoverboards[player.UserId].Name then
		-- already have a hoverboard stored
		return
	end

	local boardConfig = Hoverboards.GetConfig(DEFAULT_BOARD)
	if not boardConfig then
		warn("[HoverboardService] Could not find config for: " .. DEFAULT_BOARD)
		return
	end

	print("Giving default hoverboard to player:", player.Name)

	playerHoverboards[player.UserId] = {
		Name = DEFAULT_BOARD,
		Config = boardConfig,
	}

	-- Notify only this player (client will wait for server-cloned Hoverboard)
	self.Client.EquipHoverboard:Fire(player, DEFAULT_BOARD, boardConfig)

	-- Also notify other players to spawn visuals if they want
	for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
		if otherPlayer ~= player then
			self.Client.SpawnOtherHoverboard:Fire(otherPlayer, player, DEFAULT_BOARD)
		end
	end

	-- Spawn server-side model immediately
	self:SpawnHoverboard(player, DEFAULT_BOARD)
end

----------------------------------------------------------
-- Server: spawn hoverboard for a player's character (server clones model + creates constraints)
-- Uses feet for placement and respects stored hoverboard choice
----------------------------------------------------------
function HoverboardService:SpawnHoverboard(player, boardName)
	print("Spawn hoverboard called")

	boardName = boardName
		or (playerHoverboards[player.UserId] and playerHoverboards[player.UserId].Name)
		or DEFAULT_BOARD
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- Clean up any old hoverboard and constraints
	cleanupCharacterHoverboard(character)

	local template = HoverboardModels:FindFirstChild(boardName)
	if not template then
		warn("[HoverboardService] Could not find model: " .. tostring(boardName))
		return
	end

	-- Clone into the character
	local newBoard = template:Clone()
	newBoard.Name = "Hoverboard"
	newBoard.Parent = character
	hoverboard = newBoard

	-- Ensure primary part exists
	local primary = newBoard.PrimaryPart or newBoard:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("[HoverboardService] Hoverboard model has no PrimaryPart:", boardName)
		-- still parented, but can't proceed with constraints
		return
	end

	-- Compute precise offset so it sits exactly below player's feet (uses feet if available)
	local hrp = character.HumanoidRootPart
	local offset = calculateBoardOffset(character, newBoard)

	-- Position the board primary part relative to HRP so Motor6D can weld exactly
	primary.CFrame = hrp.CFrame * CFrame.new(0, -offset, 0)

	-- Create Motor6D (server-owned) between HRP and board primary for exact visuals
	local motor = Instance.new("Motor6D")
	motor.Name = "HoverboardMotor"
	motor.Part0 = hrp
	motor.Part1 = primary
	motor.C0 = CFrame.new(0, -offset, 0)
	motor.Parent = hrp

	-- Create server-owned physics/constraints
	--createServerConstraints(character, primary)

	-- Safely set network ownership to the player for smoother movement
	if newBoard.PrimaryPart then
		newBoard.PrimaryPart:SetNetworkOwner(player)
	end

	-- Notify all clients that hoverboard spawned
	self.Client.HoverboardSpawned:FireAll(player, player, boardName)
end

-- Server: remove hoverboard and constraints
function HoverboardService:RemoveHoverboard(player)
	local character = player.Character
	if not character then
		return
	end
	cleanupCharacterHoverboard(character)
	self.Client.HoverboardRemoved:FireAll(player, player)
end

----------------------------------------------------------
-- Client Requestable Methods
----------------------------------------------------------

----------------------------------------------------------
-- Client request to change equipped hoverboard
-- Client calls :RequestEquipHoverboard(player, boardName)
----------------------------------------------------------
function HoverboardService.Client:RequestEquipHoverboard(player, boardName)
	if not player or not boardName then
		print("returning from here")
		return
	end
	local template = HoverboardModels:FindFirstChild(boardName)
	if not template then
		warn("[HoverboardService] Unknown board requested:", tostring(boardName))
		return
	end

	print("Here")

	-- Update stored config (so spawn on next join will use this)
	playerHoverboards[player.UserId] = {
		Name = boardName,
		Config = Hoverboards.GetConfig(boardName),
	}

	HoverboardService:RemoveHoverboard(player)
	HoverboardService:SpawnHoverboard(player, boardName)

	-- Inform the client's GUI or other players if you want
	self.EquipHoverboard:Fire(player, boardName, playerHoverboards[player.UserId].Config)
	for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
		if otherPlayer ~= player then
			self.SpawnOtherHoverboard:Fire(otherPlayer, player, boardName)
		end
	end
end

function HoverboardService.Client:GetHoverboardData(player)
	local data = playerHoverboards[player.UserId]
	return data or nil
end

function HoverboardService.Client:RequestSpawnHoverboard(player, boardName)
	-- Client asks server to spawn the hoverboard; respect player's equipped board if possible
	local stored = playerHoverboards[player.UserId]
	local nameToSpawn = boardName or (stored and stored.Name) or DEFAULT_BOARD
	HoverboardService:SpawnHoverboard(player, nameToSpawn)
end

function HoverboardService.Client:RequestRemoveHoverboard(player)
	HoverboardService:RemoveHoverboard(player)
end

----------------------------------------------------------
-- Character Setup
----------------------------------------------------------
function HoverboardService:OnCharacterAdded(player)
	-- slight delay to ensure character parts exist
	task.wait(1)

	-- If player has no stored hoverboard, give default. Otherwise spawn stored board.
	if not playerHoverboards[player.UserId] or not playerHoverboards[player.UserId].Name then
		self:GiveDefaultHoverboard(player)
	else
		-- spawn the stored board (will also create constraints)
		local storedName = playerHoverboards[player.UserId].Name
		self:SpawnHoverboard(player, storedName)
	end
end

----------------------------------------------------------
-- Player Handling
----------------------------------------------------------
function HoverboardService:KnitStart()
	hoverboardDataService = Knit.GetService("HoverboardDataService")
	Players.PlayerAdded:Connect(function(player)
		hoverboardDataService:GetEquippedHoverboard(player, playerHoverboards, Hoverboards)
		player.CharacterAdded:Connect(function()
			self:OnCharacterAdded(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		hoverboardDataService:SetEquippedHoverboard(player, playerHoverboards, Hoverboards)
		playerHoverboards[player.UserId] = nil
	end)

	-- Fall death check loop
    -- RunService.Heartbeat:Connect(function()
    --     for userId, data in pairs(playerHoverboards) do
    --         local player = Players:GetPlayerByUserId(userId)
    --         if player and player.Character then
    --             local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    --             local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	-- 			print("falling")
    --             if hrp and humanoid and humanoid.Health > 0 then
	-- 				print("falling 2")
    --                 -- Adjust -100 to your desired death height
    --                 if hrp.Position.Y < -100 then
	-- 					print("killing")
    --                     humanoid.Health = 0
    --                 end
    --             end
    --         end
    --     end
    -- end)
end

return HoverboardService
