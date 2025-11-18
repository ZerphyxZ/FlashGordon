local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local RunService = Global.RunService
local UserInputService = Global.UserInputService
local TweenService = Global.TweenService
local workspace = Global.Workspace
local ReplicatedStorage = Global.ReplicatedStorage
local HoverboardModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")

local HoverboardData = require(HoverboardModules:WaitForChild("Hoverboards"))
local HoverboardMovement = require(HoverboardModules:WaitForChild("HoverboardMovement"))
local HoverboardJump = require(HoverboardModules:WaitForChild("HoverboardJump"))
local HoverboardPhysics = require(HoverboardModules:WaitForChild("HoverboardPhysics"))
local GameHUD = require(HoverboardModules:WaitForChild("GameHUD"))
local HoverboardUtils = require(HoverboardModules:WaitForChild("HoverboardUtils"))

-- Create controller
local HoverboardController = Knit.CreateController({ Name = "HoverboardController" })
local HoverboardService

-- State
local character, humanoid, rootPart
local hoverboard, bodyVelocity, bodyGyro, bodyPosition
local runningConnection
local inputVector = Vector3.zero
local isOnHoverboard = false
local HOVERBOARD_OFFSET = Vector3.new(0, 0, 0)

--[[
   	Hoverboard Setup
]]
--

function HoverboardController:StartHoverboard(humanoid)
	if runningConnection then
		runningConnection:Disconnect()
	end

	GameHUD.CreateHUD()
	runningConnection = RunService.Heartbeat:Connect(function(dt)
		if not rootPart or not character then
			return
		end
		local moveDir = HoverboardMovement.HandleMovement(humanoid, rootPart, bodyVelocity, dt)
		HoverboardMovement.HandleRotation(rootPart, bodyGyro, moveDir, dt)
		HoverboardMovement.HandleLeaning(rootPart, hoverboard, dt, HOVERBOARD_OFFSET)
		HoverboardMovement.HandleHovering(character, rootPart, bodyPosition)
		HoverboardMovement.UpdateSurfaceAlignment(character, rootPart, bodyGyro, dt)
		HoverboardMovement.UpdateHoverboardOrientation(character, hoverboard, rootPart, dt)
		HoverboardJump.SetCurrentSpeed(HoverboardMovement.CurrentSpeed)
		HoverboardJump.UpdateLanding(dt) --Check for the ground detection
	end)

	GameHUD.UpdateSpeed(function()
		return HoverboardMovement.CurrentSpeed
	end)
end

function HoverboardController:SetActiveHoverboard(boardName)
	local config = HoverboardData.GetConfig(boardName)
	if not config then
		warn("[HoverboardController] Could not find hoverboard config for " .. tostring(boardName))
		return
	end
	self.ActiveConfig = config
end

function HoverboardController:WaitForHoverboard(humanoid)
	if not character then
		return
	end

	-- Check if we already have a hoverboard and are set up
	if hoverboard then
		print("Hoverboard: Hoverboard already existed")
		return
	end

	local hb = character:WaitForChild("Hoverboard", 5)
	if hb then
		print("Hoverboard: Hoverboard is assigned.")
		hoverboard = hb
		HoverboardController:StartHoverboard(humanoid)
	end
end

--[[
    State Management
]]
--
local function ResetStates()
	hoverboard = nil
	bodyVelocity = nil
	bodyGyro = nil
	bodyPosition = nil
end

local function CleanupHoverboard()
	print("Hoverboard: Clean up hoverboard called")
	isOnHoverboard = false
	HoverboardPhysics.Cleanup(hoverboard, bodyGyro, bodyVelocity, bodyPosition)
end

--[[
    Character Setup
]]
--
local function DisableAnimations(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
		track:Stop()
	end
	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end
	hum:ChangeState(Enum.HumanoidStateType.Physics)
end

local function OnCharacterAdded(char)
	character = char
	local humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	DisableAnimations(char)
	-- Physics must wait until hoverboard exists (server-created)
	HoverboardController:WaitForHoverboard(humanoid)
	-- Attach physics AFTER hoverboard arrives
	task.defer(function()
		if hoverboard and rootPart then
			bodyVelocity, bodyGyro, bodyPosition = HoverboardPhysics.AttachPhysics(rootPart)
			HoverboardJump.SetReferences(hoverboard, character, rootPart, bodyPosition)
			HoverboardJump.SetHoverHeight(5)
		end
	end)
end

local function OnCharacterRemoving()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	HoverboardPhysics.Cleanup(hoverboard, bodyVelocity, bodyGyro, bodyPosition)
	GameHUD.Cleanup()
	hoverboard, bodyVelocity, bodyGyro, bodyPosition = nil, nil, nil, nil
end

local function OnPlayerAdded(plr)
	if plr ~= player then
		return
	end
	plr.CharacterAdded:Connect(OnCharacterAdded)
	plr.CharacterRemoving:Connect(OnCharacterRemoving)
	if plr.Character then
		OnCharacterAdded(plr.Character)
	end
end

--[[
    Knit Lifecycle
]]
--

function HoverboardController:KnitInit()
	print("HoverboardController initialized")
end

function HoverboardController:KnitStart()
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner == player then
			self:SetActiveHoverboard(boardName)
			task.defer(function()
				local offsetY = HoverboardService:GetBoardOffset():expect()
				if typeof(offsetY) == "number" then
					HOVERBOARD_OFFSET = Vector3.new(0, -offsetY, 0)
					print("Client received board offset:", offsetY)
				end
				self:WaitForHoverboard()
			end)
		end
	end)
	HoverboardService.HoverboardRemoved:Connect(function()
		ResetStates()
		CleanupHoverboard()
	end)
	OnPlayerAdded(player)
	HoverboardUtils.BindInput(player)
end

return HoverboardController
