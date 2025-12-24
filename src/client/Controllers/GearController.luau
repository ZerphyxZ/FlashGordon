print("Loading GearController")
local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local hoverboardsData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("HoverboardData"))
local HoverboardService

-- --UI References
local gearGui
local mainFrame
local closeBtn
local BG
local boardsFrame
local hoverboadsList
local cardTemplate
local selectionFrameHoverboard
local purchaseBtn
local equipButton
local currentButton
local revolvingContainer
local hoverboardItemDetails
local itemDetailsBGImage
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
local titleLabel
local cratesFrame
local trailsFrame
local tabs
local boardsTab
local trailsTab
local cratesTab

local SELECTED_COLOR = Color3.fromRGB(107, 223, 255) -- #6bdfff
local NORMAL_COLOR = Color3.fromRGB(69, 168, 255)

local GearController = Knit.CreateController({ Name = "GearController" })

local currentBoardConfig = nil
local equippedBoard = nil

local TAB_CONFIG = {}

local function SetButtonState(state)
	purchaseBtn.Visible = state == "Purchase"
	equipButton.Visible = state == "Equip"
	currentButton.Visible = state == "Current"
end

local function CloseGearGui()
	gearGui.Enabled = false
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
		else
			frame.Visible = false
		end
	end
end

local function UpdateSelectionStats(boardName, data)
	titleLabel.Text = boardName

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
		SetButtonState("Current")
		return
	end

	HoverboardService:PlayerOwnsHoverboard(boardName)
		:andThen(function(owns)
			print("Owns:", owns)

			if owns then
				print("Owns true")
				if equippedBoard == boardName then
					SetButtonState("Current")
				else
					SetButtonState("Equip")
				end
			else
				print("Owns false")
				SetButtonState("Purchase")
			end
		end)
		:catch(function(err)
			warn("PlayerOwnsHoverboard failed:", err)
			SetButtonState("Purchase")
		end)
end

-------------------------
-- POPULATE UI CARDS
-------------------------
local function PopulateHoverboards()
	-- cleanup previous items except template
	for _, child in ipairs(hoverboadsList:GetChildren()) do
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
			card.Parent = hoverboadsList
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
	SetButtonState("Current")
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
		SetButtonState("Equip")
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
	equipButton.MouseButton1Click:Connect(function()
		if currentBoardConfig then
			print("Current config:", currentBoardConfig)
			EquipHoverboard(currentBoardConfig)
			--CloseGearGui()
		end
	end)
	purchaseBtn.MouseButton1Click:Connect(function()
		PurchaseHoverboard()
	end)
	BindTabs()
end

local function CleanStates()
	-- Reset selection state
	currentBoardConfig = nil
	equippedBoard = nil

	-- Reset buttons
	SetButtonState("Purchase")

	-- Clear item details
	titleLabel.Text = ""

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

	gearGui = nil
	mainFrame = nil
	closeBtn = nil
	BG = nil
	boardsFrame = nil
	hoverboadsList = nil
	cardTemplate = nil
	selectionFrameHoverboard = nil
	TAB_CONFIG = {}
end

local function UIReferences()
	local playerGui = player:WaitForChild("PlayerGui")

	gearGui = playerGui:WaitForChild("Gear")
	mainFrame = gearGui:WaitForChild("MainFrame")
	closeBtn = mainFrame:WaitForChild("Close"):WaitForChild("Button")

	BG = mainFrame:WaitForChild("BG")

	-- Boards
	boardsFrame = BG:WaitForChild("HoverboardsFrame")
	hoverboadsList = boardsFrame:WaitForChild("Hoverboards")
	cardTemplate = BG:WaitForChild("CardTemplate")

	selectionFrameHoverboard = boardsFrame:WaitForChild("SelectionFrame")

	-- Purchase buttons
	local purchaseFrame = selectionFrameHoverboard:WaitForChild("PurchaseFrame")

	purchaseBtn = purchaseFrame:WaitForChild("PurchaseButton")
	equipButton = purchaseFrame:WaitForChild("EquipButton")
	currentButton = purchaseFrame:WaitForChild("CurrentButton")

	-- Item details
	revolvingContainer = selectionFrameHoverboard:WaitForChild("RevolvingContainer")
	hoverboardItemDetails = selectionFrameHoverboard:WaitForChild("ItemDetails")
	itemDetailsBGImage = hoverboardItemDetails:WaitForChild("BGImage")

	-- Top Speed
	topSpeed = itemDetailsBGImage:WaitForChild("TopSpeed")
	topSpeedFillerBG = topSpeed:WaitForChild("FillerBG")
	topSpeedFiller = topSpeedFillerBG:WaitForChild("Filler")
	topSpeedTitle = topSpeed:WaitForChild("Title")
	topSpeedValue = topSpeed:WaitForChild("Value")

	-- Acceleration
	acceleration = itemDetailsBGImage:WaitForChild("Acceleration")
	accelerationFillerBG = acceleration:WaitForChild("FillerBG")
	accelerationFiller = accelerationFillerBG:WaitForChild("Filler")
	accelerationTitle = acceleration:WaitForChild("Title")
	accelerationValue = acceleration:WaitForChild("Value")

	-- Jump Power
	jumpPower = itemDetailsBGImage:WaitForChild("JumpPower")
	jumpPowerFillerBG = jumpPower:WaitForChild("FillerBG")
	jumpPowerFiller = jumpPowerFillerBG:WaitForChild("Filler")
	jumpPowerTitle = jumpPower:WaitForChild("Title")
	jumpPowerValue = jumpPower:WaitForChild("Value")

	-- Title
	titleLabel = itemDetailsBGImage:WaitForChild("TitleLable")

	-- Other tabs
	cratesFrame = BG:WaitForChild("CratesFrame")
	trailsFrame = BG:WaitForChild("TrailsFrame")

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

function GearController:KnitStart()
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner ~= player then
			return
		end
		equippedBoard = boardName
		if equippedBoard then
			PopulateHoverboards()
			OpenTab(boardsTab)
			SelectHoverboard(equippedBoard)
		end
	end)
	OnPlayerAdded(player)
end

return GearController
