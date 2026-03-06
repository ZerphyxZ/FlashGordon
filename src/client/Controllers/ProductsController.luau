local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))

local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local workspace = game:GetService("Workspace")

local ProductsController = Knit.CreateController({ Name = "ProductsController" })
local ProductsService

-- ── Public flags (read by NewController and other systems) ────────────────────
ProductsController.HasDoubleJump    = false
ProductsController.HasFastRespawn  = false
ProductsController.HasGravity      = false
ProductsController.HasDoubleLuck   = false
ProductsController.HasDoubleCoins  = false
ProductsController.HasDisablePopups = false
ProductsController.HasWorldPass    = false
ProductsController.HasInfFlyBar    = false
-- Legacy fly kept for NewController compatibility
ProductsController.HasFly          = false
ProductsController.flybar          = nil   -- Frame set by CreateFlyBar, read by NewController

-- ── Character refs ────────────────────────────────────────────────────────────
local character, humanoid
local billboard, flyBarBackground

-- ── Gravity ───────────────────────────────────────────────────────────────────
local DEFAULT_GRAVITY = workspace.Gravity
local REDUCED_GRAVITY = workspace.Gravity / 2

-- ── UI refs (rebuilt on every character spawn) ────────────────────────────────
local playerGui, gameHUD
-- Per-product: { button, timer }
local UI = {}

local RED_COLOR    = Color3.fromRGB(255, 60, 60)
local GREEN_COLOR  = Color3.fromRGB(60, 255, 120)
local YELLOW_COLOR = Color3.fromRGB(255, 220, 0)

-- ── UI helper: find a Frame + Button + DurationTimer inside GameHUD ────────────
-- Expected structure for each product:
--   GameHUD / <FrameName>Frame / <ButtonName>Button   (TextButton/ImageButton)
--   GameHUD / <FrameName>Frame / DurationTimer        (TextLabel)
local function FindProductUI(frameName, buttonName)
    if not gameHUD then return nil, nil end
    local frame = gameHUD:FindFirstChild(frameName .. "Frame")
    if not frame then return nil, nil end
    local btn   = frame:FindFirstChild(buttonName .. "Button")
    local timer = frame:FindFirstChild("DurationTimer")
    return btn, timer
end

-- ── Countdown timer ────────────────────────────────────────────────────────────
local function RunTimer(button, label, endAt)
    task.spawn(function()
        while true do
            local left = math.max(0, math.ceil(endAt - tick()))
            if label then label.Text = left .. "s" end
            if left <= 0 then
                if label  then label.Visible = false end
                if button then button.Interactable = true end
                break
            end
            task.wait(1)
        end
    end)
end

-- ── Generic bind: one signal pair drives one product slot ─────────────────────
local function BindProduct(options)
    -- options: {
    --   activatedSignal, expiredSignal,
    --   button, timer,
    --   flag,        -- string key into ProductsController (e.g. "HasDoubleJump")
    --   onActivate,  -- optional function()
    --   onExpire,    -- optional function()
    -- }
    options.activatedSignal:Connect(function(duration)
        print(options.flag, "activated, duration:", duration)
        ProductsController[options.flag] = true
        local endAt = tick() + duration
        if options.button then
            options.button.Interactable = false
        end
        if options.timer then
            options.timer.Visible = true
        end
        if options.onActivate then options.onActivate() end
        RunTimer(options.button, options.timer, endAt)
    end)

    options.expiredSignal:Connect(function()
        print(options.flag, "expired.")
        ProductsController[options.flag] = false
        if options.timer  then options.timer.Visible = false end
        if options.button then options.button.Interactable = true end
        if options.onExpire then options.onExpire() end
    end)
end

-- ── Fly Bar (BillboardGui created at runtime) ─────────────────────────────────
function ProductsController:CreateFlyBar()
    billboard = Instance.new("BillboardGui")
    billboard.Name = "FlyEnergyBillboard"
    billboard.Parent = humanoid
    billboard.Size = UDim2.fromScale(0.85, 4)
    billboard.StudsOffsetWorldSpace = Vector3.new(3, -1.5, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.ResetOnSpawn = false

    flyBarBackground = Instance.new("Frame")
    flyBarBackground.Name = "Background"
    flyBarBackground.Parent = billboard
    flyBarBackground.Size = UDim2.fromScale(1, 1)
    flyBarBackground.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    flyBarBackground.BackgroundTransparency = 0.2
    flyBarBackground.BorderSizePixel = 0
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0.1, 0)
    bgCorner.Parent = flyBarBackground

    ProductsController.flybar = Instance.new("Frame")
    ProductsController.flybar.Name = "EnergyBar"
    ProductsController.flybar.Parent = flyBarBackground
    ProductsController.flybar.Size = UDim2.fromScale(1, 1)
    ProductsController.flybar.AnchorPoint = Vector2.new(0, 1)
    ProductsController.flybar.Position = UDim2.fromScale(0, 1)
    ProductsController.flybar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    ProductsController.flybar.BorderSizePixel = 0
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0.1, 0)
    barCorner.Parent = ProductsController.flybar
