-- Server: HoverboardService.lua
local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local ReplicatedStorage = Global.ReplicatedStorage
local RunService = Global.RunService
local Hoverboards = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("HoverboardData"))
local Players = Global.Players
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local HoverboardModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Hoverboards")
local DEFAULT_BOARD = "Hoverboard1" -- Fallback hoverboard model name
local playerHoverboards = {}
local hoverboard
local HoverboardPhysics, bodyVelocity, bodyPosition, bodyGyro

local HoverboardService = Knit.CreateService({
	Name = "HoverboardService",
	Client = {
		EquipHoverboard = Knit.CreateSignal(),
		HoverboardSpawned = Knit.CreateSignal(),
		HoverboardRemoved = Knit.CreateSignal(),
		SpawnOtherHoverboard = Knit.CreateSignal(),
		ControlSignal = Knit.CreateSignal(),
	},
})

-- Utility: clean up existing hoverboard and constraints on a character
local function CleanupCharacterHoverboard(character)
	if not character then
		return
	end
	-- Destroy hoverboard model if present
	local existing = character:FindFirstChild("Hoverboard")
	if existing and HoverboardPhysics then
		existing:Destroy()
		HoverboardPhysics.Cleanup(
			existing,
			existing.PrimaryPart.BodyVelocity,
			existing.PrimaryPart.BodyGyro,
			existing.PrimaryPart.BodyPosition
		)
	end
end

