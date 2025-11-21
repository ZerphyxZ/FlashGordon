--// HoverboardPhysics.lua
local HoverboardPhysics = {}

local MAX_BODY_FORCE = 100000

function HoverboardPhysics.AttachPhysics(hoverboard)
	if not hoverboard or not hoverboard.PrimaryPart then return end
	local primaryPart = hoverboard.PrimaryPart

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(4000, 0, 4000)
	bv.P = 2000
	bv.Velocity = Vector3.zero
	bv.Parent = primaryPart

	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(4000, 4000, 4000)
	bg.P = 7000
	bg.D = 500
	bg.Parent = primaryPart

	local bp = Instance.new("BodyPosition")
	bp.Name = "BodyPosition"
	bp.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	bp.P = 6000
	bp.D = 600
	bp.Position = primaryPart.Position
	bp.Parent = primaryPart

	return bv, bg, bp
end

function HoverboardPhysics.Cleanup(hoverboard, bv, bg, bp)
	if hoverboard then 
		hoverboard:Destroy()
		hoverboard = nil
	end
	if bv then 
		bv:Destroy()
		bv = nil
	end
	if bg then 
		bg:Destroy() 
		bg = nil
	end
	if bp then 
		bp:Destroy()
		bp = nil
	end
end

return HoverboardPhysics