end

function ProductsController:DestroyFlyBar()
    if billboard then
        billboard:Destroy()
        billboard = nil
    end
    ProductsController.flybar = nil
end

-- ── UIReferences ─────────────────────────────────────────────────────────────
function ProductsController:UIReferences()
    playerGui = player:WaitForChild("PlayerGui")
    gameHUD   = playerGui:WaitForChild("GameHUD")

    UI.DoubleJump    = { FindProductUI("DoubleJump",    "DoubleJump")    }
    UI.FastRespawn   = { FindProductUI("FastRespawn",   "FastRespawn")   }
    UI.Gravity       = { FindProductUI("Gravity",       "Gravity")       }
    UI.DoubleLuck    = { FindProductUI("DoubleLuck",    "DoubleLuck")    }
    UI.DoubleCoins   = { FindProductUI("DoubleCoins",   "DoubleCoins")   }
    UI.DisablePopups = { FindProductUI("DisablePopups", "DisablePopups") }
    UI.WorldPass     = { FindProductUI("WorldPass",     "WorldPass")     }
    UI.InfFlyBar     = { FindProductUI("InfFlyBar",     "InfFlyBar")     }
    -- Legacy (existing HUD frames kept as-is)
    UI.Fly           = { FindProductUI("Fly",           "Fly")           }
end

-- ── ClearUI ───────────────────────────────────────────────────────────────────
function ProductsController:ClearUI()
    playerGui, gameHUD = nil, nil
    UI = {}
    ProductsController.flybar = nil
    flyBarBackground = nil
    billboard = nil
    ProductsController.HasDoubleJump    = false
    ProductsController.HasFastRespawn  = false
    ProductsController.HasGravity      = false
    ProductsController.HasDoubleLuck   = false
    ProductsController.HasDoubleCoins  = false
    ProductsController.HasDisablePopups = false
    ProductsController.HasWorldPass    = false
    ProductsController.HasInfFlyBar    = false
    ProductsController.HasFly          = false
end

-- ── GetProductId helper used by BindInput ─────────────────────────────────────
local function PromptPurchase(productName)
    ProductsService:GetProductId(productName):andThen(function(success, productId)
        if success then
            MarketplaceService:PromptProductPurchase(player, productId)
        else
            warn("[ProductsController] GetProductId failed for", productName, productId)
        end
    end):catch(function(err)
        warn("[ProductsController] GetProductId error:", err)
    end)
end

-- ── BindInput ─────────────────────────────────────────────────────────────────
function ProductsController:BindInput()
    local function safe(btn, fn)
        if btn then btn.MouseButton1Click:Connect(fn) end
    end

    safe(UI.DoubleJump[1],    function() PromptPurchase("DoubleJump")    end)
    safe(UI.FastRespawn[1],   function() PromptPurchase("FastRespawn")   end)
    safe(UI.Gravity[1],       function() PromptPurchase("GravityCoil")   end)
    safe(UI.DoubleLuck[1],    function() PromptPurchase("DoubleLuck")    end)
    safe(UI.DoubleCoins[1],   function() PromptPurchase("DoubleCoins")   end)
    safe(UI.DisablePopups[1], function() PromptPurchase("DisablePopups") end)
    safe(UI.WorldPass[1],     function() PromptPurchase("WorldPass")     end)
    safe(UI.InfFlyBar[1],     function() PromptPurchase("InfFlyBar")     end)
    -- Legacy fly button
    safe(UI.Fly[1],           function() ProductsService:PurchaseFly()   end)
end

