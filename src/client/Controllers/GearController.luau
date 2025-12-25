print("Loading GearController")
local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local hoverboardsData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("HoverboardData"))
local trailData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("TrailsConfig"))
local HoverboardService

--UI References

--COMMON REFERENCES
local Gear
local mainFrame
local closeBtn
local BG
local cardTemplate

--BOARDS SECTION
local boardsFrame
local boardsList
local boardSelectionFrame
local boardPurchaseBtn
local boardEquipButton
local boardCurrentButton
local revolvingContainer
local boardItemDetails
local boardDetailsFrame
local topSpeed
local topSpeedFillerBG
local topSpeedFiller
local topSpeedTitle
local topSpeedValue
local acceleration
local accelerationFillerBG
local accelerationFiller
local accelerationTitle
local accelerationValue
local jumpPower
local jumpPowerFillerBG
local jumpPowerFiller
local jumpPowerTitle
local jumpPowerValue
local boardItemDetailsTitleLabel

--CRATES SECTION
local cratesFrame

--TRAILS SECTION
local trailsFrame
local trailsList
local trailSelectionFrame
local trailItemDetails
local trailsItemDetailsBGImage
local trailItemDetailsTitleLabel
local trailItemDetailsDescriptionLabel
local trailPurchaseButton
local trailEquipButton
local trailUnequipButton

--TABS SECTION
local tabs
local boardsTab
local trailsTab
local cratesTab

local SELECTED_COLOR = Color3.fromRGB(107, 223, 255) -- #6bdfff
local NORMAL_COLOR = Color3.fromRGB(69, 168, 255)

local GearController = Knit.CreateController({ Name = "GearController" })

local currentBoardConfig = nil
local equippedBoard = nil

local currentTrailConfig = nil
local equippedTrail = nil

local TAB_CONFIG = {}

----------------- BOARDS FUNCTIONS ---------------------
local function SetBoardButtonState(state)
	boardPurchaseBtn.Visible = state == "Purchase"
	boardEquipButton.Visible = state == "Equip"
	boardCurrentButton.Visible = state == "Current"
end

local function UpdateSelectionStats(boardName, data)
	boardItemDetailsTitleLabel.Text = boardName

	-- Values
	accelerationValue.Text = tostring(data.Acceleration)
	topSpeedValue.Text = tostring(data.TopSpeed)
	jumpPowerValue.Text = tostring(data.JumpPower)

	-- -- Fillers
	topSpeedFiller.Size = UDim2.new(data.TopSpeed / 100, 0, 1, 0)
	accelerationFiller.Size = UDim2.new(data.Acceleration / 2, 0, 1, 0)
	jumpPowerFiller.Size = UDim2.new(data.JumpPower / 100, 0, 1, 0)
end

local function SelectHoverboard(boardName)
	local data = hoverboardsData[boardName]
	if not data then
		return
	end

	currentBoardConfig = boardName
	UpdateSelectionStats(boardName, data)

	if equippedBoard == boardName then
		SetBoardButtonState("Current")
		return
	end

	HoverboardService:PlayerOwnsHoverboard(boardName)
		:andThen(function(owns)
			print("Owns:", owns)

			if owns then
				print("Owns true")
				if equippedBoard == boardName then
					SetBoardButtonState("Current")
				else
					SetBoardButtonState("Equip")
				end
			else
				print("Owns false")
				SetBoardButtonState("Purchase")
			end
		end)
		:catch(function(err)
			warn("PlayerOwnsHoverboard failed:", err)
			SetBoardButtonState("Purchase")
		end)
end

local function PopulateHoverboards()
	-- cleanup previous items except template
	for _, child in ipairs(boardsList:GetChildren()) do
		if child:GetAttribute("HoverboardCard") then
			child:Destroy()
		end
		-- if child:IsA("Frame") and child.Name ~= "CardTemplate" then
		-- 	child:Destroy()
		-- end
	end

	for boardName, data in pairs(hoverboardsData) do
		if typeof(data) == "table" then
			local card = cardTemplate:Clone()
			card.Name = boardName
			card.Visible = true
			card.Parent = boardsList
			card:SetAttribute("HoverboardCard", true)

			-- Fill card UI
			card:WaitForChild("Title").Text = tostring(boardName)
			card:WaitForChild("Price").Text = tostring(data.Price)

			card.MouseButton1Click:Connect(function()
				SelectHoverboard(boardName)
			end)
		end
	end
