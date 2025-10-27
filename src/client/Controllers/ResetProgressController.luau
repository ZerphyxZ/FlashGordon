-- ResetProgressController.luau (client) - robust to MainGui recreation
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local ResetProgressController = Knit.CreateController { Name = "ResetProgressController" }

local player = Players.LocalPlayer

local playerGuiConn = nil

-- dynamic refs
local RestartFrame, RestartButtonFrame, RestartProgressButton, CloseButton
local SureRestartFrame, SureCloseButton, YesRestartProgressButton, NoRestartProgressButton

local function bindGui()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return end
    local mainGui = gui:FindFirstChild("MainGui")
    if not mainGui then return end

    RestartFrame = mainGui:FindFirstChild("RestartFrame")
    if RestartFrame then
        RestartButtonFrame = RestartFrame:FindFirstChild("RestartButtonFrame")
        RestartProgressButton = RestartButtonFrame and RestartButtonFrame:FindFirstChild("RestartProgressButton")
        CloseButton = RestartFrame:FindFirstChild("CloseButtonFrame") and RestartFrame:FindFirstChild("CloseButtonFrame"):FindFirstChild("CloseButton")
    end

    SureRestartFrame = mainGui:FindFirstChild("SureRestartFrame")
    if SureRestartFrame then
        SureCloseButton = SureRestartFrame:FindFirstChild("SureCloseButtonFrame") and SureRestartFrame:FindFirstChild("SureCloseButtonFrame"):FindFirstChild("SureCloseButton")
        YesRestartProgressButton = SureRestartFrame:FindFirstChild("YesRestartButtonFrame") and SureRestartFrame:FindFirstChild("YesRestartButtonFrame"):FindFirstChild("YesRestartProgressButton")
        NoRestartProgressButton = SureRestartFrame:FindFirstChild("NoRestartButtonFrame") and SureRestartFrame:FindFirstChild("NoRestartButtonFrame"):FindFirstChild("NoRestartProgressButton")
    end

    -- Ensure start hidden if present
    if RestartFrame then RestartFrame.Visible = false end
    if SureRestartFrame then SureRestartFrame.Visible = false end

    -- (re)connect button handlers (unbind previous by creating new connections local to elements)
    -- Note: simple and robust approach: reconnect by setting new Connects; we don't hold explicit handles here
    if CloseButton then
        CloseButton.MouseButton1Click:Connect(function()
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
        end)
    end

    if RestartProgressButton then
        RestartProgressButton.MouseButton1Click:Connect(function()
            if RestartFrame and SureRestartFrame then
                RestartFrame.Visible = false
                SureRestartFrame.Visible = true
            end
        end)
    end

    if SureCloseButton then
        SureCloseButton.MouseButton1Click:Connect(function()
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
        end)
    end

    if NoRestartProgressButton then
        NoRestartProgressButton.MouseButton1Click:Connect(function()
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
        end)
    end

    if YesRestartProgressButton then
        YesRestartProgressButton.MouseButton1Click:Connect(function()
            YesRestartProgressButton.Active = false
            YesRestartProgressButton.AutoButtonColor = false

            local resetService = Knit.GetService("ResetProgressService")
            if not resetService then
                warn("[ResetProgressController] ResetProgressService not found")
                YesRestartProgressButton.Active = true
                YesRestartProgressButton.AutoButtonColor = true
                return
            end

            local result = resetService:RequestReset()
            if result == true then
                print("[ResetProgressController] Reset requested; awaiting server confirmation (ResetResult attribute).")
            else
                warn("[ResetProgressController] Reset request returned false (server could not start reset).")
                YesRestartProgressButton.Active = true
                YesRestartProgressButton.AutoButtonColor = true
            end

            task.delay(3, function()
                YesRestartProgressButton.Active = true
                YesRestartProgressButton.AutoButtonColor = true
            end)
        end)
    end
end

function ResetProgressController:KnitStart()
    print("[ResetProgressController] KnitStart called (client)")

    -- bind now if possible
    bindGui()

    -- rebind when MainGui is recreated
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        if playerGuiConn then playerGuiConn:Disconnect() end
        playerGuiConn = gui.ChildAdded:Connect(function(child)
            if child and child.Name == "MainGui" then
                task.delay(0.05, bindGui)
            end
        end)
    else
        task.spawn(function()
            local g = player:WaitForChild("PlayerGui")
            playerGuiConn = g.ChildAdded:Connect(function(child)
                if child and child.Name == "MainGui" then
                    task.delay(0.05, bindGui)
                end
            end)
        end)
    end

    -- React to ResetUI attribute changes (use dynamic refs)
    player:GetAttributeChangedSignal("ResetUI"):Connect(function()
        local val = player:GetAttribute("ResetUI")
        if val == true then
            if RestartFrame then
                RestartFrame.Visible = true
                if SureRestartFrame then SureRestartFrame.Visible = false end
            end
        else
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
        end
    end)

    -- React to ResetResult attribute changes
    player:GetAttributeChangedSignal("ResetResult"):Connect(function()
        local result = player:GetAttribute("ResetResult")
        local msg = player:GetAttribute("ResetResultMsg")
        if result == "Success" then
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
            print("[ResetProgressController] Reset succeeded:", tostring(msg))
        elseif result == "Failure" then
            if RestartFrame then RestartFrame.Visible = false end
            if SureRestartFrame then SureRestartFrame.Visible = false end
            warn("[ResetProgressController] Reset failed:", tostring(msg))
        end
    end)

    -- initial attribute check
    if player:GetAttribute("ResetUI") == true then
        if RestartFrame then RestartFrame.Visible = true end
    end
end

return ResetProgressController
