local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
local Players = Global.Players
local player = Players.LocalPlayer
local ReplicatedStorage = Global.ReplicatedStorage
local HoverboardService

--UI References
local gearGui = player:WaitForChild("PlayerGui"):WaitForChild("Gear")
local mainFrame = gearGui:WaitForChild("MainFrame")
local BG = mainFrame:WaitForChild("BG")
local closeBtn = mainFrame:WaitForChild("Close"):WaitForChild("Button")
local hoverboadsList = BG:WaitForChild("BoardsFrame"):WaitForChild("HoverboardsList")
local tabs = BG:WaitForChild("Tabs")


local GearController = Knit.CreateController({ Name = "GearController" })

local function CloseGearGui()
    gearGui.enabled = false
end

local function OnHoverboardTemplateClicked()
    -- Connect every hoverboard button automatically
	for _, button in ipairs(hoverboadsList:GetChildren()) do
		if button:IsA("ImageButton") then
			local boardName = button.Name  -- must match the hoverboard model name
			button.MouseButton1Click:Connect(function()
				-- request server to equip the clicked hoverboard
				HoverboardService:RequestEquipHoverboard(boardName)
				-- close gear ui
				--CloseGearGui()
			end)
		end
	end
end

local function BindInput()
    OnHoverboardTemplateClicked()
    closeBtn.MouseButton1Click:Connect(function()
        CloseGearGui()
    end)
end

function GearController:KnitStart()
    HoverboardService = Knit.GetService("HoverboardService")
    BindInput()
end

return GearController