local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local NewController = Knit.CreateController({ Name = "NewController" })
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local character
local humanoid
local Board
local rootPart
local bodyVelocity
local bodyGyro
local bodyPosition
local Camera = workspace.Camera
local Config

-- MODULES
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local HoverboardModules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")
local HoverboardData = require(Configuration:WaitForChild("HoverboardData"))
local Speed = require(HoverboardModules:WaitForChild("HoverboardSpeed"))
local BoostAbility = require(HoverboardModules:WaitForChild("HoverboardBoost"))
--local DashAbility = require(HoverboardModules:WaitForChild("HoverboardDash"))
--local cameraFOV = require(HoverboardModules:WaitForChild("CameraFOV"))
local HoverboardService

-- MOVEMENT / HOVERING
local HoverStiffness = 10
local HoverHeight = 3.5

-- MOVEMENT / ORIENTATION
local OgBoardRotation --= Board.CFrame.Rotation.Y
local LastMovedirection = nil
local CameraHeld = false
local newNormal
local MaxCharacterRotation = 90
local ForwardLean = 0
local RotateDirection = 0
local HorizontalLean = 25
local BoardRotation --= OgBoardRotation
local InstantTurn = false
local Rayvelocity = 0.2
local SmoothBoardRotation --= OgBoardRotation
local SmoothHorizontalLean = 0
local SmoothForwardLean = 0
local SmoothingSpeed = 14   -- higher = faster smoothing
local HorizontalSmoothingSpeed = 240

-- CONSTANT VALUES
local HORIZONTAL_LEAN_AMOUNT = 35
local FORWARD_LEAN_AMOUNT = 0
local ROTATION_AMOUNT = 30
local JUMP_POWER = 70
local INSTANT_TURN_SMOOTHING = 0.02
local NORMAL_TURN_SMOOTHING = 4
local MAX_SPEED = 100
local ACCELERATION = 0.3
local DECELERATION = 150
local MOVEMENT_SMOOTHNESS = 0.5

local currentAccelerationRef = { value = ACCELERATION }
local currentTopSpeedRef = { value = MAX_SPEED }

-- MOVEMENT / SPEED
local IsDecelerating = false
local Diff = 0.01
local SpeedVar = 0
local CurrentSpeed = 0
local acceleration --= Config:GetAttribute("Acceleration") or ACCELERATION
local topSpeed --= Config:GetAttribute("MaxSpeed") or MAX_SPEED
local jumpPower --= Config:GetAttribute("JumpPower") or JUMP_POWER

-- JUMP
local Jump = false
local LastJump = false
local CanJump = false
local AirJumps = 1

-- CONNECTIONS
local runningConnection

-- State
local hoverboard
local runningConnection
local isOnHoverboard = false
local isHoverboardInitialized = false

-- SPEED REFERENCES
local MAX_BARS = 10
local MAX_BAR_HEIGHT = 0.6
local MAX_BAR_WIDTH = 0.08
local BASE_TWEEN_DURATION = 1
local SMOOTHING_FACTOR = 0.18     -- how smooth the bar grows
local TWEEN_EASING = Enum.EasingStyle.Quad
local TWEEN_DIR = Enum.EasingDirection.Out

local MIN_FOV = 70
local MAX_FOV = 100

local speedBars = {}

-- UI References
local playerGUI = player:WaitForChild("PlayerGui")
local gameHUD = playerGUI:WaitForChild("GameHUD")
local mainGUI = playerGUI:WaitForChild("MainGui")
local speedGUI = gameHUD:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
local bars = speedGUI:WaitForChild("Bars")

local controls
local function GetControls()
	if controls then
		return controls
	end
	local playerScripts = player:WaitForChild("PlayerScripts")
	controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
	return controls
end

