--// HoverboardUtils.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HoverboardJump = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules")
	:WaitForChild("Hoverboard"):WaitForChild("HoverboardJump"))

local HoverboardUtils = {}
HoverboardUtils.MoveVector = Vector3.zero

local function SetupHumanoidTracking(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Update MoveVector every frame based on humanoid MoveDirection
	RunService.Heartbeat:Connect(function()
		if humanoid and humanoid.Parent then
			local dir = humanoid.MoveDirection
			if dir.Magnitude > 0.05 then
				HoverboardUtils.MoveVector = dir
			else
				HoverboardUtils.MoveVector = Vector3.zero
			end
		else
			HoverboardUtils.MoveVector = Vector3.zero
		end
	end)

	-- Jump input handling
	UserInputService.JumpRequest:Connect(function()
		print("Jump requested!")
		HoverboardJump.State.isJumpHeld = true
		HoverboardJump.AttemptJump()

		-- Start checking for hold-to-fly
		--while isJumpHeld do
		--	task.wait()
		--	local holdDuration = tick() - jumpHoldStartTime
		--	if holdDuration >= JUMP_HOLD_THRESHOLD then
		--		HoverboardJump.StartFlying()
		--		break
		--	end
		--end
	end)

	-- Handle jump release
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Space then
			print("Got here")
			HoverboardJump.State.isJumpHeld = false
			--HoverboardJump.StopFlying()
		end

		-- Check for touch input (mobile)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- For mobile, we need to check if this was a jump touch
			if HoverboardJump.State.isJumpHeld then
				HoverboardJump.State.isJumpHeld = false
				--HoverboardJump.StopFlying()
			end
		end
	end)


end

local function SetupJumpUpdate()
	RunService.Heartbeat:Connect(function(deltaTime)
		HoverboardJump.UpdateJump(deltaTime)
	end)
end

function HoverboardUtils.BindInput(player)
	SetupHumanoidTracking(player)
	SetupJumpUpdate() -- Start the jump/fly update loop

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		SetupHumanoidTracking(player)
	end)
end

return HoverboardUtils





----// HoverboardUtils.lua
--local Players = game:GetService("Players")
--local RunService = game:GetService("RunService")
--local UserInputService = game:GetService("UserInputService")

--local HoverboardJump = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules")
--	:WaitForChild("Hoverboard"):WaitForChild("HoverboardJump"))

--local HoverboardUtils = {}
--HoverboardUtils.MoveVector = Vector3.zero

--local function setupHumanoidTracking(player)
--	local character = player.Character or player.CharacterAdded:Wait()
--	local humanoid = character:WaitForChild("Humanoid")

--	-- Update MoveVector every frame based on humanoid MoveDirection
--	RunService.Heartbeat:Connect(function()
--		if humanoid and humanoid.Parent then
--			local dir = humanoid.MoveDirection
--			if dir.Magnitude > 0.05 then
--				HoverboardUtils.MoveVector = dir
--			else
--				HoverboardUtils.MoveVector = Vector3.zero
--			end
--		else
--			HoverboardUtils.MoveVector = Vector3.zero
--		end
--	end)

--	UserInputService.JumpRequest:Connect(function()
--		print("Jump requested!")
--		HoverboardJump.AttemptJump()
--	end)

--end

--function HoverboardUtils.BindInput(player)
--	setupHumanoidTracking(player)

--	player.CharacterAdded:Connect(function()
--		task.wait(0.1)
--		setupHumanoidTracking(player)
--	end)
--end

--function HoverboardUtils.BindJump()
--	game:GetService("UserInputService").JumpRequest:Connect(function()
--		-- Handle jump logic here
--		print("Jump requested!")
--		HoverboardJump.AttemptJump()
--	end)
--end


--return HoverboardUtils