local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))

local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local hoverboardsData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("HoverboardData"))
local trailData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("TrailsConfig"))
local cratesData = require(ReplicatedStorage:WaitForChild("Configuration"):WaitForChild("CratesConfig"))
local HoverboardService
local GearService
local RobuxReceiptService
local CoinsController

local character
local hoverboard

-- UI References

-- COMMON REFERENCES
local Gear
local mainFrame
local closeBtn
local Contents
local cardTemplate
local overlay

-- BOARDS SECTION
local boardsFrame
local boardsList
local boardSelectionFrame
local purchaseFrame
local boardPurchaseBtn
local boardEquipButton
local boardCurrentButton
local revolvingContainer
local boardItemDetails
local boardItemDetailsBGImage
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

-- CRATES SECTION
local cratesFrame
local cratesList
local crateScrollingItemTemplate
local crateScrollingItemImage
local crateScrollingItemPercentageLabel
local crateSelectionFrame
local crateSelectionInnerFrame
local crateSelectionItemImage
local crateSelectionItemNameLabel
local crateItemsScrollingFrame
local cratesBoardListScrollingFrame
local cratesBoardListScrollingFrameParent
local scrollingBoardItemTemplate
local arrow
local winningBoardFrame
local winningBoardImage
local winningBoardNameLabel
local winningBoardFrameShine

-- Purchase buttons
local cratePurchaseFrame
local cratePurchaseButton

-- TRAILS SECTION
local trailsFrame
local trailsList
local trailSelectionFrame
local trailSelectionInnerFrame
local trailPurchaseFrame
local trailItemDetails
local trailItemDetailsTitleLabel
local trailItemDetailsDescriptionLabel
local trailPurchaseButton
local trailEquipButton
local trailUnequipButton

-- TABS SECTION
local tabs
local boardsTab
local trailsTab
local cratesTab
local statusMessage

-- local SELECTED_COLOR = Color3.fromRGB(107, 223, 255) -- #6bdfff
-- local NORMAL_COLOR = Color3.fromRGB(69, 168, 255)

local currentBoardConfig = nil
local equippedBoard = nil
local currentTrailConfig = nil
local equippedTrail = nil
local currentCrateConfig = nil
local equippedCrate = nil
local TAB_CONFIG = {}

local WARNING_TEXT = "Something went wrong!"
local RED_COLOR = Color3.fromRGB(255, 0, 0)
local GREEN_COLOR = Color3.fromRGB(0, 255, 0)
local YELLOW_COLOR = Color3.fromRGB(255, 255, 0)

local GearController = Knit.CreateController({
    Name = "GearController"
})

