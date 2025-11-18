--// HoverboardPhysics.lua
local HoverboardPhysics = {}

local MAX_BODY_FORCE = 100000

function HoverboardPhysics.AttachPhysics(rootPart)
	if not rootPart then return end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(4000, 0, 4000)
	bv.P = 2000
	bv.Velocity = Vector3.zero
	bv.Parent = rootPart

	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(4000, 4000, 4000)
	bg.P = 7000
	bg.D = 500
	bg.Parent = rootPart

	local bp = Instance.new("BodyPosition")
	bp.Name = "HoverBodyPosition"
	bp.MaxForce = Vector3.new(0, MAX_BODY_FORCE, 0)
	bp.P = 6000
	bp.D = 600
	bp.Position = rootPart.Position
	bp.Parent = rootPart

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