----------------------------------------------------------
-- Give Default Hoverboard (only if player doesn't already have one)
----------------------------------------------------------
function HoverboardService:GiveDefaultHoverboard(player)
	local equipped = PlayerDataHandler:GetEquippedHoverboard(player)
	local config = Hoverboards.GetConfig(equipped)

	if not config then
		equipped = DEFAULT_BOARD
		config = Hoverboards.GetConfig(DEFAULT_BOARD)
	end

	print("Giving hoverboard to:", player.Name, "→", equipped)

	playerHoverboards[player.UserId] = { Name = equipped, Config = config }

	self.Client.EquipHoverboard:Fire(player, equipped, config)
	self:SpawnHoverboard(player, equipped)
end

----------------------------------------------------------
-- Server: spawn hoverboard for a player's character (server clones model + creates constraints)
-- Uses feet for placement and respects stored hoverboard choice
----------------------------------------------------------
function HoverboardService:SpawnHoverboard(player, boardName)
	print("Spawn hoverboard called")
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	boardName = boardName
		or (playerHoverboards[player.UserId] and playerHoverboards[player.UserId].Name)
		or DEFAULT_BOARD

	-- Clean up any old hoverboard and constraints
	--CleanupCharacterHoverboard(character)

	local template = HoverboardModels:FindFirstChild(boardName)
	if not template then
		warn("[HoverboardService] Could not find model: " .. tostring(boardName))
		return
	end

	-- CRITICAL: Temporarily disable physics on character to prevent falling
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character.HumanoidRootPart

	-- Clone into the character
	local newBoard = template:Clone()
	newBoard.Name = "Hoverboard"
	newBoard.Parent = character
	hoverboard = newBoard

	-- Ensure primary part exists
	local primary = hoverboard.PrimaryPart or hoverboard:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("[HoverboardService] Hoverboard model has no PrimaryPart:", boardName)
		-- still parented, but can't proceed with constraints
		return
	end

	local heightOffset = humanoid.HipHeight + hrp.Size.Y / 2
	primary.CFrame = hrp.CFrame * CFrame.Angles(0, 0, 0) - Vector3.new(0, heightOffset, 0)

	-- Create Motor6D (server-owned) between HRP and board primary for exact visuals
	local motor = Instance.new("Motor6D")
	motor.Name = "HoverboardMotor"
	motor.Part0 = hrp
	motor.Part1 = primary
	motor.C0 = CFrame.new(0, -heightOffset, 0)
	motor.Parent = hrp

	if HoverboardPhysics and hoverboard and hoverboard.PrimaryPart then
		local bodyVelocity, bodyGyro, bodyPosition = HoverboardPhysics.AttachPhysics(hoverboard, hrp)
		hoverboard:SetAttribute("HasPhysics", true)
		hoverboard.PrimaryPart:SetNetworkOwner(player)

		if bodyPosition then
			local currentPos = primary.Position
			bodyPosition.Position = Vector3.new(currentPos.X, currentPos.Y, currentPos.Z)
			bodyPosition.MaxForce = Vector3.new(0, HoverboardPhysics.MAX_BODY_FORCE, 0)
		end

		-- Notify all clients that hoverboard spawned
		self.Client.HoverboardSpawned:FireAll(player, player, boardName)
	end
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
		print("returning from RequestEquipHoverboard")
		return
	end

	-- Check if player owns this hoverboard
	if not PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
		warn("Player does not own this hoverboard")
		return
	end

	local template = HoverboardModels:FindFirstChild(boardName)
	if not template then
		warn("[HoverboardService] Unknown board requested:", tostring(boardName))
		return
	end

	print("RequestEquipHoverboard called.")

	-- Update stored config (so spawn on next join will use this)
	playerHoverboards[player.UserId] = {
		Name = boardName,
		Config = Hoverboards.GetConfig(boardName),
	}

	local success = PlayerDataHandler:SetEquippedHoverboard(player, boardName)
	if success then
		HoverboardService:RemoveHoverboard(player)
		HoverboardService:SpawnHoverboard(player, boardName)
		print("Hoverboad equipped successfully.")
	else
		print("Failed to equip hoverboard.")
		return
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
-- Hoverboard Store/Purchase Methods
----------------------------------------------------------
function HoverboardService.Client:PurchaseHoverboard(player, boardName, price, currencyType)
	-- currencyType: "Coins" or "Robux"
	local playerData = PlayerDataHandler:GetData(player)

	if not playerData then
		return false, "Player data not found"
	end

	-- Check if already owned
	if PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
		return false, "Already owned"
	end

	-- Check if valid hoverboard
	local config = Hoverboards.GetConfig(boardName)
	if not config then
		return false, "Invalid hoverboard"
	end

	-- Process payment
	if currencyType == "Coins" then
		if playerData.Coins < price then
			return false, "Insufficient coins"
		end
		PlayerDataHandler:DeductCoins(player, price)
	elseif currencyType == "Robux" then
		-- Implement Robux purchase logic here
		-- This would typically use MarketplaceService
		return false, "Robux purchases not implemented yet"
	else
		return false, "Invalid currency type"
	end

	-- Add to inventory
	local success = PlayerDataHandler:AddHoverboardToInventory(player, boardName)
	if success then
		print("[HoverboardService] Purchased hoverboard:", player.Name, boardName, price, currencyType)
		return true, "Purchase successful"
	else
		-- Refund if failed to add to inventory
		if currencyType == "Coins" then
			PlayerDataHandler:IncrementCoins(player, price)
		end
		return false, "Purchase failed"
	end
end

----------------------------------------------------------
-- Get player's hoverboard inventory
----------------------------------------------------------
function HoverboardService.Client:GetHoverboardInventory(player)
	local owned = PlayerDataHandler:GetOwnedHoverboards(player)
	local equipped = PlayerDataHandler:GetEquippedHoverboard(player)
	local total = PlayerDataHandler:GetTotalHoverboards()

	return {
		OwnedHoverboards = owned,
		EquippedHoverboard = equipped,
		TotalHoverboards = total,
		AvailableHoverboards = total - #owned,
	}
end

----------------------------------------------------------
-- Character Setup
----------------------------------------------------------
local function HandleCharacterDeath(player)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not character then
		return
	end

	humanoid.BreakJointsOnDeath = false

	-- Prevent default death behavior
	humanoid.Died:Connect(function()
		print("Character would die, making invisible instead: ", player.Name)

		-- Make all character parts invisible & non-collidable
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			elseif part:IsA("Decal") or part:IsA("SurfaceGui") then
				--part.Transparency = 1
				--part.Visible = false
				--part.CanCollide = false
			end
		end

		-- Make hoverboard invisible & non-collidable
		local hoverboard = character:FindFirstChild("Hoverboard")
		if hoverboard then
			for _, part in ipairs(hoverboard:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.CanCollide = false
				end
			end
		end
	end)
end

function HoverboardService:OnCharacterAdded(player)
	self.Client.ControlSignal:Fire(player, "Disable")

	-- slight delay to ensure character parts exist
	--task.wait(3)

	-- If player has no stored hoverboard, give default. Otherwise spawn stored board.
	if not playerHoverboards[player.UserId] or not playerHoverboards[player.UserId].Name then
		self:GiveDefaultHoverboard(player)
	else
		-- spawn the stored board (will also create constraints)
		local storedName = playerHoverboards[player.UserId].Name
		self:SpawnHoverboard(player, storedName)
	end

	task.wait(0.3)
	self.Client.ControlSignal:Fire(player, "Enable")
end

----------------------------------------------------------
-- Player Handling
----------------------------------------------------------
function HoverboardService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		HoverboardPhysics = require(ReplicatedStorage.Shared.Modules.Hoverboard.HoverboardPhysics)
		local saved = PlayerDataHandler:GetEquippedHoverboard(player)
		playerHoverboards[player.UserId] = {
			Name = saved,
			Config = Hoverboards.GetConfig(saved),
		}
		player.CharacterAdded:Connect(function()
			print("character added even called from this")
			HandleCharacterDeath(player)
			self:OnCharacterAdded(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataHandler:SetEquippedHoverboard(player, playerHoverboards[player.UserId].Name)
		playerHoverboards[player.UserId] = nil
	end)
end

return HoverboardService