local function InitBodyMovers()
	bodyVelocity = Instance.new("BodyVelocity")
	bodyGyro = Instance.new("BodyGyro")
	bodyPosition = Instance.new("BodyPosition")
	
	bodyPosition.MaxForce = Vector3.new(2e9, 2e9, 2e9)
	bodyPosition.Position = rootPart.Position

	bodyGyro.MaxTorque = Vector3.new(2e9, 2e9, 2e9)
	bodyGyro.Parent = Board

	bodyVelocity.MaxForce = Vector3.new(2e9, 0, 2e9)
	bodyVelocity.Parent = Board
end


------------------- UPDATE SPEED GUI -----------------------
local TWEEN_INFO = TweenInfo.new(
	BASE_TWEEN_DURATION,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local function GetTweenInfo()
	local duration = BASE_TWEEN_DURATION * SMOOTHING_FACTOR
	return TweenInfo.new(duration, TWEEN_EASING, TWEEN_DIR)
end

local function LoadSpeedGUI()
	speedBars = {}
	for i = 1, MAX_BARS do
		local bar = bars:WaitForChild("Bar"..i)
		table.insert(speedBars, bar)
		bar.Visible = true
		bar.Size = UDim2.new(0, 0, MAX_BAR_HEIGHT, 0)
	end
end

local function AnimateFrame(frame, scale, visible)
	local tweenInfo = GetTweenInfo()
	TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(scale, 0, MAX_BAR_HEIGHT, 0)
	}):Play()
	frame.Visible = visible
end

function UpdateSpeedGUI(MaxSpeed)
	local Speed
	
	if SpeedVar then
		if tonumber(SpeedVar) >= 0 then
			Speed = SpeedVar
		else
			Speed = SpeedVar * -1
		end
		if Speed and Speed / MaxSpeed < 1 then
			speedLabel.Text = string.format("Speed: %.0f", math.round(Speed) or 0) 
		else
			speedLabel.Text = string.format("Speed: %.0f", math.round(Speed) or 0)
		end
	end
	
	
	
	
	
	--local maxSpeed = currentTopSpeedRef.value
	--if not maxSpeed or maxSpeed <= 0 then return end

	---- Round up to nearest multiple of 10
	----local maxSpeed = math.ceil(maxSpeed / 10) * 10

	--speedLabel.Text = string.format("Speed: %.0f", SpeedVar or 0)
	--local segment = maxSpeed / 12  -- threshold per frame
	--for i = 1, MAX_BARS do
	--	local threshold = segment * i

	--	if SpeedVar >= threshold then
	--		AnimateFrame(speedBars[i], MAX_BAR_WIDTH, true, CurrentSpeed)	-- expand to full size
	--	else
	--		AnimateFrame(speedBars[i], 0, false, CurrentSpeed)	-- collapse smoothly
	--	end
	--end
end
-----------------------------------------------------------


--------- ------ CONTROLLER METHODS -----------------------
local function ReturnAngleBetweenVectors(VectorOne, VectorTwo, Plane: "XY" | "XZ" | "YZ" | nil)
	local PlaneNormal = Vector3.one

	if Plane == "XY" then
		PlaneNormal = Vector3.new(1, 1, 0)
	elseif Plane == "XZ" then
		PlaneNormal = Vector3.new(1, 0, 1) 
	elseif Plane == "YZ" then
		PlaneNormal = Vector3.new(0, 1, 1)
	end 

	VectorOne = VectorOne * PlaneNormal
	VectorTwo = VectorTwo * PlaneNormal

	if VectorOne.Magnitude == 0 or VectorTwo.Magnitude == 0 then
		return 0, 0
	end

	local DotProduct = VectorOne:Dot(VectorTwo) / (VectorOne.Magnitude * VectorTwo.Magnitude)
	DotProduct = math.clamp(DotProduct, -1, 1)
	local Angle = math.acos(DotProduct)
	local AngleInDegrees = math.deg(Angle)

	return Angle, AngleInDegrees
end