-- ── BindSignals ───────────────────────────────────────────────────────────────
function ProductsController:BindSignals()
    BindProduct({
        activatedSignal = ProductsService.DoubleJumpActivated,
        expiredSignal   = ProductsService.DoubleJumpExpired,
        button = UI.DoubleJump[1], timer = UI.DoubleJump[2],
        flag   = "HasDoubleJump",
    })

    BindProduct({
        activatedSignal = ProductsService.FastRespawnActivated,
        expiredSignal   = ProductsService.FastRespawnExpired,
        button = UI.FastRespawn[1], timer = UI.FastRespawn[2],
        flag   = "HasFastRespawn",
    })

    BindProduct({
        activatedSignal = ProductsService.GravityActivated,
        expiredSignal   = ProductsService.GravityExpired,
        button = UI.Gravity[1], timer = UI.Gravity[2],
        flag   = "HasGravity",
        onActivate = function() workspace.Gravity = REDUCED_GRAVITY end,
        onExpire   = function() workspace.Gravity = DEFAULT_GRAVITY  end,
    })

    BindProduct({
        activatedSignal = ProductsService.DoubleLuckActivated,
        expiredSignal   = ProductsService.DoubleLuckExpired,
        button = UI.DoubleLuck[1], timer = UI.DoubleLuck[2],
        flag   = "HasDoubleLuck",
    })

    BindProduct({
        activatedSignal = ProductsService.DoubleCoinsActivated,
        expiredSignal   = ProductsService.DoubleCoinsExpired,
        button = UI.DoubleCoins[1], timer = UI.DoubleCoins[2],
        flag   = "HasDoubleCoins",
    })

    BindProduct({
        activatedSignal = ProductsService.DisablePopupsActivated,
        expiredSignal   = ProductsService.DisablePopupsExpired,
        button = UI.DisablePopups[1], timer = UI.DisablePopups[2],
        flag   = "HasDisablePopups",
    })

    BindProduct({
        activatedSignal = ProductsService.WorldPassActivated,
        expiredSignal   = ProductsService.WorldPassExpired,
        button = UI.WorldPass[1], timer = UI.WorldPass[2],
        flag   = "HasWorldPass",
    })

    BindProduct({
        activatedSignal = ProductsService.InfFlyBarActivated,
        expiredSignal   = ProductsService.InfFlyBarExpired,
        button = UI.InfFlyBar[1], timer = UI.InfFlyBar[2],
        flag   = "HasInfFlyBar",
        onActivate = function() self:CreateFlyBar() end,
        onExpire   = function() self:DestroyFlyBar() end,
    })

    -- Legacy fly (kept for back-compat with existing buttons/NewController)
    BindProduct({
        activatedSignal = ProductsService.FlyActivated,
        expiredSignal   = ProductsService.FlyExpired,
        button = UI.Fly[1], timer = UI.Fly[2],
        flag   = "HasFly",
        onActivate = function() self:CreateFlyBar() end,
        onExpire   = function() self:DestroyFlyBar() end,
    })
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
function ProductsController:OnCharacterAdded(char)
    character = char
    humanoid  = character:WaitForChild("Humanoid")
    ProductsService = Knit.GetService("ProductsService")
    self:UIReferences()
    self:BindInput()
    self:BindSignals()
    if ProductsController.HasFly or ProductsController.HasInfFlyBar then
        self:CreateFlyBar()
    end
end

function ProductsController:OnCharacterRemoving()
    self:ClearUI()
end

function ProductsController:OnPlayerAdded(plr)
    if plr ~= player then return end
    plr.CharacterAdded:Connect(function()
        self:OnCharacterAdded(plr.Character or plr.CharacterAdded:Wait())
    end)
    plr.CharacterRemoving:Connect(function()
        self:OnCharacterRemoving()
    end)
    if plr.Character then
        self:OnCharacterAdded(plr.Character)
    end
end

function ProductsController:KnitStart()
    self:OnPlayerAdded(player)
end

return ProductsController














-- local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
--     "Global"))

-- local TweenService = game:GetService("TweenService")
-- local Knit = Global.Knit
-- local Players = Global.Players
-- local player = Players.LocalPlayer
-- local character
-- local humanoid
-- local ReplicatedStorage = Global.ReplicatedStorage
-- local workspace = game:GetService("Workspace")
-- local ProductsController = Knit.CreateController({
--     Name = "ProductsController"
-- })
-- local ProductsService

-- -- UI References
-- local playerGui
-- local gameHUD
-- local doubleJumpButton
-- local doubleJumpDuration
-- local flyButton
-- local flyDuration
-- local gravityButton
-- local gravityDuration
-- ProductsController.flybar = nil
-- local flyBarBackground
-- local billboard

