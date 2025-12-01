--// HoverboardUtils.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HoverboardUtils = {}

local JumpConnections = {
	JumpRequest = nil,
	InputEnded = nil,
	Heartbeat = nil,
}

local function EnableJumpInput(HoverboardJump)
	-- Prevent duplicates
	if JumpConnections.JumpRequest then return end

	JumpConnections.JumpRequest = UserInputService.JumpRequest:Connect(function()
		HoverboardJump.State.isJumpHeld = true
		HoverboardJump.AttemptJump()
	end)

	JumpConnections.InputEnded = UserInputService.InputEnded:Connect(function(input, gp)
		if input.KeyCode == Enum.KeyCode.Space then
			HoverboardJump.State.isJumpHeld = false
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			HoverboardJump.State.isJumpHeld = false
		end
	end)

	JumpConnections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
		HoverboardJump.UpdateJump(HoverboardJump.State.moveDir, dt)
	end)

	print("Jump Input ENABLED")
end

local function DisableJumpInput()
	for key, conn in pairs(JumpConnections) do
		if conn then conn:Disconnect() end
		JumpConnections[key] = nil
	end

	print("Jump Input DISABLED")
end

function HoverboardUtils.BindJump(HoverboardJump)
	EnableJumpInput(HoverboardJump)
end

function HoverboardUtils.UnBindJump()
	DisableJumpInput()
end

return HoverboardUtils