local function ReturnDirectionAndTiltAngle(ReferenceVector: Vector3, OtherVector: Vector3, NormalVector: Vector3 ?)
	NormalVector = NormalVector or Vector3.yAxis

	local crossProduct = ReferenceVector:Cross(OtherVector)
	local direction = crossProduct:Dot(NormalVector) >= 0 and 1 or -1

	ReferenceVector *= Vector3.new(1, 0, 1)
	OtherVector = OtherVector * Vector3.new(1, 0, 1)

	local dotProduct = ReferenceVector:Dot(OtherVector)
	local normalizedDotProduct = math.clamp( dotProduct / (ReferenceVector.Magnitude * OtherVector.Magnitude), -1, 1)
	local angle = math.deg(math.acos(normalizedDotProduct))


	return direction, angle
end


local function GetGoal(MoveDirection)
	local Goal

	if MoveDirection.Z < 0 and MoveDirection.X == 0 then
		Goal = (Camera.CFrame * CFrame.new(0, 0, -1000)).Position
	elseif MoveDirection.Z > 0 then
		Goal = (Camera.CFrame * CFrame.new(0, 0, 1000)).Position
	elseif MoveDirection.Z < 0 and MoveDirection.X ~= 0 then
		Goal = (Camera.CFrame * CFrame.new(0, 0, -1000)).Position
	elseif MoveDirection.Z == 0 and MoveDirection.X > 0 then
		Goal = (Camera.CFrame * CFrame.new(1000, 0, 0)).Position
	elseif MoveDirection.Z == 0 and MoveDirection.X < 0 then
		Goal = (Camera.CFrame * CFrame.new(-1000, 0, 0)).Position
	else
		Goal = (rootPart.CFrame * CFrame.new(0, 0, -1000)).Position
	end

	return Goal
end

local function IsFacingRightDirection(currentForward, goalForward)
	local dotProduct = currentForward:Dot(goalForward)
	local angle = math.acos(dotProduct)
	local angleInDegrees = math.deg(angle)
	return angleInDegrees
end

