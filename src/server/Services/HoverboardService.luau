------ Server: HoverboardService.lua
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
local trailEquipped = true

local bodyVelocity
local bodyGyro

local HoverboardService = Knit.CreateService({
	Name = "HoverboardService",
	Client = {
		EquipHoverboard = Knit.CreateSignal(),
		HoverboardSpawned = Knit.CreateSignal(),
		HoverboardRemoved = Knit.CreateSignal(),
		HoverboardChanged = Knit.CreateSignal(),
		ControlSignal = Knit.CreateSignal(),
		GravitySignal = Knit.CreateSignal(),
		TrailEquipped = Knit.CreateSignal(),
		TrailUnequipped = Knit.CreateSignal(),
	},
})

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

local function InitBodyMovers(Board)
	bodyVelocity = Instance.new("BodyVelocity")
	bodyGyro = Instance.new("BodyGyro")

	bodyGyro.MaxTorque = Vector3.new(20000, 20000, 20000)
	bodyGyro.P = 10000
	bodyGyro.D = 500
	bodyGyro.Parent = Board

	bodyVelocity.MaxForce = Vector3.new(1e4, 0, 1e4)
	bodyVelocity.Parent = Board
end


function HoverboardService:SpawnHoverboard(player, boardName)
	print("Spawn hoverboard called")
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		print("No character or HumanoidRootPart found, returning")
		return
	end

	boardName = boardName or (playerHoverboards[player.UserId] and playerHoverboards[player.UserId].Name) or DEFAULT_BOARD

	local template = HoverboardModels:FindFirstChild(boardName)
	if not template then
		warn("[HoverboardService] Could not find model: " .. tostring(boardName))
		return
	end

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

	InitBodyMovers(primary)

	if hoverboard and hoverboard.PrimaryPart then
		hoverboard.PrimaryPart:SetNetworkOwner(player)
		print("Notifying all the clients of hoverboard spawn")
		--self.Client.HoverboardSpawned:FireAll(player, player, boardName)
	end
end

-- Server: remove hoverboard and constraints
function HoverboardService:RemoveHoverboard(player)
	local character = player.Character
	if not character then
		return
	end
	local motor = character:FindFirstChild("HumanoidRootPart"):FindFirstChild("HoverboardMotor")
	if motor then
		motor:Destroy()
	end
	local hoverboard = character:FindFirstChild("Hoverboard")
	if hoverboard then
		hoverboard:Destroy()
	end
	self.Client.HoverboardRemoved:Fire(player, player)
end

----------------------------------------------------------
-- Client Requestable Methods
----------------------------------------------------------

----------------------------------------------------------
-- Hoverboards (Client APIs)
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
		HoverboardService.Client.HoverboardChanged:Fire(player, boardName)
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

function HoverboardService.Client:RequestGravityCoil(player)
	-- Validate if player owns the gravity coil product
	local playerData = PlayerDataHandler:GetData(player)
	
	if not playerData then
		return false, "Player data not found"
	end
	
	-- Check if player owns the gravity coil (you need to implement this check based on your data structure)
	local hasCoil = PlayerDataHandler:PlayerHasGravityCoil(player) -- You'll need to create this function
	
	if not hasCoil then
		return false, "You don't own the Gravity Coil"
	end
	
	-- Notify client to enable gravity coil
	-- You'll need to add this signal to the service
	print("Firing gravity signal")
	self.GravitySignal:Fire(player, true)
	
	return true, "Gravity Coil activated"
end

function HoverboardService.Client:PlayerOwnsHoverboard(player, boardName)
	if PlayerDataHandler:PlayerOwnsHoverboard(player, boardName) then
		return true
	end
	return false
end

function HoverboardService.Client:GetEquippedHoverboard(player)
	return PlayerDataHandler:GetEquippedHoverboard(player)
end

function HoverboardService.Client:PurchaseHoverboard(player, boardName, price, currencyType)
	print("PurchaseHoverboard called:", player.Name, boardName, price, currencyType)
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
-- Trails (Client APIs)
----------------------------------------------------------
function HoverboardService.Client:PlayerOwnsTrail(player, trailName)
	return PlayerDataHandler:PlayerOwnsTrail(player, trailName)
end

function HoverboardService.Client:PurchaseTrail(player, trailName, price, currencyType)
	local data = PlayerDataHandler:GetData(player)
	if not data then return false end

	if PlayerDataHandler:PlayerOwnsTrail(player, trailName) then
		print("Player already owns this trail")
		return false
	end

	if currencyType == "Coins" then
		if data.Coins < price then
			print("Insufficient coins to purchase trail")
			return false
		end
		PlayerDataHandler:DeductCoins(player, price)
		print("Deducted", price, "coins from", player.Name)
	end

	return PlayerDataHandler:AddTrailToInventory(player, trailName)
end

function HoverboardService.Client:EquipTrail(player, trailName)
	PlayerDataHandler:SetEquippedTrail(player, trailName)
	self.TrailEquipped:Fire(player, trailName)
	return true
end

function HoverboardService.Client:UnequipTrail(player)
	PlayerDataHandler:SetEquippedTrail(player, nil)
	self.TrailUnequipped:Fire(player)
	return true
end

function HoverboardService.Client:GetEquippedTrail(player)
	return PlayerDataHandler:GetEquippedTrail(player)
end


