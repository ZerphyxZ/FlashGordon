local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))

local MarketplaceService = game:GetService("MarketplaceService")
local Knit               = Global.Knit
local Players            = Global.Players
local player             = Players.LocalPlayer
local workspace          = game:GetService("Workspace")

local ProductsController = Knit.CreateController({ Name = "ProductsController" })
local ProductsService    -- resolved in KnitStart

-- ── Public flags read by NewController ───────────────────────────────────────
-- HasFly is the single gate NewController.HandleHumanoidStates checks.
-- Both InfFlyBar AND legacy Fly set it when active so the existing fly logic works.
ProductsController.HasDoubleJump    = false
ProductsController.HasFastRespawn   = false
ProductsController.HasGravity       = false
ProductsController.HasDoubleLuck    = false
ProductsController.HasDoubleCoins   = false
ProductsController.HasDisablePopups = false
ProductsController.HasWorldPass     = false
ProductsController.HasInfFlyBar     = false
ProductsController.HasFly           = false  -- unified fly gate for NewController
ProductsController.flybar           = nil    -- EnergyBar Frame; NewController reads this each frame

-- ── Character / billboard refs ────────────────────────────────────────────────
local character, humanoid
local billboard, flyBarBackground

-- ── Physics constants ─────────────────────────────────────────────────────────
local DEFAULT_GRAVITY = workspace.Gravity
local REDUCED_GRAVITY = workspace.Gravity / 2

-- ── UI state rebuilt every respawn ───────────────────────────────────────────
local playerGui, gameHUD
local UI = {}  -- UI[productName] = { btn, timerLabel }

-- ─────────────────────────────────────────────────────────────────────────────
-- PRODUCT CONFIG TABLE
-- frameName / buttonName follow the GameHUD naming convention:
--   <frameName>Frame  →  <buttonName>Button  +  DurationTimer
-- onActivate / onExpire handle side-effects (gravity, flybar, etc.)
-- InfFlyBar and Fly both set HasFly = true so NewController's fly gate works.
-- ─────────────────────────────────────────────────────────────────────────────
local PRODUCT_CONFIG = {
    DoubleJump    = { flag = "HasDoubleJump",    frameName = "DoubleJump",    buttonName = "DoubleJump"    },
    FastRespawn   = { flag = "HasFastRespawn",   frameName = "FastRespawn",   buttonName = "FastRespawn"   },
    GravityCoil   = { flag = "HasGravity",       frameName = "Gravity",       buttonName = "Gravity",
        onActivate = function() workspace.Gravity = REDUCED_GRAVITY end,
        onExpire   = function() workspace.Gravity = DEFAULT_GRAVITY  end,
    },
    DoubleLuck    = { flag = "HasDoubleLuck",    frameName = "DoubleLuck",    buttonName = "DoubleLuck"    },
    DoubleCoins   = { flag = "HasDoubleCoins",   frameName = "DoubleCoins",   buttonName = "DoubleCoins"   },
    DisablePopups = { flag = "HasDisablePopups", frameName = "DisablePopups", buttonName = "DisablePopups" },
    WorldPass     = { flag = "HasWorldPass",     frameName = "WorldPass",     buttonName = "WorldPass"     },
    -- InfFlyBar: the main fly product (349 R$). Sets HasFly so NewController gates it.
    InfFlyBar = { flag = "HasInfFlyBar", frameName = "InfFlyBar", buttonName = "InfFlyBar",
        onActivate = function()
            ProductsController.HasFly = true          -- gate for NewController
            ProductsController:CreateFlyBar()
        end,
        onExpire = function()
            ProductsController.HasFly = false
            ProductsController:DestroyFlyBar()
        end,
    },
    -- Fly: legacy entry. Button now prompts InfFlyBar purchase.
    -- Still needs its own config entry so signal listeners work for rejoin restoration.
    Fly = { flag = "HasFly", frameName = "Fly", buttonName = "Fly",
        onActivate = function()
            ProductsController.HasFly = true
            ProductsController:CreateFlyBar()
        end,
        onExpire = function()
            ProductsController.HasFly = false
            ProductsController:DestroyFlyBar()
        end,
    },
}