local function SetCharacterOrientation(Normal : Vector3, DeltaTime)
	controls = GetControls()
	local MoveDirection = controls:GetMoveVector()
	local BoardCF = Board.CFrame
	local Origin = Board.Position + BoardCF.LookVector + Board.AssemblyLinearVelocity * Rayvelocity
	local Direction = Vector3.new(0, -1, 0)
	local CheckingDistance = HoverHeight + 4
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.FilterDescendantsInstances = { Board, character }
	local SwaySpeed = 0 --2
	local MaxSwayAngle = 0 --1.5
	local TiltAngle = math.sin(tick() * SwaySpeed) * MaxSwayAngle
	local newNormal
	local LerpFactor = 0.8
	local Goal = GetGoal(MoveDirection)

	if Goal then

		local RaycastResult = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)

		if ForwardLean ~= 0 then
			TiltAngle = ForwardLean
		end

		if RaycastResult then
			newNormal = RaycastResult.Normal
		else
			newNormal = Normal
		end

		if newNormal then

			local Goal = Vector3.new(Goal.X, Origin.Y, Goal.Z)
			local LookVector = CFrame.new(Origin, Goal).LookVector
			local RightVector = LookVector:Cross(newNormal).Unit
			local UpVector = newNormal
			local AlignedCFrame = CFrame.fromMatrix(rootPart.Position, RightVector, UpVector)

            local deltaFactor = 4

			if InstantTurn and tonumber(SpeedVar) <= 15 then

				local currentForward = rootPart.CFrame.LookVector
				local goalForward = (GetGoal(MoveDirection) - Board.Position).unit

				-- rootPart.CFrame = rootPart.CFrame:Lerp(AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean)), INSTANT_TURN_SMOOTHING) 
				bodyGyro.CFrame = bodyGyro.CFrame:Lerp(AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean)), INSTANT_TURN_SMOOTHING) 
                --RootPart.CFrame = RootPart.CFrame:Lerp(AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(BoardRotation), math.rad(HorizontalLean)), 0.05) 
			else

				bodyGyro.CFrame = bodyGyro.CFrame:Lerp(AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean)), DeltaTime * 4) 
				--BG.CFrame = AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(BoardRotation), math.rad(HorizontalLean))

			end

		else
			bodyGyro.CFrame = CFrame.new(Origin, Vector3.new(Goal.X, Origin.Y, Goal.Z)) * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean))
			--BG.CFrame = CFrame.new(Origin, Vector3.new(Goal.X, Origin.Y, Goal.Z)) * CFrame.Angles(math.rad(TiltAngle), math.rad(BoardRotation), math.rad(HorizontalLean))
		end

	end

	
	
	
	
	
	
	
	--local BoardCF = Board.CFrame
	--local Origin = Board.Position + BoardCF.LookVector + Board.AssemblyLinearVelocity * Rayvelocity
	--local Direction = Vector3.new(0, -1, 0)
	--local CheckingDistance = HoverHeight + 4
	--local RayParams = RaycastParams.new()
	--RayParams.FilterType = Enum.RaycastFilterType.Exclude
	--RayParams.FilterDescendantsInstances = { Board, character }
	--local SwaySpeed = 0 --2
	--local MaxSwayAngle = 0 --1.5
	--local TiltAngle = math.sin(tick() * SwaySpeed) * MaxSwayAngle
	--local newNormal
	--local LerpFactor = 0.8
	--local Goal = GetGoal(MoveDirection)

	--if Goal then
	--	local RaycastResult = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)

	--	if ForwardLean ~= 0 then
	--		TiltAngle = ForwardLean
	--	end

	--	if RaycastResult then
	--		newNormal = RaycastResult.Normal
	--	else
	--		newNormal = Normal
	--	end

	--	if newNormal then
	--		local Goal = Vector3.new(Goal.X, Origin.Y, Goal.Z)
	--		local LookVector = CFrame.new(Origin, Goal).LookVector
	--		local RightVector = LookVector:Cross(newNormal).Unit
	--		local UpVector = newNormal
	--		local AlignedCFrame = CFrame.fromMatrix(rootPart.Position, RightVector, UpVector)

	--		if InstantTurn and tonumber(SpeedVar) <= 10 then
	--			local currentForward = rootPart.CFrame.LookVector
	--			local goalForward = (GetGoal(MoveDirection) - Board.Position).unit

	--			rootPart.CFrame = rootPart.CFrame:Lerp(AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean)), INSTANT_TURN_SMOOTHING) 
	--		else

	--			bodyGyro.CFrame = AlignedCFrame * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean))
	--		end

	--	else
	--		bodyGyro.CFrame = CFrame.new(Origin, Vector3.new(Goal.X, Origin.Y, Goal.Z)) * CFrame.Angles(math.rad(TiltAngle), math.rad(SmoothBoardRotation), math.rad(SmoothHorizontalLean))
	--	end
	--end
end

local function ExponentialDecay(InitialValue : number, FinalValue : number, DecayRate : number, TimeDelta : number)
	return FinalValue + (InitialValue - FinalValue) * math.exp(-DecayRate * TimeDelta)
end

local function Hover(DeltaTime, JumpPower)
	local Origin = Board.Position
	local Direction = Vector3.new(0, -1, 0)
	local CheckingDistance = HoverHeight + 4
	local PotentialMap = workspace:FindFirstChild("CurrentMap")
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.FilterDescendantsInstances = { Board, character }
	local RaycastResult = workspace:Raycast(Origin, Direction * CheckingDistance, RayParams)
	local SwaySpeed = 2.5
	local MaxSwayHeight = 0.1
	local HeightSway = math.sin(tick() * SwaySpeed) * MaxSwayHeight
	local Normal

	if Jump then
		Jump = false
		LastJump = true
		bodyVelocity.MaxForce = Vector3.new(2e9, 2e9, 2e9)
		bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, JumpPower, bodyVelocity.Velocity.Z)
	end

	if RaycastResult then
		CanJump = true
		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(2e9, 2e9, 2e9)
			local HoverPosition = RaycastResult.Position + Vector3.new(0, HoverHeight + HeightSway, 0)
			local VelocityY = ((HoverPosition - rootPart.Position).Y + HoverHeight) * HoverStiffness
			Normal = RaycastResult.Normal

			local BoardCF = Board.CFrame * CFrame.Angles(math.rad(-ForwardLean), 0, 0)
			local yoffset = (BoardCF.LookVector * SpeedVar * Vector3.new(0, 1, 0)).Y

			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, ExponentialDecay(Board.AssemblyLinearVelocity.Y, VelocityY + yoffset, 20, DeltaTime), bodyVelocity.Velocity.Z)
		end

		if not Jump then
			AirJumps = 1
		end

	else
		CanJump = false
		if not LastJump then
			bodyVelocity.MaxForce = Vector3.new(2e9, 0, 2e9)
			bodyVelocity.Velocity = Vector3.new(bodyVelocity.Velocity.X, -HoverHeight, bodyVelocity.Velocity.Z)
		end
		LastJump = false
	end

	SetCharacterOrientation(Normal, DeltaTime)
