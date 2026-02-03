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
local RewardsGUI = PlayerGui:WaitForChild("Rewards")
local Rewards = RewardsGUI:WaitForChild("Rewards")
local Contents = Rewards:WaitForChild("Contents")

local Codes = Contents:WaitForChild("Codes")
local Daily = Contents:WaitForChild("Daily")
local Time = Contents:WaitForChild("Time")

local textBox = Codes:WaitForChild("Box")
local ClaimButton = Codes:WaitForChild("ClaimButton")

local Sections = Rewards:WaitForChild("Sections")
local CodesButtonFrame = Sections:WaitForChild("Codes")
local Codesbutton = CodesButtonFrame:WaitForChild("Button")

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

local function EnableCodes()
	Daily.Visible = false
	Time.Visible = false
	Codes.Visible = true
	HandleTextBoxFrame()
end

function CodesController:Enable(Enabled: boolean)
	RewardsGUI.Enabled = Enabled

	if Enabled then
		Daily.Visible = false
		Time.Visible = false
		Codes.Visible = true
		HandleTextBoxFrame()
	end
end

function CodesController:KnitStart()
	CodesService = Knit.GetService("CodesService")
	CoinsController = Knit.GetController("CoinsController")

	textBox.FocusLost:Connect(onFocusLost)
	textBox.Focused:Connect(onFocused)

	ClaimButton.MouseButton1Click:Connect(OnClaim)
	Codesbutton.MouseButton1Click:Connect(EnableCodes)
end

return CodesController
