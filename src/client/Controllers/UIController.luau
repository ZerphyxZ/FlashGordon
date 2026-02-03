---- [Services]			-----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService: SoundService = game:GetService("SoundService")
local Library: Folder = ReplicatedStorage:WaitForChild("Library")
local Utility: Folder = ReplicatedStorage:WaitForChild("Utility")

----- [Modules]         -----
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

----	[References]    -----
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local GameHUD = PlayerGui:WaitForChild("GameHUD")
local LeftItemHolder = GameHUD:WaitForChild("ItemsLeft")
local RightItemHolder = GameHUD:WaitForChild("ItemsRight")


local hoverTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local unHoverTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local gameGuis = {}

local UIController = Knit.CreateController({
    Name = "UIController"
})

UIController.CurrentActiveScreen = nil

UIController.Buttons = {
	Spin = RightItemHolder:WaitForChild("Items"):WaitForChild("Spin"),
	DailyReward = RightItemHolder:WaitForChild("Items"):WaitForChild("DailyReward"),
	-- Codes = LeftItemHolder:WaitForChild("Codes"),
	TimeReward = RightItemHolder:WaitForChild("TimeReward"),
    Boards = LeftItemHolder:WaitForChild("Boards"),
	Worlds = LeftItemHolder:WaitForChild("Worlds"),
}

UIController.Module = { MainGui = UIController }
UIController.GUI = { MainGui = GameHUD }



local function SetUpButtonAnims(button)
	if not button:GetAttribute("OriginalSize") then
		button:SetAttribute("OriginalSize", button.Size)
	end

	local originalSize = button:GetAttribute("OriginalSize")
	local hover = TweenService:Create(button, hoverTweenInfo, {
		Size = originalSize + UDim2.new(0.07, 0, 0.03, 0),
	})

	local unhover = TweenService:Create(button, unHoverTweenInfo, {
		Size = originalSize,
	})

	button.MouseEnter:Connect(function()
		hover:Play()
		--SoundService:WaitForChild("SFXGroupL"):WaitForChild("UIHover"):Play()
	end)

	button.MouseLeave:Connect(function()
		unhover:Play()
	end)

	button.MouseButton1Click:Connect(function()
		unhover:Play()
	end)
end

function UIController:ToggleContainer(name: string)

    if self.CurrentActiveScreen == name then
        self:CloseContainer(self.CurrentActiveScreen)
        self.CurrentActiveScreen = nil

        return
	end

    self:CloseContainer(self.CurrentActiveScreen)
    self.CurrentActiveScreen = name
		

    if self.Module[name] then
        self.Module[name]:Enable(true)
    else
        warn("No name", name)
    end
end

function UIController:CloseContainer(name: string)
	if self.Module[name] then
		self.Module[name]:Enable(false)
	else
		--warn("No name ", name)
	end

	if self.CurrentActiveScreen == name then
		self.CurrentActiveScreen = nil
	end
end

function UIController:KnitStart()
	self.CurrentActiveScreen = nil

    UIController.Module.Spin = Knit.GetController("SpinController")
    UIController.Module.Codes = Knit.GetController("CodesController")
    UIController.Module.DailyReward = Knit.GetController("DailyRewardController")
    UIController.Module.TimeReward = Knit.GetController("TimeRewardController")
    UIController.Module.Boards = Knit.GetController("GearController")
	UIController.Module.Worlds = Knit.GetController("WorldUIController")

	for name, button in pairs(self.Buttons) do
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			button.MouseButton1Down:Connect(function()
				self:ToggleContainer(name)
			end)

			SetUpButtonAnims(button)
		else
			warn("Invalid button: " .. name)
		end
	end
end



return UIController