end

local function ManageMoveDirection(deltaTime, MaxSpeed)
	controls = GetControls()
	local MoveDirection = controls:GetMoveVector()
	local currentForward = Board.CFrame.LookVector
	local goalForward = (GetGoal(MoveDirection) - Board.Position).unit
	local angleInDegrees = IsFacingRightDirection(currentForward, goalForward)
	local direction, angle = ReturnDirectionAndTiltAngle(currentForward, goalForward)

    if MoveDirection.X ~= 0 and MoveDirection.Z ~= 0 then
        direction *= -1
    end

	if angle >= 130 then
		IsDecelerating = true
		if tonumber(SpeedVar) <= 10 then
			InstantTurn = true
		end
	elseif angle > 50 then
		SpeedVar = math.max(0, SpeedVar - (SpeedVar * .35 * 10) * deltaTime)
	elseif angle < 20 then
		InstantTurn = false
	end
	
	if MoveDirection.Z == 0 then
		CurrentSpeed = 0
		ForwardLean = 0
	elseif MoveDirection.Z > 0 then
		CurrentSpeed = MaxSpeed
		ForwardLean = FORWARD_LEAN_AMOUNT
	elseif MoveDirection.Z < 0 then
		CurrentSpeed = MaxSpeed
		ForwardLean = FORWARD_LEAN_AMOUNT

	end

	if MoveDirection.X == 0 then
		BoardRotation = OgBoardRotation
		--HorizontalLean = 0

	elseif MoveDirection.X < 0 then
		CurrentSpeed = MaxSpeed
		ForwardLean = FORWARD_LEAN_AMOUNT

	elseif MoveDirection.X > 0 then
		CurrentSpeed = MaxSpeed
		ForwardLean = FORWARD_LEAN_AMOUNT

	elseif MoveDirection.Z == 0 and MoveDirection.X ~= 0 then
		BoardRotation = OgBoardRotation
		--HorizontalLean = 0
	end



	if MoveDirection.Z < 0 and MoveDirection.X > 0 then
		BoardRotation = OgBoardRotation - ROTATION_AMOUNT
		-- HorizontalLean = -HORIZONTAL_LEAN_AMOUNT

	elseif MoveDirection.Z < 0 and MoveDirection.X < 0 then
		BoardRotation = OgBoardRotation + ROTATION_AMOUNT
		-- HorizontalLean = HORIZONTAL_LEAN_AMOUNT
	elseif MoveDirection.Z > 0 and MoveDirection.X < 0 then
		BoardRotation = OgBoardRotation - ROTATION_AMOUNT

		-- HorizontalLean = -HORIZONTAL_LEAN_AMOUNT
		_G.MoveVector = Vector3.new(1,0,1)
	elseif MoveDirection.Z > 0 and MoveDirection.X > 0 then
		BoardRotation = OgBoardRotation + ROTATION_AMOUNT
        --direction *= -1
		-- HorizontalLean = HORIZONTAL_LEAN_AMOUNT
		_G.MoveVector = Vector3.new(-1,0,1)
	elseif MoveDirection.Z == 0 and MoveDirection.X == 0 then
		BoardRotation = OgBoardRotation
		-- HorizontalLean = 0
	elseif MoveDirection.Z == 0 and MoveDirection.X ~= 0 then
		BoardRotation = OgBoardRotation
		-- HorizontalLean = 0
	end

	if MoveDirection.Z == 0 and MoveDirection.X == 0 and IsDecelerating then
		IsDecelerating = false
	end


	local maxAngle = 45
	local leanRatio = math.clamp(angle / maxAngle, -1, 1)
	HorizontalLean = math.round(HORIZONTAL_LEAN_AMOUNT * leanRatio * direction)

	-- Smoothing
	SmoothBoardRotation = SmoothBoardRotation + (BoardRotation - SmoothBoardRotation) * deltaTime * SmoothingSpeed
	SmoothHorizontalLean = SmoothHorizontalLean + (HorizontalLean - SmoothHorizontalLean) * deltaTime * HorizontalSmoothingSpeed
	SmoothForwardLean = SmoothForwardLean + (ForwardLean - SmoothForwardLean) * deltaTime * SmoothingSpeed
	
	
	
	--if MoveDirection.Z == 0 then
	--	CurrentSpeed = 0
	--	ForwardLean = 0
	--elseif MoveDirection.Z > 0 then
	--	CurrentSpeed = MaxSpeed
	--	ForwardLean = FORWARD_LEAN_AMOUNT
	--elseif MoveDirection.Z < 0 then
	--	CurrentSpeed = MaxSpeed
	--	ForwardLean = FORWARD_LEAN_AMOUNT
	--end

	--if MoveDirection.X == 0 then
	--	BoardRotation = OgBoardRotation
	--	HorizontalLean = 0

	--elseif MoveDirection.X < 0 then
	--	CurrentSpeed = MaxSpeed
	--	ForwardLean = FORWARD_LEAN_AMOUNT

	--elseif MoveDirection.X > 0 then
	--	CurrentSpeed = MaxSpeed
	--	ForwardLean = FORWARD_LEAN_AMOUNT

	--elseif MoveDirection.Z == 0 and MoveDirection.X ~= 0 then
	--	BoardRotation = OgBoardRotation
	--	HorizontalLean = 0
	--end

	--if MoveDirection.Z < 0 and MoveDirection.X > 0 then
	--	BoardRotation = OgBoardRotation - ROTATION_AMOUNT
	--	HorizontalLean = -HORIZONTAL_LEAN_AMOUNT
	--elseif MoveDirection.Z < 0 and MoveDirection.X < 0 then
	--	BoardRotation = OgBoardRotation + ROTATION_AMOUNT
	--	HorizontalLean = HORIZONTAL_LEAN_AMOUNT
	--elseif MoveDirection.Z > 0 and MoveDirection.X < 0 then
	--	BoardRotation = OgBoardRotation - ROTATION_AMOUNT
	--	HorizontalLean = -HORIZONTAL_LEAN_AMOUNT
	--	_G.MoveVector = Vector3.new(1,0,1)
	--elseif MoveDirection.Z > 0 and MoveDirection.X > 0 then
	--	BoardRotation = OgBoardRotation + ROTATION_AMOUNT
	--	HorizontalLean = HORIZONTAL_LEAN_AMOUNT
	--	_G.MoveVector = Vector3.new(-1,0,1)
	--elseif MoveDirection.Z == 0 and MoveDirection.X == 0 then
	--	BoardRotation = OgBoardRotation
	--	HorizontalLean = 0
	--elseif MoveDirection.Z == 0 and MoveDirection.X ~= 0 then
	--	BoardRotation = OgBoardRotation
	--	HorizontalLean = 0
	--endp

	--if MoveDirection.Z == 0 and MoveDirection.X == 0 and IsDecelerating then
	--	IsDecelerating = false
	--end

	---- Smoothing
	--SmoothBoardRotation = SmoothBoardRotation + (BoardRotation - SmoothBoardRotation) * deltaTime * SmoothingSpeed
	--SmoothHorizontalLean = SmoothHorizontalLean + (HorizontalLean - SmoothHorizontalLean) * deltaTime * SmoothingSpeed
	--SmoothForwardLean = SmoothForwardLean + (ForwardLean - SmoothForwardLean) * deltaTime * SmoothingSpeed
