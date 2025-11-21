-- [Services]			----
local PlayerService: Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
-- local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]			----
-- local Utility: Folder = ReplicatedStorage:WaitForChild("Utility")
-- local EnumsAndConstants : Folder = ReplicatedStorage:WaitForChild("EnumsAndContants")

-- local Constants : {} = require(EnumsAndConstants:WaitForChild("Constants"))
-- local SoundModule: {} = require(Utility.SoundModule)

-- [UI References]		----
local PlayerGui = PlayerService.LocalPlayer:WaitForChild("PlayerGui")
local RedeemCode = PlayerGui:WaitForChild("RedeemCode")

local MainFrame = RedeemCode:WaitForChild("MainFrame")
local textBox = MainFrame:WaitForChild("Box")
local ClaimButton = MainFrame:WaitForChild("ClaimButton")
local CloseButton = RedeemCode:WaitForChild("Close")

-- [Variables]		----
local PlaceHolderText = "Enter code..."
textBox.PlaceholderText = PlaceHolderText
textBox.ClearTextOnFocus = true

local CodesService
local CoinsController

local CodesController = Knit.CreateController({
	Name = "CodesController",
})

local function HandleTextBoxFrame()
	--textBox:CaptureFocus()
	textBox.Text = ""
end

local function Trim(str)
	return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

local function OnClaim()
	local code: string = Trim(textBox.Text)

	if string.len(code) == 0 then
		-- NotificationClientBE:Fire("Enter code!", "Error")
		textBox.Text = ""
		return
	end

	CodesService:RedeemCode(code):andThen(function(success, message)
		if success then
			-- NotificationClientBE:Fire(message)
			CoinsController:RefreshDisplay()
			textBox.Text = ""
		else
			-- NotificationClientBE:Fire(message , "Error")
			textBox.Text = ""
		end

		textBox:ReleaseFocus()
		textBox:CaptureFocus()
	end)
end

local function onFocused()
	textBox.Text = ""
end

local function onFocusLost(enterPressed, _inputObject)
	if enterPressed then
		OnClaim()
	end
end

textBox.FocusLost:Connect(onFocusLost)
textBox.Focused:Connect(onFocused)

-- function CodesController:SetEnabled(enabled: boolean)
-- 	RedeemCode.Enabled = enabled

-- 	if enabled then
-- 		HandleTextBoxFrame()
-- 	end
-- end

ClaimButton.MouseButton1Click:Connect(OnClaim)

-- Open button already handled in Lobbyhud
CloseButton.MouseButton1Click:Connect(function()
	-- CodesController.LobbyHUD:OpenContainer("MainGui")
end)

function CodesController:KnitStart()
	CodesService = Knit.GetService("CodesService")
	CoinsController = Knit.GetController("CoinsController")

	HandleTextBoxFrame()
end

return CodesController