-- Server-side signal names that map to each product
local SIGNAL_NAMES = {
    DoubleJump    = { activated = "DoubleJumpActivated",    expired = "DoubleJumpExpired"    },
    FastRespawn   = { activated = "FastRespawnActivated",   expired = "FastRespawnExpired"   },
    GravityCoil   = { activated = "GravityActivated",       expired = "GravityExpired"       },
    DoubleLuck    = { activated = "DoubleLuckActivated",    expired = "DoubleLuckExpired"    },
    DoubleCoins   = { activated = "DoubleCoinsActivated",   expired = "DoubleCoinsExpired"   },
    DisablePopups = { activated = "DisablePopupsActivated", expired = "DisablePopupsExpired" },
    WorldPass     = { activated = "WorldPassActivated",     expired = "WorldPassExpired"     },
    InfFlyBar     = { activated = "InfFlyBarActivated",     expired = "InfFlyBarExpired"     },
    Fly           = { activated = "FlyActivated",           expired = "FlyExpired"           },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- FLY BAR  (BillboardGui parented to humanoid, read by NewController.UpdateFlyBar)
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:CreateFlyBar()
    if billboard and billboard.Parent then return end  -- already exists

    billboard                      = Instance.new("BillboardGui")
    billboard.Name                 = "FlyEnergyBillboard"
    billboard.Parent               = humanoid  -- character-specific
    billboard.Size                 = UDim2.fromScale(0.85, 4)
    billboard.StudsOffsetWorldSpace = Vector3.new(3, -1.5, 0)
    billboard.AlwaysOnTop          = true
    billboard.LightInfluence       = 0
    billboard.ResetOnSpawn         = false

    flyBarBackground                        = Instance.new("Frame")
    flyBarBackground.Name                   = "Background"
    flyBarBackground.Parent                 = billboard
    flyBarBackground.Size                   = UDim2.fromScale(1, 1)
    flyBarBackground.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
    flyBarBackground.BackgroundTransparency = 0.2
    flyBarBackground.BorderSizePixel        = 0
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0.1, 0)
    bgCorner.Parent = flyBarBackground

    -- NewController.UpdateFlyBar reads ProductsController.flybar every PreRender frame
    -- and lerps its Size.Y.Scale based on flyEnergy ratio.
    -- AnchorPoint (0,1) + Position (0,1) = bar grows upward from the bottom.
    ProductsController.flybar                  = Instance.new("Frame")
    ProductsController.flybar.Name             = "EnergyBar"
    ProductsController.flybar.Parent           = flyBarBackground
    ProductsController.flybar.Size             = UDim2.fromScale(1, 1)
    ProductsController.flybar.AnchorPoint      = Vector2.new(0, 1)
    ProductsController.flybar.Position         = UDim2.fromScale(0, 1)
    ProductsController.flybar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    ProductsController.flybar.BorderSizePixel  = 0
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0.1, 0)
    barCorner.Parent = ProductsController.flybar
end

function ProductsController:DestroyFlyBar()
    if billboard then billboard:Destroy() end
    billboard                  = nil
    flyBarBackground           = nil
    ProductsController.flybar  = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ACTIVATE / EXPIRE
-- Both are idempotent — safe to call from signals AND from RestoreActiveProducts.
-- ─────────────────────────────────────────────────────────────────────────────
local function RunTimer(btn, label, endAt)
    task.spawn(function()
        while true do
            local left = math.max(0, math.ceil(endAt - tick()))
            if label then label.Text = left .. "s" end
            if left <= 0 then
                if label then label.Visible = false end
                if btn   then btn.Interactable = true end
                break
            end
            task.wait(1)
        end
    end)
end

-- `remainingSecs` = seconds from NOW until the product expires.
function ProductsController:ActivateProduct(productName, remainingSecs)
    local cfg = PRODUCT_CONFIG[productName]
    if not cfg then
        warn("[ProductsController] Unknown product:", productName)
        return
    end

    -- Guard: skip if already active (handles duplicate signal delivery)
    if ProductsController[cfg.flag] then
        print("[ProductsController] Already active, skipping:", productName)
        return
    end

    print(("[ProductsController] Activating %s for %ds"):format(productName, remainingSecs))
    ProductsController[cfg.flag] = true

    -- Update button / timer UI
    local slot  = UI[productName] or {}
    local btn   = slot[1]
    local timer = slot[2]
    if btn   then btn.Interactable = false end
    if timer then timer.Visible    = true  end

    -- Side-effects (gravity, fly bar, etc.)
    if cfg.onActivate then cfg.onActivate() end

    -- Visual countdown (tick()-based, survives multiple task.wait calls)
    local endAt = tick() + remainingSecs
    RunTimer(btn, timer, endAt)

    -- Local safety expiry timer so the product always ends even if the server
    -- Expired signal arrives slightly late or is dropped.
    task.delay(remainingSecs + 1, function()
        self:ExpireProduct(productName)
    end)
end