end

local function CalculateSpeed(Acceleration, Deceleration, MaxSpeed, dt)
	local isMoving = Acceleration > 0
	local rate = isMoving and Acceleration or Deceleration
	local minRate = 0.1
	rate = math.max(rate, minRate)
	local smooth = 1 - math.exp(-rate * MOVEMENT_SMOOTHNESS * dt)
	print("Max speed :", MaxSpeed)
	print("Current speed: ", CurrentSpeed)
	CurrentSpeed = CurrentSpeed + (MaxSpeed - CurrentSpeed) * smooth
	CurrentSpeed = math.clamp(CurrentSpeed, 0, MAX_SPEED)
	
	if CurrentSpeed <= 0 then
		CurrentSpeed = 0
	end
end

local function SetSpeed(dt, acceleration, topSpeed)

	SpeedVar = math.max(SpeedVar + (CurrentSpeed - SpeedVar) * acceleration * dt, 0)

	local BoardCF = Board.CFrame * CFrame.Angles(math.rad(-ForwardLean), 0, 0)
    -- local goalDirection = GetGoal(GetControls():GetMoveVector()).Unit
	bodyVelocity.Velocity = BoardCF.LookVector * SpeedVar * Vector3.new(1, 0, 1) + Vector3.new(0, bodyVelocity.Velocity.Y, 0)
