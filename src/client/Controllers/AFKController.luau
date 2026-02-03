--// AFKController.lua
-- Client-side Knit Controller for:
-- - Opening/closing AFKScreen
-- - Disabling/enabling player input
-- - Telling AFKService when AFK is toggled

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local player = Players.LocalPlayer

local AFKController = Knit.CreateController {
    Name = "AFKController",
}

AFKController._isAFK = false
AFKController._controls = nil
AFKController._afkService = nil

AFKController._itemAFKButton = nil
AFKController._afkScreen = nil
AFKController._skipButton = nil


-- Internal: set AFK on (UI + controls + service call)
function AFKController:_EnterAFK()
    if self._isAFK then
        return
    end

    self._isAFK = true

    if self._afkScreen then
        self._afkScreen.Enabled = true
    end

    if self._controls then
        self._controls:Disable()
    end

    if self._afkService then
        self._afkService:SetAFK(true)
    end
end


-- Internal: set AFK off (UI + controls + service call)
function AFKController:_ExitAFK()
    if not self._isAFK then
        return
    end

    self._isAFK = false

    if self._afkScreen then
        self._afkScreen.Enabled = false
    end

    if self._controls then
        self._controls:Enable()
    end

    if self._afkService then
        self._afkService:SetAFK(false)
    end
end


function AFKController:KnitStart()
    -- Get the service
    self._afkService = Knit.GetService("AFKService")

    -- Grab UI from PlayerGui, not StarterGui
    local playerGui = player:WaitForChild("PlayerGui")
    local gameHUD = playerGui:WaitForChild("GameHUD")

    local itemsFrame = gameHUD:WaitForChild("ItemsLeft")
    self._itemAFKButton = itemsFrame:WaitForChild("AFK")

    self._afkScreen = playerGui:WaitForChild("AFK")
    local mainFrame = self._afkScreen:WaitForChild("MainFrame")
    self._skipButton = mainFrame:WaitForChild("SkipButton")

    -- Make sure AFKScreen starts hidden
    self._afkScreen.Enabled = false

    -- Disable movement using the built-in PlayerModule controls
    local playerScripts = player:WaitForChild("PlayerScripts")
    local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
    self._controls = playerModule:GetControls()

    -- Connect UI
    self._itemAFKButton.MouseButton1Click:Connect(function()
        self:_EnterAFK()
    end)

    self._skipButton.MouseButton1Click:Connect(function()
        self:_ExitAFK()
    end)
end


return AFKController
