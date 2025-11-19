-- Server: HoverboardService.lua
local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local RunService = Global.RunService
local Hoverboards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard"):WaitForChild("Hoverboards"))
local Players = Global.Players
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local HoverboardModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Hoverboards")
local DEFAULT_BOARD = "Default" -- Fallback hoverboard model name
local playerHoverboards = {}
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
local function CleanupCharacterHoverboard(character)
	if not character then
		return
	end
	-- Destroy hoverboard model if present
	local existing = character:FindFirstChild("Hoverboard")
	if existing then
		existing:Destroy()
	end
end

-- Calculate offset such that the hoverboard sits flush to player's feet
local function CalculateBoardOffset(character, boardModel)
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

	-- Keep the same visual tweak as client
	return (footOffset + (boardSizeY / 2))
end

function HoverboardService.Client:GetBoardOffset(player)
	local character = player.Character
	if not character then return 0 end

	local hoverboard = character:FindFirstChild("Hoverboard")
	if not hoverboard then return 0 end
	
	return CalculateBoardOffset(character, hoverboard)
end
----------------------------------------------------------
-- Give Default Hoverboard (only if player doesn't already have one)
----------------------------------------------------------
function HoverboardService:GiveDefaultHoverboard(player)
	local saved = PlayerDataHandler:GetEquippedHoverboard(player)
	local config = Hoverboards.GetConfig(saved)

	if not config then
		saved = DEFAULT_BOARD
		config = Hoverboards.GetConfig(DEFAULT_BOARD)
	end

	print("Giving hoverboard to:", player.Name, "→", saved)

	playerHoverboards[player.UserId] = { Name = saved, Config = config }

	self.Client.EquipHoverboard:Fire(player, saved, config)
	self:SpawnHoverboard(player, saved)
	
	
	
	-- OLD CODE USING DATA STORE
	---- Only set default if no record exists (so we don't overwrite purchased choices)
	--if playerHoverboards[player.UserId] and playerHoverboards[player.UserId].Name then
	--	-- already have a hoverboard stored
	--	return
	--end

	--local boardConfig = Hoverboards.GetConfig(DEFAULT_BOARD)
	--if not boardConfig then
	--	warn("[HoverboardService] Could not find config for: " .. DEFAULT_BOARD)
	--	return
	--end

	--print("Giving default hoverboard to player:", player.Name)

	--playerHoverboards[player.UserId] = {
	--	Name = DEFAULT_BOARD,
	--	Config = boardConfig,
	--}

	---- Notify only this player (client will wait for server-cloned Hoverboard)
	--self.Client.EquipHoverboard:Fire(player, DEFAULT_BOARD, boardConfig)

	---- Also notify other players to spawn visuals if they want
	--for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
	--	if otherPlayer ~= player then
	--		self.Client.SpawnOtherHoverboard:Fire(otherPlayer, player, DEFAULT_BOARD)
	--	end
	--end

	---- Spawn server-side model immediately
	--self:SpawnHoverboard(player, DEFAULT_BOARD)
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
	CleanupCharacterHoverboard(character)

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
	local offset = CalculateBoardOffset(character, newBoard)

	-- Position the board primary part relative to HRP so Motor6D can weld exactly
	primary.CFrame = hrp.CFrame * CFrame.new(0, -offset, 0)
	print("Offset: ", offset)

	-- Create Motor6D (server-owned) between HRP and board primary for exact visuals
	local motor = Instance.new("Motor6D")
	motor.Name = "HoverboardMotor"
	motor.Part0 = hrp
	motor.Part1 = primary
	motor.C0 = CFrame.new(0, -offset, 0)
	motor.Parent = hrp

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
	CleanupCharacterHoverboard(character)
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
	
	PlayerDataHandler:SetEquippedHoverboard(player, boardName)
	
	HoverboardService:RemoveHoverboard(player)
	HoverboardService:SpawnHoverboard(player, boardName)

	---- Inform the client's GUI or other players if you want
	--self.EquipHoverboard:Fire(player, boardName, playerHoverboards[player.UserId].Config)
	--for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
	--	if otherPlayer ~= player then
	--		self.SpawnOtherHoverboard:Fire(otherPlayer, player, boardName)
	--	end
	--end
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
	--task.wait(1)

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
	Players.PlayerAdded:Connect(function(player)
		local saved = PlayerDataHandler:GetEquippedHoverboard(player)
		playerHoverboards[player.UserId] = {
			Name = saved,
			Config = Hoverboards.GetConfig(saved),
		}
		player.CharacterAdded:Connect(function()
			self:OnCharacterAdded(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataHandler:SetEquippedHoverboard(player, playerHoverboards[player.UserId].Name)
		playerHoverboards[player.UserId] = nil
	end)
end

return HoverboardService