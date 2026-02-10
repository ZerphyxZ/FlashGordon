local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))

local TweenService = game:GetService("TweenService")
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local GUILoader = Knit.CreateController({
    Name = "GUILoader"
})

local playerGui = player:WaitForChild("PlayerGui")
local gameHUD = playerGui:WaitForChild("GameHUD")
local mainMenu = playerGui:WaitForChild("MainGui")

local function EnableAllPlayerGUIs(enable)
    local playerGui = player:WaitForChild("PlayerGui")

    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("ScreenGui") then
            gui.Enabled = enable
        end
    end
end

local function ToggleAllGuiObjects(visible)
    local playerGui = player:WaitForChild("PlayerGui")

    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            gui.Enabled = true -- keep ScreenGui enabled

            for _, ui in ipairs(gui:GetDescendants()) do
                if ui:IsA("GuiObject") then
                    ui.Visible = visible
                end
            end
        end
    end
end

function GUILoader:KnitStart()
    print("GUILoader started")
    -- ToggleAllGuiObjects(true)
    -- --EnableAllPlayerGUIs(true)
    -- task.wait(0.01) -- Wait a moment to ensure everything is loaded
    -- ToggleAllGuiObjects(false)
    -- --EnableAllPlayerGUIs(false)
    -- gameHUD.Enabled = true
    -- mainMenu.Enabled = true
end

return GUILoader