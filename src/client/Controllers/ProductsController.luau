local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))

local TweenService = game:GetService("TweenService")
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
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


---------------------- Common functions ------------------------
function ProductsController:UIReferences()
    playerGui = player:WaitForChild("PlayerGui")
    gameHUD = playerGui:WaitForChild("GameHUD")
    doubleJumpButton = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DoubleJumpButton")
    doubleJumpDuration = gameHUD:WaitForChild("DoubleJumpFrame"):WaitForChild("DurationTimer")
    flyButton = gameHUD:WaitForChild("FlyFrame"):WaitForChild("FlyButton")
end

function ProductsController:BindInput()
    doubleJumpButton.MouseButton1Click:Connect(function()
        ProductsController:RequestDoubleJump()
    end)

    flyButton.MouseButton1Click:Connect(function()
        ProductsController:RequestFly()
    end)
end

function ProductsController:BindDoubleJump()
    ProductsService.DoubleJumpActivated:Connect(function(endTime)
        print("Double Jump Activated until:", endTime)
        doubleJumpButton.Interactable = false
        doubleJumpDuration.Visible = true

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
end

return ProductsController
