local Utilities = {}

function Utilities.ProjectVectorOnPlane(vector, planeNormal)
	local projection = vector - planeNormal * vector:Dot(planeNormal)
	return projection.Magnitude > 1e-5 and projection.Unit or Vector3.zero
end

function Utilities.SmoothDamp(current, target, smoothTime, dt)
	return current + (target - current) * (1 - math.exp(-smoothTime * dt))
end

function Utilities.CalculateMoveDirection(camera, inputVec)
	local lookDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local rightDir = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

	if lookDir.Magnitude > 0 then
		lookDir = lookDir.Unit
	end
	if rightDir.Magnitude > 0 then
		rightDir = rightDir.Unit
	end

	return (lookDir * -inputVec.Z + rightDir * inputVec.X)
end

function Utilities.CreateConstraint(part, className, properties)
	local constraint = Instance.new(className)
	for property, value in pairs(properties) do
		constraint[property] = value
	end
	constraint.Parent = part
	return constraint
end

return Utilities