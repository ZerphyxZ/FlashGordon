--// HoverboardHUD.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HoverboardHUD = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui
local speedLabel
local connection

function HoverboardHUD.CreateHUD()
	-- Create GUI if not already created
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HoverboardHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(0, 200, 0, 50)
	speedLabel.Position = UDim2.new(0.5, -100, 0.9, 0)
	speedLabel.BackgroundTransparency = 0
	speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedLabel.TextScaled = true
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.Text = "Speed: 0"
	speedLabel.Parent = screenGui
end

function HoverboardHUD.UpdateSpeed(getSpeedFunc)
	if connection then connection:Disconnect() end

	connection = RunService.Heartbeat:Connect(function()
		if not speedLabel then return end
		local speed = getSpeedFunc()
		speedLabel.Text = string.format("Speed: %.0f", speed or 0)
	end)
end

function HoverboardHUD.Cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return HoverboardHUD