end

local function EquipHoverboard(boardName)
	if not currentBoardConfig then
		return
	end
	HoverboardService:RequestEquipHoverboard(currentBoardConfig)
	equippedBoard = currentBoardConfig
	SetBoardButtonState("Current")
end

local function PurchaseHoverboard()
	if not currentBoardConfig then
		return
	end

	local boardData = hoverboardsData[currentBoardConfig]
	if not boardData then
		print("Board data not found for", currentBoardConfig)
		return
	end

	local success, message =
		HoverboardService:PurchaseHoverboard(currentBoardConfig, boardData.Price, boardData.Currency)
	if success then
		SetBoardButtonState("Equip")
	end
end
--------------------------------------------------------

----------------- TRAILS FUNCTIONS ---------------------
local function SetTrailButtonState(state)
	trailPurchaseButton.Visible = state == "Purchase"
	trailEquipButton.Visible = state == "Equip"
	trailUnequipButton.Visible = state == "Unequip"
end

local function SelectTrail(trailName)
	local data = trailData[trailName]
	if not data then
		return
	end

	currentTrailConfig = trailName

	trailItemDetailsTitleLabel.Text = data.Name
	trailItemDetailsDescriptionLabel.Text = data.Description

	if equippedTrail == trailName then
		SetTrailButtonState("Unequip")
		return
	end

	HoverboardService:PlayerOwnsTrail(trailName)
		:andThen(function(owns)
			if owns then
				SetTrailButtonState("Equip")
			else
				SetTrailButtonState("Purchase")
			end
		end)
		:catch(function()
			SetTrailButtonState("Purchase")
		end)
end

local function PopulateTrails()
	for _, child in ipairs(trailsList:GetChildren()) do
		if child:GetAttribute("TrailCard") then
			child:Destroy()
		end
	end

	for trailName, data in pairs(trailData) do
		if typeof(data) == "table" then
			local card = cardTemplate:Clone()
			card.Name = trailName
			card.Visible = true
			card.Parent = trailsList
			card:SetAttribute("TrailCard", true)

			card:WaitForChild("Title").Text = data.Name
			card:WaitForChild("Price").Text = tostring(data.Price)

			card.MouseButton1Click:Connect(function()
				SelectTrail(trailName)
			end)
		end
	end
end

local function PurchaseTrail()
	if not currentTrailConfig then
		return
	end

	local data = trailData[currentTrailConfig]
	if not data then
		return
	end

	local success = HoverboardService:PurchaseTrail(currentTrailConfig, data.Price, data.Currency)

	if success then
		SetTrailButtonState("Equip")
	end
end

local function EquipTrail()
	if not currentTrailConfig then
		return
	end

	HoverboardService:EquipTrail(currentTrailConfig)
	equippedTrail = currentTrailConfig
	print("equippedTrail", equippedTrail)
	SetTrailButtonState("Unequip")
end

local function UnequipTrail()
	HoverboardService:UnequipTrail()
	equippedTrail = nil
	SetTrailButtonState("Equip")
end

--------------------------------------------------------

-----------------  GLOBAL FUNCTIONS --------------------
local function CloseGearGui()
	Gear.Enabled = false
end

local function SetSelectedTab(selected)
	boardsTab.BackgroundColor3 = (selected == boardsTab) and SELECTED_COLOR or NORMAL_COLOR
	cratesTab.BackgroundColor3 = (selected == cratesTab) and SELECTED_COLOR or NORMAL_COLOR
	trailsTab.BackgroundColor3 = (selected == trailsTab) and SELECTED_COLOR or NORMAL_COLOR
