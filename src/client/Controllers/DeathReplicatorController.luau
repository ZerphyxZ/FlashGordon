-- DeathReplicatorController.luau
-- Client‑side controller that reacts to other players' IsDead attribute changes.
-- When a player dies, this controller hides their character locally and plays
-- the same death effect.  When IsDead is cleared, it restores visibility.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local DeathEffects = require(ReplicatedStorage.Shared.Modules.DeathEffects)

local DeathReplicatorController = Knit.CreateController({ Name = "DeathReplicatorController" })
local LocalPlayer = Players.LocalPlayer

-- Helper to make a character fully invisible and disable particle effects.
local function hideCharacter(character)
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 1
		elseif obj:IsA("Decal") then
			obj.Transparency = 1
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
			obj.Enabled = false
		end
	end
end

-- Restore visibility and re‑enable particle emitters.
local function showCharacter(character)
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Transparency = 0
		elseif obj:IsA("Decal") then
			obj.Transparency = 0
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
			obj.Enabled = true
		end
	end
end

function DeathReplicatorController:KnitStart()
	print("[DeathReplicatorController] KnitStart called")

	local function monitorPlayer(player)
		if player == LocalPlayer then
			return
		end
		-- Listen for changes to the IsDead attribute on each player.
		player:GetAttributeChangedSignal("IsDead"):Connect(function()
			local isDead = player:GetAttribute("IsDead")
			local character = player.Character
			if isDead then
				if character then
					hideCharacter(character)
					-- Play the same death effect for remote players.
					DeathEffects.playDeathEffectAtCharacter(character)
				end
			else
				if character then
					showCharacter(character)
				end
			end
		end)
		-- Apply current state on join.
		task.delay(0.05, function()
			if player:GetAttribute("IsDead") then
				local char = player.Character
				if char then
					hideCharacter(char)
				end
			end
		end)
	end

	-- Monitor existing and future players.
	for _, pl in ipairs(Players:GetPlayers()) do
		monitorPlayer(pl)
	end
	Players.PlayerAdded:Connect(monitorPlayer)
end

return DeathReplicatorController
