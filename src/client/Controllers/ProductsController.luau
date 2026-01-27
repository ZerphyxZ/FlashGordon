local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))

local TweenService = game:GetService("TweenService")
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local workspace = game:GetService("Workspace")
local ProductsController = Knit.CreateController({
    Name = "ProductsController",
})
local ProductsService

--UI References
local playerGui
local gameHUD
local doubleJumpButton
local doubleJumpDuration
local flyButton
local flyDuration
local gravityButton
local gravityDuration

ProductsController.HasDoubleJump = true
ProductsController.HasFly = true
ProductsController.HasGravity = false

local DEFAULT_GRAVITY = workspace.Gravity
local REDUCED_GRAVITY = workspace.Gravity / 2.5

---------------------- Common functions ------------------------
function ProductsController:UIReferences()
    playerGui = player:WaitForChild("PlayerGui")
    gameHUD = playerGui:WaitForChild("GameHUD")
    doubleJumpButton = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DoubleJumpButton")
    doubleJumpDuration = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DurationTimer")
    flyButton = gameHUD:WaitForChild("FlyFrame"):WaitForChild("FlyButton")
    gravityButton = gameHUD:WaitForChild("GravityFrame"):WaitForChild("GravityButton")
    gravityDuration = gameHUD:WaitForChild("GravityFrame"):WaitForChild("DurationTimer")
end

function ProductsController:BindInput()
    doubleJumpButton.MouseButton1Click:Connect(function()
        self:RequestDoubleJump()
    end)

    flyButton.MouseButton1Click:Connect(function()
        self:RequestFly()
    end)

    gravityButton.MouseButton1Click:Connect(function()
        self:RequestGravity()
    end)
end

function ProductsController:BindTimedProduct(options)
    local activatedSignal = options.Activated
    local expiredSignal = options.Expired
    local button = options.Button
    local label = options.Label
    local onActivate = options.OnActivate
    local onExpire = options.OnExpire

    activatedSignal:Connect(function(endTime)
        print(options.Name .. " Activated until:", endTime)
        if button then 
            button.Interactable = false 
        end
        if label then 
            label.Visible = true 
        end 
        if onActivate then 
            onActivate() 
        end

        task.spawn(function()
            while true do
                local timeLeft = endTime - os.time()
                if timeLeft <= 0 then
                    if label then
                        label.Text = "0s"
                        label.Visible = false
                    end
                    if button then
                        button.Interactable = true
                    end
                    break
                end
                if label then 
                    label.Text = timeLeft .. "s" 
                end
                task.wait(1)
            end
        end)
    end)

    expiredSignal:Connect(function()
        print(options.Name .. " Expired.")
        if label then 
            label.Visible = false 
        end
        if button then 
            button.Interactable = true 
        end
        if onExpire then 
            onExpire()
        end
    end)
end

function ProductsController:BindDoubleJump()
    ProductsService.DoubleJumpActivated:Connect(function(endTime)
        print("Double Jump Activated until:", endTime)
        doubleJumpButton.Interactable = false
        doubleJumpDuration.Visible = true
        ProductsController.HasDoubleJump = true

        -- Update duration timer
        local function updateTimer()
            local timeLeft = endTime - os.time()
            if timeLeft < 0 then
                doubleJumpDuration.Text = "0s"
                doubleJumpButton.Interactable = true
                doubleJumpDuration.Visible = false
                return
            end
            doubleJumpDuration.Text = tostring(timeLeft) .. "s"
            task.delay(1, updateTimer)
        end
        updateTimer()
    end)

    ProductsService.DoubleJumpExpired:Connect(function()
        print("Double Jump Expired.")
        ProductsController.HasDoubleJump = false
    end)
end

function ProductsController:BindGravity()
    ProductsService.GravityActivated:Connect(function(endTime)
        print("Gravity Activated until:", endTime)
        gravityButton.Interactable = false
        gravityDuration.Visible = true
        ProductsController.HasGravity = true
        workspace.Gravity = REDUCED_GRAVITY

        -- Update duration timer
        local function updateTimer()
            local timeLeft = endTime - os.time()
            if timeLeft < 0 then
                gravityDuration.Text = "0s"
                gravityButton.Interactable = true
                gravityDuration.Visible = false
                return
            end
            gravityDuration.Text = tostring(timeLeft) .. "s"
            task.delay(1, updateTimer)
        end
        updateTimer()
    end)

    ProductsService.GravityExpired:Connect(function()
        print("Gravity Expired.")
        ProductsController.HasGravity = false
        workspace.Gravity = DEFAULT_GRAVITY
    end)
end
-------------------------------------------------------

--------------------- Client callable functions -----------------
function ProductsController:RequestDoubleJump()
    print("Double Jump Requested.")
    ProductsService:PurchaseDoubleJump()
end

function ProductsController:RequestFly()
    print("Fly Requested.")
    ProductsService:PurchaseFly()
end

function ProductsController:RequestGravity()
    print("Gravity Requested.")
    ProductsService:PurchaseGravity()
end
-------------------------------------------------------


-- Player lifecycle methods
function ProductsController:OnCharacterAdded(character)
    ProductsService = Knit.GetService("ProductsService")
    self:UIReferences()
end

function ProductsController:OnCharacterRemoving(character)

end

function ProductsController:OnPlayerAdded(plr)
    if plr ~= player then
		return
	end
	plr.CharacterAdded:Connect(function()
		self:OnCharacterAdded(plr.Character)
	end)
	plr.CharacterRemoving:Connect(function()
		self:OnCharacterRemoving(plr.Character)
	end)
	if plr.Character then
		self:OnCharacterAdded(plr.Character)
	end
end
----------------------------------------------

function ProductsController:KnitStart()
    self:OnPlayerAdded(player)
    self:BindInput()
    self:BindDoubleJump()
    self:BindGravity()
end

return ProductsController