function ProductsController:ExpireProduct(productName)
    local cfg = PRODUCT_CONFIG[productName]
    if not cfg or not ProductsController[cfg.flag] then return end

    print("[ProductsController] Expiring:", productName)
    ProductsController[cfg.flag] = false

    local slot  = UI[productName] or {}
    local btn   = slot[1]
    local timer = slot[2]
    if timer then timer.Visible    = false end
    if btn   then btn.Interactable = true  end

    if cfg.onExpire then cfg.onExpire() end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UIReferences  (rebuilt each respawn so refs point to the new HUD instances)
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:UIReferences()
    playerGui = player:WaitForChild("PlayerGui")
    gameHUD   = playerGui:WaitForChild("GameHUD")

    UI = {}
    for productName, cfg in pairs(PRODUCT_CONFIG) do
        local frame = gameHUD:FindFirstChild(cfg.frameName .. "Frame")
        if frame then
            local btn   = frame:FindFirstChild(cfg.buttonName .. "Button")
            local timer = frame:FindFirstChild("DurationTimer")
            UI[productName] = { btn, timer }
        else
            UI[productName] = { nil, nil }
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ClearUI  (called on CharacterRemoving)
-- Resets all flags so RestoreActiveProducts can re-assert them cleanly.
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:ClearUI()
    playerGui, gameHUD = nil, nil
    UI = {}
    -- Flybar is parented to the old humanoid which is about to be destroyed
    ProductsController:DestroyFlyBar()
    -- Reset gravity in case it was reduced
    workspace.Gravity = DEFAULT_GRAVITY
    -- Reset all flags; RestoreActiveProducts on the next CharacterAdded re-sets them
    ProductsController.HasDoubleJump    = false
    ProductsController.HasFastRespawn   = false
    ProductsController.HasGravity       = false
    ProductsController.HasDoubleLuck    = false
    ProductsController.HasDoubleCoins   = false
    ProductsController.HasDisablePopups = false
    ProductsController.HasWorldPass     = false
    ProductsController.HasInfFlyBar     = false
    ProductsController.HasFly           = false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BindInput  (called per-respawn — old HUD buttons are destroyed so no duplicate fires)
--
-- BUG FIX: The legacy Fly button previously called ProductsService:PurchaseFly()
-- which granted the ability directly without opening a Robux purchase prompt.
-- It now calls PromptPurchase("InfFlyBar") — the correct Robux product.
-- ─────────────────────────────────────────────────────────────────────────────
local function PromptPurchase(productName)
    ProductsService:GetProductId(productName):andThen(function(success, productId)
        if success then
            MarketplaceService:PromptProductPurchase(player, productId)
        else
            warn("[ProductsController] No product ID configured for:", productName)
        end
    end):catch(function(err)
        warn("[ProductsController] GetProductId error:", err)
    end)
end

function ProductsController:BindInput()
    local function safe(slot, fn)
        local btn = slot and slot[1]
        if btn then btn.MouseButton1Click:Connect(fn) end
    end

    safe(UI.DoubleJump,    function() PromptPurchase("DoubleJump")    end)
    safe(UI.FastRespawn,   function() PromptPurchase("FastRespawn")   end)
    safe(UI.GravityCoil,   function() PromptPurchase("GravityCoil")   end)
    safe(UI.Gravity,       function() PromptPurchase("GravityCoil")   end)
    safe(UI.DoubleLuck,    function() PromptPurchase("DoubleLuck")    end)
    safe(UI.DoubleCoins,   function() PromptPurchase("DoubleCoins")   end)
    safe(UI.DisablePopups, function() PromptPurchase("DisablePopups") end)
    safe(UI.WorldPass,     function() PromptPurchase("WorldPass")     end)
    safe(UI.InfFlyBar,     function() PromptPurchase("InfFlyBar")     end)
    -- FIX: legacy Fly button → purchase prompt for InfFlyBar (not a free grant)
    safe(UI.Fly,           function() PromptPurchase("InfFlyBar")     end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BindSignals  (called ONCE in KnitStart — NOT per respawn)
--
-- Previous bug: BindSignals was called in OnCharacterAdded which meant every
-- respawn accumulated another set of listeners. On respawn #3 there would be
-- 3 timers running, gravity changed 3 times, 3 fly bars created, etc.
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:BindSignals()
    for productName, sigNames in pairs(SIGNAL_NAMES) do
        local activatedSig = ProductsService[sigNames.activated]
        local expiredSig   = ProductsService[sigNames.expired]

        if activatedSig then
            activatedSig:Connect(function(remaining)
                self:ActivateProduct(productName, remaining)
            end)
        end
        if expiredSig then
            expiredSig:Connect(function()
                self:ExpireProduct(productName)
            end)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- RestoreActiveProducts  (called on every CharacterAdded via task.defer)
--
-- Queries the server for all currently active timed products and re-activates
-- them on this client. This is the PRIMARY persistence mechanism:
--   • Respawn  → flags were cleared by ClearUI, this restores them
--   • Rejoin   → CheckTimedProductsAtStart fires during LoadProfile before the
--                client's signal listeners exist, so those signals are lost.
--                This method queries fresh data AFTER the client is ready.
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:RestoreActiveProducts()
    ProductsService:GetActiveProducts():andThen(function(active)
        if not active then return end
        for productName, remaining in pairs(active) do
            if remaining > 0 then
                self:ActivateProduct(productName, remaining)
            end
        end
    end):catch(function(err)
        warn("[ProductsController] RestoreActiveProducts error:", err)
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Character lifecycle
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:OnCharacterAdded(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")

    self:UIReferences()
    self:BindInput()

    -- Defer so Knit's remote bridge is fully ready before querying the server
    task.defer(function()
        self:RestoreActiveProducts()
    end)
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

-- ─────────────────────────────────────────────────────────────────────────────
-- KnitStart
-- ─────────────────────────────────────────────────────────────────────────────
function ProductsController:KnitStart()
    ProductsService = Knit.GetService("ProductsService")
    -- Bind signals ONCE here, before any character spawns
    self:BindSignals()
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