end

local function SetSpeedOld(dt, acceleration, topSpeed)
	if IsDecelerating then
		if tonumber(SpeedVar) > 0 then
			SpeedVar = math.max(SpeedVar - DECELERATION * dt, 0)
		elseif SpeedVar == 0 then
			IsDecelerating = false
		end
	else
		local SpeedDifference = CurrentSpeed - SpeedVar
		if math.abs(SpeedDifference) > Diff then
			SpeedVar = SpeedVar + (SpeedDifference) * acceleration * dt
			SpeedVar = math.round(SpeedVar)
		else
			SpeedVar = math.round(CurrentSpeed)
		end
	end
	local BoardCF = Board.CFrame * CFrame.Angles(math.rad(-ForwardLean), 0, 0)
	bodyVelocity.Velocity = BoardCF.LookVector * SpeedVar * Vector3.new(1, 0, 1) + Vector3.new(0, bodyVelocity.Velocity.Y, 0)
end

local function UpdateFOV(dt)
	local diff = MAX_FOV - MIN_FOV
	Camera.FieldOfView =  math.clamp(math.lerp(Camera.FieldOfView,  MIN_FOV + (diff * (CurrentSpeed / MAX_SPEED)), dt), MIN_FOV, MAX_FOV)
end
-----------------------------------------------------------


-- PLAYER LIFECYCLE

local function ResetStates()
	print("Reset states called")
	character = nil
	humanoid = nil
	rootPart = nil
	Board = nil
	bodyVelocity = nil
	bodyGyro = nil
	bodyPosition = nil
	controls = nil
	Config = nil
	LastMovedirection = nil
	OgBoardRotation = 0
	BoardRotation = 0
	SmoothBoardRotation = 0
	acceleration = 0
	topSpeed = 0
	jumpPower = 0
	ForwardLean = 0
	HorizontalLean = 0
	SmoothForwardLean = 0
	SmoothHorizontalLean = 0
	SpeedVar = 0
	CurrentSpeed = 0
	AirJumps = 1
	IsDecelerating = false
	Jump = false
	LastJump = false
	CanJump = false
	isHoverboardInitialized = false
	isOnHoverboard = false
	CameraHeld = false
	InstantTurn = false
end

function NewController:DisableAnimations(char)
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
end

function NewController:HumanoidSetup()
	humanoid.MaxSlopeAngle = 0
	humanoid.AutoRotate = true
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 70
end

