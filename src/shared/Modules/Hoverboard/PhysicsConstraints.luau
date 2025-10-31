local HoverboardFolder = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Hoverboard")
local Utilities = require(HoverboardFolder:WaitForChild("Utilities"))
local Constants = require(HoverboardFolder:WaitForChild("HoverboardConstants"))
local Physics = {}

function Physics.CreatePhysicsConstraints(humanoidRootPart, hoverboard, bodyVelocity, bodyGyro, hoverBodyPosition)
	if not humanoidRootPart or not hoverboard or not hoverboard.PrimaryPart then
		return
	end

	-- BodyVelocity
	if not humanoidRootPart:FindFirstChild("HoverBodyVelocity") then
		bodyVelocity = Utilities.CreateConstraint(humanoidRootPart, "BodyVelocity", {
			Name = "HoverBodyVelocity",
			MaxForce = Constants.Physics.BODY_VELOCITY_MAX_FORCE,
			Velocity = Vector3.new(0, 0, 0),
			P = Constants.Physics.BODY_VELOCITY_P,
		})
	else
		bodyVelocity = humanoidRootPart:FindFirstChild("HoverBodyVelocity")
	end

	-- BodyGyro
	if not humanoidRootPart:FindFirstChild("HoverBodyGyro") then
		bodyGyro = Utilities.CreateConstraint(humanoidRootPart, "BodyGyro", {
			Name = "HoverBodyGyro",
			MaxTorque = Constants.Physics.BODY_GYRO_MAX_TORQUE,
			P = Constants.Hover.BODYGYRO_P,
			D = Constants.Hover.BODYGYRO_D,
			CFrame = humanoidRootPart.CFrame,
		})
	else
		bodyGyro = humanoidRootPart:FindFirstChild("HoverBodyGyro")
	end

	-- BodyPosition for hoverboard
	local primary = hoverboard.PrimaryPart
	if primary and not primary:FindFirstChild("HoverPosition") then
		hoverBodyPosition = Utilities.CreateConstraint(primary, "BodyPosition", {
			Name = "HoverPosition",
			MaxForce = Constants.Physics.BODY_POSITION_MAX_FORCE,
			Position = primary.Position,
			P = Constants.Physics.BODY_POSITION_P,
			D = Constants.Physics.BODY_POSITION_D,
		})
	else
		hoverBodyPosition = primary and primary:FindFirstChild("HoverPosition")
	end
end

function Physics.CleanupConstraints(humanoidRootPart, bodyVelocity, bodyGyro, hoverBodyPosition)
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	if bodyGyro and bodyGyro.Parent then
		bodyGyro:Destroy()
	end
	if hoverBodyPosition and hoverBodyPosition.Parent then
		hoverBodyPosition:Destroy()
	end

	local localMotor = humanoidRootPart and humanoidRootPart:FindFirstChild("HoverboardMotorLocal")
	if localMotor then
		localMotor:Destroy()
	end

	bodyVelocity = nil
	bodyGyro = nil
	hoverBodyPosition = nil
end

return Physics