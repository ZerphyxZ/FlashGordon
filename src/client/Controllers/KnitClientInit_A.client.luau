local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit

local player = game.Players.LocalPlayer
local ScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local boostBtn = ScreenGui:WaitForChild("BoostButton")
local plasmaBtn = ScreenGui:WaitForChild("PlasmaButton")
local defaultBtn = ScreenGui:WaitForChild("DefaultButton")
local respawnBtn = ScreenGui:WaitForChild("RespawnButton")

Knit.AddControllers(script.Parent)
Knit.Start():andThen(function()
	print("Knit started on client")
	local HoverboardService = Knit.GetService("HoverboardService")
	boostBtn.MouseButton1Click:Connect(function()
		print("Equipping BoostRider")
		HoverboardService:RequestEquipHoverboard("BoostRider")
	end)

	plasmaBtn.MouseButton1Click:Connect(function()
		print("Equipping PlasmaRider")
		HoverboardService:RequestEquipHoverboard("PlasmaRider")
	end)

	defaultBtn.MouseButton1Click:Connect(function()
		print("Equipping DefaultRider")
		HoverboardService:RequestEquipHoverboard("DefaultRider")
	end)

	respawnBtn.MouseButton1Click:Connect(function()
		print("Respawn Clicked")
		if not player then
			return
		end
		local char = player.Character or player.CharacterAdded:Wait()
		local humanoid = char:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
end)