function NewController:SetActiveConfig(boardName)
	if isHoverboardInitialized then
		print("Hoverboard: Hoverboard already initialized, skipping SetActiveHoverboard")
		return
	end
	local config = HoverboardData.GetConfig(boardName)
	if not config then
		warn("Hoverboard: Could not find hoverboard config for " .. tostring(boardName))
		return
	end
	self.ActiveConfig = config
	print("Hoverboard: Active config: ", self.ActiveConfig)
	isOnHoverboard = true
	isHoverboardInitialized = true
	self:StartHoverboard(config)
end

function NewController:StartHoverboard(config)
	print("StartHoverboard called")
	if runningConnection then
		runningConnection:Disconnect()
	end
	
	acceleration = config.Acceleration or ACCELERATION
	topSpeed = config.TopSpeed or MAX_SPEED
	jumpPower = config.JumpPower or JUMP_POWER
	currentAccelerationRef.value = config.Acceleration or ACCELERATION
	currentTopSpeedRef.value = config.TopSpeed or MAX_SPEED
	LoadSpeedGUI()
	BoostAbility.BindBoost(character, humanoid, rootPart, function() return CurrentSpeed end, function() return SpeedVar end, currentAccelerationRef, currentTopSpeedRef)
	
	print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)
	runningConnection = RunService.Heartbeat:Connect(function(dt)
		Hover(dt, jumpPower)
		ManageMoveDirection(dt, topSpeed)
		SetSpeed(dt, acceleration, topSpeed)
		UpdateFOV(dt)
		
		if speedGUI and speedLabel and bars then
			UpdateSpeedGUI(topSpeed)
		end
	end)
end

local function OnCharacterAdded(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	rootPart = char:WaitForChild("HumanoidRootPart")

	-- Wait for board
	local hb = char:WaitForChild("Hoverboard")
	Board = hb:WaitForChild("PrimaryPart")
	InitBodyMovers()
	
	OgBoardRotation = Board.CFrame.Rotation.Y
	BoardRotation = OgBoardRotation
	SmoothBoardRotation = OgBoardRotation
	
	UserInputService.InputBegan:Connect(function(Input : InputObject, gameProcessedEvent)
		if gameProcessedEvent then return end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Space and CanJump then
				print("Jump requested")
				Jump = true
				if not LastJump then
					AirJumps -= 1
				end
			end

		end

		if Input.UserInputType == Enum.UserInputType.MouseButton2 or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			CameraHeld = true
		end
	end)

	UserInputService.InputEnded:Connect(function(Input : InputObject, GameProcessed : boolean)
		if GameProcessed then return end

		if Input.UserInputType == Enum.UserInputType.MouseButton2 and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			CameraHeld = false
		end

	end)
	
	

end

local function OnCharacterRemoving()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	ResetStates()
	BoostAbility.CharRemoving()
end

local function OnPlayerAdded(plr)
	if plr ~= player then
		return
	end
	plr.CharacterAdded:Connect(function() 
		OnCharacterAdded(plr.Character)
	end)
	plr.CharacterRemoving:Connect(OnCharacterRemoving)
	if plr.Character then
		OnCharacterAdded(plr.Character)
	end
end


function NewController:KnitStart()
	print("NewController started")
	OnPlayerAdded(player)
	HoverboardService = Knit.GetService("HoverboardService")
	HoverboardService.HoverboardSpawned:Connect(function(_, owner, boardName)
		if owner ~= player then
			return
		end
		if isHoverboardInitialized then
			print("Hoverboard: Hoverboard already initialized, ignoring spawn event")
			return
		end
		NewController:SetActiveConfig(boardName)
	end)
	HoverboardService.HoverboardRemoved:Connect(function()
		ResetStates()
	end)
	HoverboardService.ControlSignal:Connect(function(action)
		local ctrl = GetControls()

		if action == "Disable" then
			ctrl:Disable()
		elseif action == "Enable" then
			ctrl:Enable()
		end
	end)
end

return NewController
