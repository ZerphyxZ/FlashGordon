local AnimationManager = {}
local originalAnims = {}

function AnimationManager.DisableMovementAnimations(humanoid, character)
	humanoid = character:WaitForChild("Humanoid")

	local animate = character:FindFirstChild("Animate")
	if not animate then return end

	-- List of movement-related animation tracks
	local toDisable = { "walk", "run", "jump", "fall" }

	for _, name in ipairs(toDisable) do
		local animObj = animate:FindFirstChild(name)
		if animObj and animObj:FindFirstChild("Animation") then
			local anim = animObj.Animation
			if not originalAnims[name] then
				originalAnims[name] = anim.AnimationId
			end
			anim.AnimationId = "" -- Disable by clearing
		end
	end

	-- Also ensure physics-based state if on hoverboard
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

function AnimationManager.RestoreMovementAnimations(character)
	if not character then return end
	local animate = character:FindFirstChild("Animate")
	if not animate then return end

	for name, animId in pairs(originalAnims) do
		local animObj = animate:FindFirstChild(name)
		if animObj and animObj:FindFirstChild("Animation") then
			animObj.Animation.AnimationId = animId
		end
	end
end

return AnimationManager