end

local function OpenTab(selectedTab)
	for tabButton, frame in pairs(TAB_CONFIG) do
		if tabButton == selectedTab then
			frame.Visible = true
			SetSelectedTab(tabButton)

			if tabButton == trailsTab and equippedTrail then
				SelectTrail(equippedTrail)
			end
		else
			frame.Visible = false
		end
	end
end

local function BindTabs()
	for tabButton in pairs(TAB_CONFIG) do
		tabButton.MouseButton1Click:Connect(function()
			OpenTab(tabButton)
		end)
	end
end

local function BindInput()
	closeBtn.MouseButton1Click:Connect(function()
		CloseGearGui()
	end)
	boardEquipButton.MouseButton1Click:Connect(function()
		if currentBoardConfig then
			print("Current config:", currentBoardConfig)
			EquipHoverboard(currentBoardConfig)
			--CloseGearGui()
		end
	end)
	boardPurchaseBtn.MouseButton1Click:Connect(function()
		PurchaseHoverboard()
	end)
	trailPurchaseButton.MouseButton1Click:Connect(function()
		PurchaseTrail()
	end)
	trailEquipButton.MouseButton1Click:Connect(function()
		EquipTrail()
	end)
	trailUnequipButton.MouseButton1Click:Connect(function()
		UnequipTrail()
	end)

	BindTabs()
end

local function CleanStates()
	-- Reset selection state
	currentBoardConfig = nil
	equippedBoard = nil

	-- Reset buttons
	SetBoardButtonState("Purchase")

	-- Clear item details
	boardItemDetailsTitleLabel.Text = ""

	accelerationValue.Text = "0"
	topSpeedValue.Text = "0"
	jumpPowerValue.Text = "0"

	accelerationFiller.Size = UDim2.new(0, 0, 1, 0)
	topSpeedFiller.Size = UDim2.new(0, 0, 1, 0)
	jumpPowerFiller.Size = UDim2.new(0, 0, 1, 0)

	-- Reset tabs visibility
	boardsFrame.Visible = false
	cratesFrame.Visible = false
	trailsFrame.Visible = false

	-- Optional: reset tab colors
	boardsTab.BackgroundColor3 = NORMAL_COLOR
	cratesTab.BackgroundColor3 = NORMAL_COLOR
	trailsTab.BackgroundColor3 = NORMAL_COLOR

	Gear = nil
	mainFrame = nil
	closeBtn = nil
	BG = nil
	boardsFrame = nil
	boardsList = nil
	cardTemplate = nil
	boardSelectionFrame = nil

	currentTrailConfig = nil
	equippedTrail = nil
	SetTrailButtonState("Purchase")

	trailItemDetailsTitleLabel.Text = ""
	trailItemDetailsDescriptionLabel.Text = ""
	TAB_CONFIG = {}
end