-- ProductsController.HasDoubleJump = false
-- ProductsController.HasFly = false
-- ProductsController.IsFlying = false
-- ProductsController.HasGravity = false

-- local DEFAULT_GRAVITY = workspace.Gravity
-- local REDUCED_GRAVITY = workspace.Gravity / 2

-- ---------------------- Common functions ------------------------
-- function ProductsController:UIReferences()
--     playerGui = player:WaitForChild("PlayerGui")
--     gameHUD = playerGui:WaitForChild("GameHUD")
--     doubleJumpButton = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DoubleJumpButton")
--     doubleJumpDuration = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DurationTimer")
--     flyButton = gameHUD:WaitForChild("FlyFrame"):WaitForChild("FlyButton")
--     flyDuration = gameHUD:WaitForChild("FlyFrame"):WaitForChild("DurationTimer")
--     gravityButton = gameHUD:WaitForChild("GravityFrame"):WaitForChild("GravityButton")
--     gravityDuration = gameHUD:WaitForChild("GravityFrame"):WaitForChild("DurationTimer")
-- end

-- function ProductsController:ClearUI()
--     playerGui = nil
--     gameHUD = nil
--     doubleJumpButton = nil
--     doubleJumpDuration = nil
--     flyButton = nil
--     flyDuration = nil
--     gravityButton = nil
--     gravityDuration = nil
--     ProductsController.flybar = nil
--     flyBarBackground = nil
--     billboard = nil
--     ProductsController.HasDoubleJump = false
--     ProductsController.HasFly = false
--     ProductsController.IsFlying = false
--     ProductsController.HasGravity = false
-- end

-- function ProductsController:BindInput()
--     doubleJumpButton.MouseButton1Click:Connect(function()
--         ProductsService:PurchaseDoubleJump()
--     end)

--     flyButton.MouseButton1Click:Connect(function()
--         ProductsService:PurchaseFly()
--     end)

--     gravityButton.MouseButton1Click:Connect(function()
--         ProductsService:PurchaseGravity()
--     end)
-- end

-- function ProductsController:BindTimedProduct(options)
--     local activatedSignal = options.Activated
--     local expiredSignal = options.Expired
--     local button = options.Button
--     local label = options.Label
--     local onActivate = options.OnActivate
--     local onExpire = options.OnExpire

--     activatedSignal:Connect(function(endTime)
--         print(options.Name .. " Activated until:", endTime)
--         if button then
--             button.Interactable = false
--         end
--         if label then
--             label.Visible = true
--         end
--         if onActivate then
--             onActivate()
--         end

--         task.spawn(function()
--             while true do
--                 local timeLeft = endTime - os.time()
--                 if timeLeft <= 0 then
--                     if label then
--                         label.Text = "0s"
--                         label.Visible = false
--                     end
--                     if button then
--                         button.Interactable = true
--                     end
--                     break
--                 end
--                 if label then
--                     label.Text = timeLeft .. "s"
--                 end
--                 task.wait(1)
--             end
--         end)
--     end)

--     expiredSignal:Connect(function()
--         print(options.Name .. " Expired.")
--         if label then
--             label.Visible = false
--         end
--         if button then
--             button.Interactable = true
--         end
--         if onExpire then
--             onExpire()
--         end
--     end)
-- end

-- function UpdateTimer(button, duration, endTime)
--     local timeLeft = math.max(0, math.ceil(endTime - tick()))
--     duration.Text = tostring(timeLeft) .. "s"
--     if timeLeft <= 0 then
--         button.Interactable = true
--         duration.Visible = false
--         return
--     end
--     task.delay(1, function()
--         UpdateTimer(button, duration, endTime)
--     end)
-- end

-- ------Double Jump--------
-- function ProductsController:BindDoubleJump()
--     ProductsService.DoubleJumpActivated:Connect(function(duration)
--         print("Double Jump Activated until:", duration)
--         doubleJumpButton.Interactable = false
--         doubleJumpDuration.Visible = true
--         ProductsController.HasDoubleJump = true
--         local endAt = tick() + duration
--         UpdateTimer(doubleJumpButton, doubleJumpDuration, endAt)
--     end)

--     ProductsService.DoubleJumpExpired:Connect(function()
--         print("Double Jump Expired.")
--         ProductsController.HasDoubleJump = false
--     end)
-- end
-- -------------------------