local FILL_TWEEN_INFO = TweenInfo.new(0.2, -- duration
Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function TweenFiller(filler, targetScale)
    if not filler then
        return
    end

    local tween = TweenService:Create(filler, FILL_TWEEN_INFO, {
        Size = UDim2.new(targetScale, 0, 1, 0)
    })

    tween:Play()
end

local function UIReferences()
    local playerGui = player:WaitForChild("PlayerGui")

    Gear = playerGui:WaitForChild("Gear")
    mainFrame = Gear:WaitForChild("MainFrame")
    closeBtn = mainFrame:WaitForChild("Close")
    Contents = mainFrame:WaitForChild("Contents")
    cardTemplate = Contents:WaitForChild("CardTemplate")
    overlay = Gear:WaitForChild("Overlay")

    -- BOARDS SECTION
    boardsFrame = Contents:WaitForChild("HoverboardsFrame")
    boardsList = boardsFrame:WaitForChild("Hoverboards")
    boardSelectionFrame = boardsFrame:WaitForChild("SelectionFrame")
    purchaseFrame = boardSelectionFrame:WaitForChild("Contents"):WaitForChild("PurchaseFrame")
    boardPurchaseBtn = purchaseFrame:WaitForChild("PurchaseButton")
    boardEquipButton = purchaseFrame:WaitForChild("EquipButton")
    boardCurrentButton = purchaseFrame:WaitForChild("CurrentButton")
    revolvingContainer = boardSelectionFrame:WaitForChild("Contents"):WaitForChild("RevolvingContainer")
    boardItemDetails = boardSelectionFrame:WaitForChild("Contents"):WaitForChild("ItemDetails")
    -- boardItemDetailsBGImage = boardItemDetails:WaitForChild("BGImage")
    topSpeed = boardItemDetails:WaitForChild("TopSpeed")
    topSpeedFillerBG = topSpeed:WaitForChild("FillerBG")
    topSpeedFiller = topSpeedFillerBG:WaitForChild("Filler")
    topSpeedTitle = topSpeed:WaitForChild("Title")
    topSpeedValue = topSpeed:WaitForChild("Value")
    acceleration = boardItemDetails:WaitForChild("Acceleration")
    accelerationFillerBG = acceleration:WaitForChild("FillerBG")
    accelerationFiller = accelerationFillerBG:WaitForChild("Filler")
    accelerationTitle = acceleration:WaitForChild("Title")
    accelerationValue = acceleration:WaitForChild("Value")
    jumpPower = boardItemDetails:WaitForChild("JumpPower")
    jumpPowerFillerBG = jumpPower:WaitForChild("FillerBG")
    jumpPowerFiller = jumpPowerFillerBG:WaitForChild("Filler")
    jumpPowerTitle = jumpPower:WaitForChild("Title")
    jumpPowerValue = jumpPower:WaitForChild("Value")
    boardItemDetailsTitleLabel = revolvingContainer:WaitForChild("TitleLable")

    -- CRATES SECTION
    cratesFrame = Contents:WaitForChild("CratesFrame")
    crateScrollingItemTemplate = cratesFrame:WaitForChild("CrateScrollingItem")
    cratesList = cratesFrame:WaitForChild("Crates")
    crateSelectionFrame = cratesFrame:WaitForChild("SelectionFrame")
    cratePurchaseFrame = crateSelectionFrame:WaitForChild("Contents"):WaitForChild("PurchaseFrame")
    crateSelectionInnerFrame = crateSelectionFrame:WaitForChild("Contents"):WaitForChild("Frame")
    crateItemsScrollingFrame = crateSelectionFrame:WaitForChild("Contents"):WaitForChild("ItemsScrollingFrame")
    crateSelectionItemImage = crateSelectionInnerFrame:WaitForChild("ItemImage")
    crateSelectionItemNameLabel = crateSelectionInnerFrame:WaitForChild("ItemNameLabel")
    cratePurchaseButton = cratePurchaseFrame:WaitForChild("PurchaseButton")
    cratesBoardListScrollingFrameParent = overlay:WaitForChild("Frame")
    cratesBoardListScrollingFrame = cratesBoardListScrollingFrameParent:WaitForChild("BoardListScrollingFrame")
    scrollingBoardItemTemplate = cratesFrame:WaitForChild("ScrollingBoardCardTemplate")
    arrow = cratesBoardListScrollingFrameParent:WaitForChild("Arrow")

    winningBoardFrame = overlay:WaitForChild("WinningBoardFrame")
    winningBoardImage = winningBoardFrame:WaitForChild("WinningBoardImage")
    winningBoardNameLabel = winningBoardImage:WaitForChild("WinningBoardNameLabel")
    winningBoardFrameShine = winningBoardFrame:WaitForChild("ShiningRay")

    -- TRAILS SECTION
    trailsFrame = Contents:WaitForChild("TrailsFrame")
    trailsList = trailsFrame:WaitForChild("TrailsList")
    trailSelectionFrame = trailsFrame:WaitForChild("SelectionFrame")
    trailItemDetails = trailSelectionFrame:WaitForChild("Contents"):WaitForChild("ItemDetails")
    trailSelectionInnerFrame = trailSelectionFrame:WaitForChild("Contents"):WaitForChild("Frame")
    trailItemDetailsTitleLabel = trailSelectionInnerFrame:WaitForChild("ItemNameLabel")
    trailItemDetailsDescriptionLabel = trailItemDetails:WaitForChild("Description")

    trailPurchaseFrame = trailSelectionFrame:WaitForChild("Contents"):WaitForChild("PurchaseFrame")
    trailPurchaseButton = trailPurchaseFrame:WaitForChild("PurchaseButton")
    trailEquipButton = trailPurchaseFrame:WaitForChild("EquipButton")
    trailUnequipButton = trailPurchaseFrame:WaitForChild("UnequipButton")

    -- TABS SECTION
    tabs = Contents:WaitForChild("Tabs")
    boardsTab = tabs:WaitForChild("BoardsButton")
    trailsTab = tabs:WaitForChild("TrailsButton")
    cratesTab = tabs:WaitForChild("CratesButton")

    statusMessage = mainFrame:WaitForChild("StatusMessage")

    TAB_CONFIG = {
        [boardsTab] = boardsFrame,
        [cratesTab] = cratesFrame,
        [trailsTab] = trailsFrame
    }
    print("UI references rebuilt on character spawn")
end

local function ShowStatusMessage(message, color)
    statusMessage.Visible = true
    statusMessage.BackgroundColor3 = color
    statusMessage.Text = message
    task.wait(2)
    statusMessage.Visible = false
end

local function SetButtonsActive(active)
    boardPurchaseBtn.Interactable = active
    boardEquipButton.Interactable = active
    boardCurrentButton.Interactable = active
    cratePurchaseButton.Interactable = active
    trailPurchaseButton.Interactable = active
    trailEquipButton.Interactable = active
    trailUnequipButton.Interactable = active
    boardsTab.Interactable = active
    cratesTab.Interactable = active
    trailsTab.Interactable = active
    closeBtn.Interactable = active

    -- Disable all cards in crates list (CrateCard attribute)
    for _, card in ipairs(cratesList:GetChildren()) do
        if card:GetAttribute("CrateCard") then
            card.Interactable = active
        end
    end
end

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

    -- Tween Fillers
    TweenFiller(topSpeedFiller, data.TopSpeed / 150)
    TweenFiller(accelerationFiller, data.Acceleration / 4)
    TweenFiller(jumpPowerFiller, data.JumpPower / 100)
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

    GearService:PlayerOwnsHoverboard(boardName):andThen(function(owns)
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
            boardPurchaseBtn:WaitForChild("Price").Text = tostring(data.Price)
            SetBoardButtonState("Purchase")
        end
    end):catch(function(err)
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
            card:WaitForChild("ItemImage").Image = data.Image
            card:WaitForChild("Frame"):WaitForChild("Price").Text = tostring(data.Price)

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

    if boardData.Currency == "Robux" then
        GearService:PurchaseRobuxHoverboard(currentBoardConfig):andThen(function(success, productId)
            if success then
                MarketplaceService:PromptProductPurchase(player, productId)
            else
                ShowStatusMessage("Failed to initiate purchase!", RED_COLOR)
            end
        end):catch(function(err)
            warn("PurchaseRobuxHoverboard failed:", err)
            ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
        end)
        return
    else
        GearService:PurchaseCoinsHoverboard(currentBoardConfig, boardData.Price, boardData.Currency):andThen(function(
            success, message)
            if success then
                CoinsController:RefreshDisplay()
                SetBoardButtonState("Equip")
                ShowStatusMessage(message, GREEN_COLOR)
            else
                ShowStatusMessage(message, RED_COLOR)
            end

        end):catch(function(err)
            warn("PurchaseHoverboard failed:", err)
            ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
        end)
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

    GearService:PlayerOwnsTrail(trailName):andThen(function(owns)
        if owns then
            SetTrailButtonState("Equip")
        else
            SetTrailButtonState("Purchase")
        end
    end):catch(function()
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
            card:WaitForChild("ItemImage").Image = data.Image
            card:WaitForChild("Frame"):WaitForChild("Price").Text = tostring(data.Price)
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

    if data.Currency == "Robux" then
        GearService:PurchaseRobuxTrail(currentTrailConfig):andThen(function(success, productId)
            if success then
                MarketplaceService:PromptProductPurchase(player, productId)
            else
                ShowStatusMessage("Failed to initiate purchase!", RED_COLOR)
            end
        end):catch(function(err)
            warn("PurchaseRobuxTrail failed:", err)
            ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
        end)
        return
    else -- Currency is Coins
        GearService:PurchaseCoinsTrail(currentTrailConfig, data.Price):andThen(function(success, message)
            if success then
                CoinsController:RefreshDisplay()
                SetTrailButtonState("Equip")
                ShowStatusMessage(message, GREEN_COLOR)
            else
                ShowStatusMessage(message, RED_COLOR)
            end

        end):catch(function(err)
            warn("PurchaseTrail failed:", err)
            ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
        end)
    end
end

local function EquipTrail()
    if not currentTrailConfig then
        return
    end
    GearService:EquipTrail(currentTrailConfig):andThen(function(success, message)
        if success then
            equippedTrail = currentTrailConfig
            print("equippedTrail", equippedTrail)
            SetTrailButtonState("Unequip")
            ShowStatusMessage(message, GREEN_COLOR)
        else
            ShowStatusMessage(message, RED_COLOR)
        end
    end):catch(function()
        ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
    end)
end

local function UnequipTrail()
    GearService:UnequipTrail():andThen(function(success, message)
        if success then
            equippedTrail = nil
            SetTrailButtonState("Equip")
            ShowStatusMessage(message, GREEN_COLOR)
        else
            ShowStatusMessage(message, RED_COLOR)
        end
    end):catch(function()
        ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
    end)
end
--------------------------------------------------------

----------------- CRATES FUNCTIONS ---------------------
local function OpenWinningBoardFrame(board, active)
    winningBoardFrame.Visible = active
    winningBoardFrameShine.Visible = active

    winningBoardImage:WaitForChild("BoardImage").Image = board.Image
    winningBoardImage:WaitForChild("RarityBG").Image = board.Background
    winningBoardNameLabel.Text = board.Name
end

local function PopulateCrateItemBoardsList(crateData)
    for _, child in ipairs(crateItemsScrollingFrame:GetChildren()) do
        if child:GetAttribute("CrateBoardItem") then
            child:Destroy()
        end
    end

    if not crateData.BoardsList then
        return
    end

    for _, boardData in pairs(crateData.BoardsList) do
        if typeof(boardData) == "table" then
            local item = crateScrollingItemTemplate:Clone()
            item.Visible = true
            item.Parent = crateItemsScrollingFrame
            item:SetAttribute("CrateBoardItem", true)

            -- UI fill
            item:WaitForChild("ItemImage").Image = boardData.Image
            item:WaitForChild("RarityBG").Image = boardData.Background
            item:WaitForChild("PercentageLabel").Text = string.format("%.2f%%", boardData.Percentage)
        end
    end

    -- Populate scrolling board list for spinning animation
    for boardName, boardData in pairs(crateData.BoardsList) do
        if typeof(boardData) == "table" then
            local card = scrollingBoardItemTemplate:Clone()
            card.Visible = true
            card.Parent = cratesBoardListScrollingFrame
            card:SetAttribute("ScrollingBoardItem", true)

            -- Fill card UI
            card:WaitForChild("BoardImage").Image = boardData.Image
            card:WaitForChild("RarityBG").Image = boardData.Background
            card:WaitForChild("BoardNameLabel").Text = boardData.Name
        end
    end

    -- Ensure there are enough items for smooth scrolling
    local itemCount = #cratesBoardListScrollingFrame:GetChildren()
    if itemCount < 100 then
        -- Duplicate items to create an endless loop effect
        local originalItems = {}
        for _, child in ipairs(cratesBoardListScrollingFrame:GetChildren()) do
            if child:GetAttribute("ScrollingBoardItem") then
                table.insert(originalItems, child:Clone())
            end
        end

        for i = 1, math.ceil(100 / itemCount) do
            for _, item in ipairs(originalItems) do
                local clone = item:Clone()
                clone.Parent = cratesBoardListScrollingFrame
                clone:SetAttribute("ScrollingBoardItem", true)
            end
        end
    end
end

local function SelectCrate(crateName)
    local data = cratesData[crateName]
    if not data then
        return
    end

    currentCrateConfig = crateName
    crateSelectionItemNameLabel.Text = data.Name
    crateSelectionItemImage.Image = data.Image
    cratePurchaseButton:WaitForChild("Price").Text = tostring(data.Price)

    PopulateCrateItemBoardsList(data)
end

local function PopulateCrates()
    for _, child in ipairs(cratesList:GetChildren()) do
        if child:GetAttribute("CrateCard") then
            child:Destroy()
        end
    end

    for crateName, data in pairs(cratesData) do
        if typeof(data) == "table" then
            local card = cardTemplate:Clone()
            card.Name = crateName
            card.Visible = true
            card.Parent = cratesList
            card:SetAttribute("CrateCard", true)

            card:WaitForChild("Title").Text = data.Name
            card:WaitForChild("ItemImage").Image = data.Image
            card:WaitForChild("Frame"):WaitForChild("Price").Text = tostring(data.Price)

            card.MouseButton1Click:Connect(function()
                SelectCrate(crateName)
            end)
        end
    end
end

local function GetRandomBoardFromCrate(crateName)
    local crateData = cratesData[crateName]
    if not crateData or not crateData.BoardsList then
        return nil
    end

    -- Calculate total percentage
    local totalPercentage = 0
    for _, boardData in pairs(crateData.BoardsList) do
        totalPercentage = totalPercentage + boardData.Percentage
    end

    -- Generate random number
    local randomValue = math.random() * totalPercentage

    -- Find winning board based on percentage
    local currentSum = 0
    for boardName, boardData in pairs(crateData.BoardsList) do
        currentSum = currentSum + boardData.Percentage
        if randomValue <= currentSum then
            return boardName, boardData
        end
    end

    return nil
end

local function SpinCrateAnimation(winningBoardName, winningBoardData)
    SetButtonsActive(false)
    overlay.Visible = true
    cratesBoardListScrollingFrameParent.Visible = true

    local RunService = game:GetService("RunService")

    local scrollingFrame = cratesBoardListScrollingFrame
    local items = scrollingFrame:GetChildren()

    -- Filter valid items
    local boardItems = {}
    for _, child in ipairs(items) do
        if child:GetAttribute("ScrollingBoardItem") then
            table.insert(boardItems, child)
        end
    end

    if #boardItems == 0 then
        return
    end

    -- Measurements
    local itemWidth = boardItems[1].AbsoluteSize.X
    local viewportWidth = scrollingFrame.AbsoluteWindowSize.X
    local contentWidth = itemWidth * #boardItems

    -- Find winning index
    local winningIndex = 1
    for i, item in ipairs(boardItems) do
        if item.BoardNameLabel.Text == winningBoardData.Name then
            winningIndex = i
            break
        end
    end

    -- Calculate target position to center the winning item
    local targetX = ((winningIndex - 1) * itemWidth) - (viewportWidth / 2) + (itemWidth / 2)

    -- Adjust targetX for looping effect (ensure it's in a reasonable position)
    -- We want to pass through enough items to make the spin look good
    local currentX = scrollingFrame.CanvasPosition.X
    local loops = 2
    local spinDistance = contentWidth * loops + targetX -- Spin through 3 full loops plus to target

    -- Spin parameters
    local spinDuration = 3
    local elapsed = 0
    local startSpeed = 2000 -- Start spinning speed

    -- Store initial positions
    local initialCanvasPos = Vector2.new(currentX, 0)

    local connection
    connection = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt

        -- Calculate progress through the animation
        local progress = elapsed / spinDuration

        -- Use easing function for smooth acceleration and deceleration
        -- This creates a slow start, fast middle, slow end
        local easeProgress
        if progress < 0.1 then
            -- Quick acceleration
            easeProgress = (progress / 0.1) ^ 2 * 0.45
        elseif progress < 0.8 then
            -- Fast cruising
            easeProgress = 0.5 + 0.5 * ((progress - 0.1) / 0.7)
        else
            -- Long smooth deceleration
            local decelProgress = (progress - 0.8) / 0.4
            easeProgress = 0.9 + 0.1 * (1 - (1 - decelProgress) ^ 2) -- Quadratic ease-out
        end

        -- Calculate current position based on eased progress
        local newX = initialCanvasPos.X + (spinDistance * easeProgress)

        -- Loop illusion
        if newX >= contentWidth then
            newX = newX % contentWidth
            initialCanvasPos = Vector2.new(initialCanvasPos.X - contentWidth, 0)
        end

        scrollingFrame.CanvasPosition = Vector2.new(newX, 0)

        -- Stop after full duration
        if elapsed >= spinDuration then
            connection:Disconnect()

            -- Ensure we're exactly on target
            scrollingFrame.CanvasPosition = Vector2.new(targetX, 0)

            task.delay(1, function()
                GearService:PurchaseCoinsHoverboard(winningBoardName, 0):andThen(function(success, message)
                    if success then
                        OpenWinningBoardFrame(winningBoardData, true)
                        cratesBoardListScrollingFrameParent.Visible = false
                        task.delay(3, function()
                            OpenWinningBoardFrame(winningBoardData, false)
                            overlay.Visible = false
                            SetButtonsActive(true)
                        end)
                    else
                        ShowStatusMessage(message, RED_COLOR)
                        overlay.Visible = false
                        SetButtonsActive(true)
                    end
                end)
            end)
        end
    end)

    -- SetButtonsActive(false)
    -- overlay.Visible = true
    -- cratesBoardListScrollingFrameParent.Visible = true

    -- local RunService = game:GetService("RunService")

    -- local scrollingFrame = cratesBoardListScrollingFrame
    -- local items = scrollingFrame:GetChildren()

    -- -- Filter valid items
    -- local boardItems = {}
    -- for _, child in ipairs(items) do
    --     if child:GetAttribute("ScrollingBoardItem") then
    --         table.insert(boardItems, child)
    --     end
    -- end

    -- if #boardItems == 0 then
    --     return
    -- end

    -- -- Measurements
    -- local itemWidth = boardItems[1].AbsoluteSize.X
    -- local viewportWidth = scrollingFrame.AbsoluteWindowSize.X
    -- local contentWidth = itemWidth * #boardItems

    -- -- Find winning index
    -- local winningIndex = 1
    -- for i, item in ipairs(boardItems) do
    --     if item.BoardNameLabel.Text == winningBoardData.Name then
    --         winningIndex = i
    --         break
    --     end
    -- end

    -- -- Center winning item
    -- local targetX = ((winningIndex - 1) * itemWidth) - (viewportWidth / 2) + (itemWidth / 2)
    -- targetX = math.clamp(targetX, 0, math.max(0, contentWidth - viewportWidth))

    -- -- Spin parameters
    -- local spinDuration = 5
    -- local elapsed = 0
    -- local startSpeed = 2000 -- Start spinning speed
    -- local decelerationStartTime = 2.5 -- Start deceleration after 3.5 seconds
    -- local decelerationDuration = 2.5 -- Decelerate over 1.5 seconds
    -- local currentX = scrollingFrame.CanvasPosition.X

    -- local connection
    -- connection = RunService.Heartbeat:Connect(function(dt)
    --     elapsed = elapsed + dt

    --     -- Calculate current speed based on deceleration phase
    --     local currentSpeed = startSpeed

    --     if elapsed >= decelerationStartTime then
    --         -- Start decelerating
    --         local decelAlpha = math.clamp((elapsed - decelerationStartTime) / decelerationDuration, 0, 1)
    --         -- Quadratic ease-out deceleration
    --         local decelFactor = (1 - decelAlpha) ^ 2
    --         currentSpeed = startSpeed * decelFactor
    --         print("Stops here.")
    --     end

    --     -- Apply movement
    --     currentX = currentX + currentSpeed * dt

    --     -- Loop illusion
    --     if currentX >= contentWidth then
    --         currentX = currentX - contentWidth
    --     end

    --     scrollingFrame.CanvasPosition = Vector2.new(currentX, 0)

    --     -- Stop only once after the full duration
    --     if elapsed >= spinDuration then
    --         connection:Disconnect()

    --         print("Spin complete")
    --         -- Snap to winning position
    --         scrollingFrame.CanvasPosition = Vector2.new(targetX, 0)

    --         task.delay(1, function()
    --             print("Going to purchase the hoverboard.")
    --             GearService:PurchaseHoverboard(winningBoardName, 0, "Coins"):andThen(function(success, message)
    --                 OpenWinningBoardFrame(winningBoardData, true)
    --                 cratesBoardListScrollingFrameParent.Visible = false
    --                 task.delay(3, function()
    --                     OpenWinningBoardFrame(winningBoardData, false)
    --                     overlay.Visible = false
    --                     SetButtonsActive(true)
    --                 end)

    --                 -- if success then
    --                 --     print("Purchased winning board from crate:", winningBoardName)
    --                 --     OpenWinningBoardFrame(winningBoardData, true)
    --                 --     cratesBoardListScrollingFrameParent.Visible = false
    --                 --     task.delay(3, function()
    --                 --         OpenWinningBoardFrame(winningBoardData, false)
    --                 --         overlay.Visible = false
    --                 --         SetButtonsActive(true)
    --                 --     end)
    --                 -- else
    --                 -- 	print("Failed to purchase winning board from crate:", winningBoardName)
    --                 -- 	ShowStatusMessage(message, RED_COLOR)
    --                 -- 	overlay.Visible = false
    --                 -- 	SetButtonsActive(true)
    --                 -- end
    --             end)
    --         end)
    --     end
    -- end)
end

local function StartCrateAnimation()
    local winningBoardName, winningBoardData = GetRandomBoardFromCrate(currentCrateConfig)
    if winningBoardName then
        -- Start spin animation
        print("Winning board:", winningBoardName)
        SpinCrateAnimation(winningBoardName, winningBoardData)
    end
end

local function PurchaseCrate()
    if not currentCrateConfig then
        print("Not current crate selected")
        return
    end

    local crateData = cratesData[currentCrateConfig]
    if not crateData then
        return
    end

    print("Purchasing crate:", currentCrateConfig)
    print("Crate:", crateData)

    if crateData.Currency == "Robux" then
        GearService:PurchaseRobuxCrate(currentCrateConfig):andThen(function(success, productId)
            if success then
                print("Currency is robux, prompting purchase")
                MarketplaceService:PromptProductPurchase(player, productId)
            else
                ShowStatusMessage("Failed to initiate purchase!", RED_COLOR)
            end
        end):catch(function(err)
            warn("PurchaseRobuxCrate failed:", err)
            ShowStatusMessage(WARNING_TEXT, YELLOW_COLOR)
        end)
    else -- Currency == Coins
        GearService:PurchaseCoinsCrate(currentCrateConfig, crateData.Price):andThen(function(success, result)
            if success then
                -- Get random winning board
                print("Currency is Coins, refreshing display and showing animation")
                CoinsController:RefreshDisplay()
                StartCrateAnimation()
            else
                CoinsController:RefreshDisplay()
                ShowStatusMessage(result, RED_COLOR)
            end
        end)
    end
end
--------------------------------------------------------

-----------------  GLOBAL FUNCTIONS --------------------
local function CloseGearGui()
    Gear.Enabled = false
end

local function SetSelectedTab(selected)
    boardsTab:WaitForChild("Select").Visible = (selected == boardsTab)
    cratesTab:WaitForChild("Select").Visible = (selected == cratesTab)
    trailsTab:WaitForChild("Select").Visible = (selected == trailsTab)
end

local function OpenTab(selectedTab)
    for tabButton, frame in pairs(TAB_CONFIG) do
        if tabButton == selectedTab then
            frame.Visible = true
            SetSelectedTab(tabButton)

            if tabButton == trailsTab and equippedTrail then
                SelectTrail(equippedTrail)
            elseif tabButton == cratesTab then
                SelectCrate("BasicCrate")
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
            -- CloseGearGui()
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
    cratePurchaseButton.MouseButton1Click:Connect(function()
        PurchaseCrate()
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
    -- boardsTab.BackgroundColor3 = NORMAL_COLOR
    -- cratesTab.BackgroundColor3 = NORMAL_COLOR
    -- trailsTab.BackgroundColor3 = NORMAL_COLOR

    Gear = nil
    mainFrame = nil
    closeBtn = nil
    Contents = nil
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
--------------------------------------------------------

----------------- CHARACTER LIFECYCLE ------------------

local function PopulateItems()
    HoverboardService:GetHoverboardData():andThen(function(data)
        if data then
            equippedBoard = data.Name
            if equippedBoard then
                PopulateHoverboards()
                OpenTab(boardsTab)
                SelectHoverboard(equippedBoard)
                PopulateCrates()
            end
        end
    end):catch(function(err)
        warn("Failed to get hoverboard data:", err)
    end)

    GearService:GetEquippedTrail():andThen(function(trailName)
        equippedTrail = trailName
        PopulateTrails()
        SelectTrail(equippedTrail)
    end):catch(function(err)
        warn("Failed to get trail data:", err)
    end)
end

local function OnCharacterAdded(char)
    HoverboardService = Knit.GetService("HoverboardService")
    GearService = Knit.GetService("GearService")
    RobuxReceiptService = Knit.GetService("RobuxReceiptService")
    CoinsController = Knit.GetController("CoinsController")

    UIReferences()
    BindInput()
    PopulateItems()

    HoverboardService.HoverboardSpawned:Connect(function(owner, boardName)
        PopulateItems()
    end)
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
    OnPlayerAdded(player)
    RobuxReceiptService.CratePurchased:Connect(function()
        task.delay(1, function()
            StartCrateAnimation()
        end)
    end)
end

return GearController
