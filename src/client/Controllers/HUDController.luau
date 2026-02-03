local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage

--UI References
local playerGui = player:WaitForChild("PlayerGui")
local GameHUD = playerGui:WaitForChild("GameHUD")
local itemsList = GameHUD:WaitForChild("ItemsLeft")

local HUDController = Knit.CreateController({ Name = "HUDController" })

local function OpenGUI()
	-- Connect all item buttons dynamically
	for _, item in ipairs(itemsList:GetChildren()) do
		-- Only detect UI buttons whose names start with "Item"
		if item:IsA("ImageButton") then
			if item.Name:sub(1, 4) == "Item" then
				local guiName = item.Name:sub(5) -- Extract name after "Item"

				item.MouseButton1Click:Connect(function()
					-- disable all guis first
					for _, gui in ipairs(playerGui:GetChildren()) do
						if gui.Name == "DailyReward" or gui.Name == "DailySpin" then
							gui.Enabled = false
						end
					end

					-- enable the desired gui
					local targetGui = playerGui:FindFirstChild(guiName)
					print("GUI requested: ", guiName)
					if targetGui then
						targetGui.Enabled = true
					else
						warn("GUI not found for item:", guiName)
					end
				end)
			end
		end
	end
end

function HUDController:KnitStart()
	OpenGUI()
end

return HUDController