----------------------------------------------------------
-- Crates (Client APIs)
----------------------------------------------------------
function HoverboardService.Client:PlayerOwnsCrate(player, crateName)
	return PlayerDataHandler:PlayerOwnsCrate(player, crateName)
end

function HoverboardService.Client:PurchaseCrate(player, crateName, price, currencyType)
	local data = PlayerDataHandler:GetData(player)
	if not data then print("HoverboardService:PurchaseCrate failed") return false end

	if currencyType == "Coins" then
		if data.Coins < price then
			print("Insufficient coins to purchase crate")
			return false
		end
		PlayerDataHandler:DeductCoins(player, price)
		print("Deducted", price, "coins from", player.Name)
	end

	return PlayerDataHandler:AddCrateToInventory(player, crateName)
end

function HoverboardService.Client:EquipCrate(player, crateName)
	PlayerDataHandler:SetEquippedCrate(player, crateName)
	return true
end

function HoverboardService.Client:UnequipCrate(player)
	PlayerDataHandler:SetEquippedCrate(player, nil)
	return true
end

function HoverboardService.Client:GetEquippedCrate(player)
	return PlayerDataHandler:GetEquippedCrate(player)
end

function HoverboardService.Client:GetOwnedCrates(player)
	return PlayerDataHandler:GetOwnedCrates(player)
end


----------------------------------------------------------
-- Hoverboard Store/Purchase Methods
----------------------------------------------------------


----------------------------------------------------------
-- Character Setup
----------------------------------------------------------
function HoverboardService:OnCharacterAdded(player)
	print("OnCharacterAdded called for:", player.Name)
	
	-- Immediately disable controls while we set up
	self.Client.ControlSignal:Fire(player, "Disable")
	
	-- Give default board immediately for immediate visual feedback
	print("Giving immediate default hoverboard for:", player.Name)
	playerHoverboards[player.UserId] = {
		Name = DEFAULT_BOARD,
		Config = Hoverboards.GetConfig(DEFAULT_BOARD),
	}
	self:SpawnHoverboard(player, DEFAULT_BOARD)
	
	-- Enable controls temporarily with default board
	self.Client.ControlSignal:Fire(player, "Enable")
	
	-- Now wait for profile to load in the background
	task.spawn(function()
		local maxWaitTime = 10
		local startTime = os.time()
		local profileLoaded = false
		
		-- Wait for profile to load
		while not PlayerDataHandler:GetProfile(player) and (os.time() - startTime) < maxWaitTime do
			task.wait(0.1)
		end
		
		-- Check if profile was successfully loaded
		local profile = PlayerDataHandler:GetProfile(player)
		if not profile then
			warn("[HoverboardService] Could not load profile for", player.Name, "within timeout period")
			-- Keep using default board
			return
		end
		
		profileLoaded = true
		
		-- Get equipped hoverboard from loaded profile
		local saved = PlayerDataHandler:GetEquippedHoverboard(player)
		print("Profile loaded, equipped hoverboard:", player.Name, "→", saved)
		
		-- If player has a saved board and it's different from default, switch to it
		if saved and saved ~= "" and saved ~= DEFAULT_BOARD then
			-- Check if player owns this hoverboard
			if PlayerDataHandler:PlayerOwnsHoverboard(player, saved) then
				print("Switching to saved hoverboard:", saved)
				
				-- Update memory cache
				playerHoverboards[player.UserId] = {
					Name = saved,
					Config = Hoverboards.GetConfig(saved),
				}
				
				-- Remove current board and spawn saved one
				self:RemoveHoverboard(player)
				self:SpawnHoverboard(player, saved)

				self.Client.HoverboardSpawned:Fire(player, saved)
				
				print("Successfully switched to saved hoverboard for", player.Name)
			else
				warn("Player doesn't own saved hoverboard:", saved, "keeping default")
			end
		elseif not saved or saved == "" then
			-- Player has no saved board, give default and save it
			print("Player has no hoverboard, saving default.")
			PlayerDataHandler:SetEquippedHoverboard(player, DEFAULT_BOARD)
			
			-- Update memory cache
			playerHoverboards[player.UserId] = {
				Name = DEFAULT_BOARD,
				Config = Hoverboards.GetConfig(DEFAULT_BOARD),
			}
		end
	end)











	-- self.Client.ControlSignal:Fire(player, "Disable")

	-- local saved = PlayerDataHandler:GetEquippedHoverboard(player)
	-- print("Player joined:", player.Name, "Equipped hoverboard:", saved)
	-- playerHoverboards[player.UserId] = {
	-- 	Name = saved,
	-- 	Config = Hoverboards.GetConfig(saved),
	-- }

	-- -- If player has no stored hoverboard, give default. Otherwise spawn stored board.
	-- if not playerHoverboards[player.UserId] or not playerHoverboards[player.UserId].Name then
	-- 	print("Player has no hoverboard, giving default.")
	-- 	self:GiveDefaultHoverboard(player)
	-- else
	-- 	-- spawn the stored board (will also create constraints)
	-- 	print("Spawning stored hoverboard for player.")
	-- 	local storedName = playerHoverboards[player.UserId].Name
	-- 	self:SpawnHoverboard(player, storedName)
	-- end

	-- task.wait(0.3)
	-- self.Client.ControlSignal:Fire(player, "Enable")
end

----------------------------------------------------------
-- Player Handling
----------------------------------------------------------
function HoverboardService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			self:OnCharacterAdded(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
	end)
end

return HoverboardService