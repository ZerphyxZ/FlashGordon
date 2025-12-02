local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local utilityFolder: Folder = replicatedStorage:WaitForChild("Utility")

-- [Constants]
local vfxTemplateFolder: ObjectValue = replicatedStorage:WaitForChild("Assets"):WaitForChild("Particles")
local vfxFolder: Folder = workspace:FindFirstChild("ParticleEffect")
if not vfxFolder then
	vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "ParticleEffect"
	vfxFolder.Parent = workspace
end

local module = {}

-- Play a single burst of particles
local function SimpleParticleBurst(
	effectTemplateName: string,
	cframe: CFrame | Vector3,
	attachTo: BasePart?,
	Color: Color3?,
	DirectionAcceleration: Vector3?
)
	--print("In particle emitter")
	local effect = vfxTemplateFolder:FindFirstChild(effectTemplateName)
	if effect == nil or not effect:IsA("BasePart") then
		warn("Requested VFX to play is either nil or not a BasePart")
		return
	end

	cframe = typeof(cframe) == "CFrame" and cframe or CFrame.new(cframe)

	--print("Effect Templete",effectTemplateName)
	effect = effect:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = vfxFolder

	if attachTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = attachTo
		weld.Part1 = effect
		weld.Parent = effect
	end

	local lifetime = 0

	-- Get all the particle emitters and have them emit, as well as get the maximum particle lifetime
	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		lifetime = math.max(lifetime, v.Lifetime.Max)

		local emitAmount = v:GetAttribute("EmitCount") or v:GetAttribute(EMIT_COUNT_ATTRIBUTE.Value)
		if DirectionAcceleration then
			local acceleration: Vector3 = v:GetAttribute(DirectionAcceleration)
			--emitAmount = 5

			v.Acceleration = acceleration
		end
		if emitAmount then
			if Color then
				v.Color = ColorSequence.new(Color)
			end
			--print(`emitting: {emitAmount}`)
			--print(emitAmount,"Amount Emitin")
			v:Emit(emitAmount)
		end
	end

	task.delay(lifetime, function()
		-- Wait for the particles to fade before destroying the effect
		effect:Destroy()
	end)
end

-- Play a particle effect for a specific amount of time, allowing extra time for the particles to fade at the end
local function SimpleParticleTimed(
	effectTemplateName: string,
	cframe: CFrame | Vector3,
	lifetime: number,
	attachTo: BasePart?,
	Color: Color3?
)
	local effect = vfxTemplateFolder:FindFirstChild(effectTemplateName)
	if effect == nil or not effect:IsA("BasePart") then
		warn("Requested VFX to play is either nil or not a BasePart")
		return
	end

	cframe = typeof(cframe) == "CFrame" and cframe or CFrame.new(cframe)

	effect = effect:Clone()
	effect.CFrame = if attachTo then attachTo.CFrame * cframe else cframe
	effect.Parent = vfxFolder

	if attachTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = attachTo
		weld.Part1 = effect
		weld.Parent = effect
	end

	local particleEmitters = {}
	local particleLifetime = 0

	-- Find all the particle emitters and get the maximum lifetime for them
	for _, v in effect:GetDescendants() do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		table.insert(particleEmitters, v)
		particleLifetime = math.max(particleLifetime, v.Lifetime.Max)
	end

	task.delay(lifetime, function()
		-- Disable all the particle emitters
		for _, emitter in particleEmitters do
			emitter.Enabled = false
		end

		-- Wait for them to fade before destroying the effect
		task.delay(particleLifetime, function()
			effect:Destroy()
		end)
	end)
end

return function(
	particleName: string,
	particleType: "Timed" | "Burst",
	cframe: CFrame,
	attachTo: BasePart?,
	Color: Color3?,
	DirectionAcceleration: Vector3?
)
	if particleType == "Timed" then
		SimpleParticleTimed(particleName, cframe, attachTo, Color)
	elseif particleType == "Burst" then
		SimpleParticleBurst(particleName, cframe, attachTo, Color, DirectionAcceleration)
	else
		warn("Invalid particle type provided")
	end
end