local function UIReferences()
	local playerGui = player:WaitForChild("PlayerGui")

	Gear = playerGui:WaitForChild("Gear")
	mainFrame = Gear:WaitForChild("MainFrame")
	closeBtn = mainFrame:WaitForChild("Close"):WaitForChild("Button")
	BG = mainFrame:WaitForChild("BG")
	cardTemplate = BG:WaitForChild("CardTemplate")

	--BOARDS SECTION
	boardsFrame = BG:WaitForChild("HoverboardsFrame")
	boardsList = boardsFrame:WaitForChild("Hoverboards")
	boardSelectionFrame = boardsFrame:WaitForChild("SelectionFrame")
	local purchaseFrame = boardSelectionFrame:WaitForChild("PurchaseFrame")
	boardPurchaseBtn = purchaseFrame:WaitForChild("PurchaseButton")
	boardEquipButton = purchaseFrame:WaitForChild("EquipButton")
	boardCurrentButton = purchaseFrame:WaitForChild("CurrentButton")
	revolvingContainer = boardSelectionFrame:WaitForChild("RevolvingContainer")
	boardItemDetails = boardSelectionFrame:WaitForChild("ItemDetails")
	boardDetailsFrame = boardItemDetails:WaitForChild("DetailsFrame")
	topSpeed = boardDetailsFrame:WaitForChild("TopSpeed")
	topSpeedFillerBG = topSpeed:WaitForChild("FillerBG")
	topSpeedFiller = topSpeedFillerBG:WaitForChild("Filler")
	topSpeedTitle = topSpeed:WaitForChild("Title")
	topSpeedValue = topSpeed:WaitForChild("Value")
	acceleration = boardDetailsFrame:WaitForChild("Acceleration")
	accelerationFillerBG = acceleration:WaitForChild("FillerBG")
	accelerationFiller = accelerationFillerBG:WaitForChild("Filler")
	accelerationTitle = acceleration:WaitForChild("Title")
	accelerationValue = acceleration:WaitForChild("Value")
	jumpPower = boardDetailsFrame:WaitForChild("JumpPower")
	jumpPowerFillerBG = jumpPower:WaitForChild("FillerBG")
	jumpPowerFiller = jumpPowerFillerBG:WaitForChild("Filler")
	jumpPowerTitle = jumpPower:WaitForChild("Title")
	jumpPowerValue = jumpPower:WaitForChild("Value")
	boardItemDetailsTitleLabel = boardItemDetails:WaitForChild("TitleLable")

	--CRATES SECTION
	cratesFrame = BG:WaitForChild("CratesFrame")

	--TRAILS SECTION
	trailsFrame = BG:WaitForChild("TrailsFrame")
	trailsList = trailsFrame:WaitForChild("TrailsList")
	trailSelectionFrame = trailsFrame:WaitForChild("SelectionFrame")
	trailItemDetails = trailSelectionFrame:WaitForChild("ItemDetails")
	trailItemDetailsTitleLabel = trailItemDetails:WaitForChild("Name")
	local frame = trailItemDetails:WaitForChild("Frame")
	trailItemDetailsDescriptionLabel = frame:WaitForChild("Description")

	local trailPurchaseFrame = trailSelectionFrame:WaitForChild("PurchaseFrame")
	trailPurchaseButton = trailPurchaseFrame:WaitForChild("PurchaseButton")
	trailEquipButton = trailPurchaseFrame:WaitForChild("EquipButton")
	trailUnequipButton = trailPurchaseFrame:WaitForChild("UnequipButton")

	--TABS SECTION
	tabs = BG:WaitForChild("Tabs")
	boardsTab = tabs:WaitForChild("BoardsButton")
	trailsTab = tabs:WaitForChild("TrailsButton")
	cratesTab = tabs:WaitForChild("CratesButton")

	TAB_CONFIG = {
		[boardsTab] = boardsFrame,
		[cratesTab] = cratesFrame,
		[trailsTab] = trailsFrame,
	}
	print("UI references rebuilt on character spawn")
end
--------------------------------------------------------

----------------- CHARACTER LIFECYCLE ------------------
local function OnCharacterAdded(char)
	UIReferences()
	BindInput()
end

local function OnCharacterRemoving()
	CleanStates()
end

local function OnPlayerAdded(plr)
	print("GearController: OnPlayerAdded called for", plr.Name)
	plr.CharacterAdded:Connect(function()
		OnCharacterAdded(plr.Character)
	end)
	plr.CharacterRemoving:Connect(function()
		OnCharacterRemoving()
	end)
	if plr.Character then
		OnCharacterAdded(plr.Character)
	end
end

function GearController:Enable(Enabled)
	Gear.Enabled = Enabled
end

function GearController:KnitStart()
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner ~= player then
			return
		end
		equippedBoard = boardName
		HoverboardService:GetEquippedTrail():andThen(function(trailName)
			equippedTrail = trailName
		end)
		if equippedBoard then
			PopulateHoverboards()
			PopulateTrails()
			OpenTab(boardsTab)
			SelectHoverboard(equippedBoard)
		end
	end)
	OnPlayerAdded(player)
end

return GearController