-- ------Gravity------------
-- function ProductsController:BindGravity()
--     ProductsService.GravityActivated:Connect(function(duration)
--         print("Gravity Activated until:", duration)
--         gravityButton.Interactable = false
--         gravityDuration.Visible = true
--         ProductsController.HasGravity = true
--         workspace.Gravity = REDUCED_GRAVITY
--         local endAt = tick() + duration
--         UpdateTimer(gravityButton, gravityDuration, endAt)
--     end)

--     ProductsService.GravityExpired:Connect(function()
--         print("Gravity Expired.")
--         ProductsController.HasGravity = false
--         workspace.Gravity = DEFAULT_GRAVITY
--     end)
-- end
-- -------------------------

-- ----------Fly------------
-- function ProductsController:BindFly()
--     ProductsService.FlyActivated:Connect(function(duration)
--         print("Fly Activated until:", duration)
--         flyButton.Interactable = false
--         flyDuration.Visible = true
--         ProductsController.HasFly = true
--         local endAt = tick() + duration
--         self:CreateFlyBar()
--         UpdateTimer(flyButton, flyDuration, endAt)
--     end)

--     ProductsService.FlyExpired:Connect(function()
--         print("Fly Expired.")
--         ProductsController.HasFly = false
--         self:DestroyFlyBar()
--     end)
-- end

-- function ProductsController:CreateFlyBar()
--     billboard = Instance.new("BillboardGui")
--     billboard.Name = "FlyEnergyBillboard"
--     billboard.Parent = humanoid

--     billboard.Size = UDim2.fromScale(0.85, 4)
--     billboard.StudsOffsetWorldSpace = Vector3.new(3, -1.5, 0)
--     billboard.AlwaysOnTop = true
--     billboard.LightInfluence = 0
--     billboard.ResetOnSpawn = false

--     flyBarBackground = Instance.new("Frame")
--     flyBarBackground.Name = "Background"
--     flyBarBackground.Parent = billboard
--     flyBarBackground.Size = UDim2.fromScale(1, 1)
--     flyBarBackground.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
--     flyBarBackground.BorderSizePixel = 0
--     flyBarBackground.BackgroundTransparency = 0.2
--     -- UICorner for Background
--     local bgCorner = Instance.new("UICorner")
--     bgCorner.CornerRadius = UDim.new(0.1, 0)
--     bgCorner.Parent = flyBarBackground

--     ProductsController.flybar = Instance.new("Frame")
--     ProductsController.flybar.Name = "EnergyBar"
--     ProductsController.flybar.Parent = flyBarBackground
--     ProductsController.flybar.Size = UDim2.fromScale(1, 1)
--     ProductsController.flybar.AnchorPoint = Vector2.new(0, 1)
--     ProductsController.flybar.Position = UDim2.fromScale(0, 1)
--     ProductsController.flybar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
--     ProductsController.flybar.BorderSizePixel = 0
--     -- UICorner for Energy Bar
--     local barCorner = Instance.new("UICorner")
--     barCorner.CornerRadius = UDim.new(0.1, 0)
--     barCorner.Parent = ProductsController.flybar
-- end

-- function ProductsController:DestroyFlyBar()
--     if billboard then
--         billboard:Destroy()
--     end
-- end
-- -------------------------

-- -- Player lifecycle methods
-- function ProductsController:OnCharacterAdded(char)
--     character = char
--     humanoid = character:WaitForChild("Humanoid")
--     ProductsService = Knit.GetService("ProductsService")
--     self:UIReferences()
--     if ProductsController.HasFly then
--         self:CreateFlyBar()
--     end
-- end

-- function ProductsController:OnCharacterRemoving(character)

-- end

-- function ProductsController:OnPlayerAdded(plr)
--     if plr ~= player then
--         return
--     end
--     plr.CharacterAdded:Connect(function()
--         self:OnCharacterAdded(plr.Character)
--     end)
--     plr.CharacterRemoving:Connect(function()
--         self:OnCharacterRemoving(plr.Character)
--     end)
--     if plr.Character then
--         self:OnCharacterAdded(plr.Character)
--     end
-- end
-- ----------------------------------------------

-- function ProductsController:KnitStart()
--     self:OnPlayerAdded(player)
--     self:BindInput()
--     self:BindDoubleJump()
--     self:BindGravity()
--     self:BindFly()
-- end

-- return ProductsController
