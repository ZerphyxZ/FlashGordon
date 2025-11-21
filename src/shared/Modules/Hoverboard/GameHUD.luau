--// HoverboardHUD.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HoverboardHUD = {}
local player = Players.LocalPlayer
local mainGUI = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local speedGUI = mainGUI:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
local connection

function HoverboardHUD.UpdateSpeed(getSpeedFunc)
	if connection then connection:Disconnect() end

	connection = RunService.Heartbeat:Connect(function()
		local speed = getSpeedFunc()
		speedLabel.Text = string.format("Speed: %.0f", speed or 0)
	end)
end

function HoverboardHUD.Cleanup(speedGui)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if speedGui then
		speedGui:Destroy()
		speedGui = nil
	end
end

return HoverboardHUD


