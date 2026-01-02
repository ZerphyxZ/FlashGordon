-- [Services]			----
local PlayerService: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Modules]            -----
local Configuration: Folder = ReplicatedStorage:WaitForChild("Configuration")
local WorldsConfig: {} = require(Configuration:WaitForChild("Worlds"))
-- local EnumsAndConstants : Folder = ReplicatedStorage:WaitForChild("EnumsAndContants")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

-- [UI References]      -----
local LocalPlayer = PlayerService.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")

local WorldsUI: Frame = MainGui:WaitForChild("Worlds")
local Content: Frame = WorldsUI:WaitForChild("Content")
local WorldParent: ScrollingFrame = Content:WaitForChild("ScrollingFrame")

local Types = { "Events", "Normal", "Gamemodes" }
local Seperators: { string: Frame } = {
	Events = WorldParent:WaitForChild("EventsSeparator"),
	Normal = WorldParent:WaitForChild("FeaturedSeparator"),
	Gamemodes = WorldParent:WaitForChild("CampaignSeparator"),
}

local TemplateWorldFolder: Frame = WorldsUI:WaitForChild("Templates")
local TemplateWorldCard: Frame = TemplateWorldFolder:WaitForChild("TemplateWorld")

-- [CONSTANTS]          -----
local PlaceId = game.PlaceId

local WorldUIController = Knit.CreateController({
	Name = "WorldUIController",
})

WorldUIController.NormalCards = {}

function WorldUIController:KnitStart()
	self.Index = 1

	if WorldsConfig.Normal[PlaceId] then
		self.CurrentWorldConfig = WorldsConfig.Normal[PlaceId]
	end

	for _, typeOfWorld: string in Types do
		local configTable = WorldsConfig[typeOfWorld]

		if Seperators[typeOfWorld] then
			Seperators[typeOfWorld].Visible = next(configTable) ~= nil
			Seperators[typeOfWorld].LayoutOrder = self.Index
			self.Index += 1
		end

		LoadWorldsFromTable(typeOfWorld, configTable)
	end
end

function WorldUIController:Enable(Enabled: boolean)
	MainGui.Enabled = Enabled
	WorldsUI.Visible = Enabled
end

function RequestTeleport(placeId)
	if placeId ~= PlaceId then
	end
end

function WorldUIController:SetWorldCardStates(CurrentMaxWorld: number)
	for index, card in self.NormalCards do
		local isLocked = index > CurrentMaxWorld

		card.Overlay.Visible = not isLocked
		card.Content.Teleport.Visible = not isLocked and (index ~= CurrentMaxWorld)
		card.Content.Current.Visible = index == CurrentMaxWorld
	end
end

function LoadWorldsFromTable(Type: string, ModeTable: {})
	if next(ModeTable) == nil then
		return
	end

	for placeId: number, worldTable: {} in ModeTable do
		local card = TemplateWorldCard:Clone()
		card.Parent = WorldParent
		card.LayoutOrder = WorldUIController.Index
		card.Overlay.Visible = Type == "Normal"

		local content = card.Content.Content

		if Type == "Normal" then
			card.Overlay.Title.Text = `Finish World {worldTable.Index - 1} to unlock`
			content.Title.Text = `World {worldTable.Index}`

			WorldUIController.Normal[worldTable.Index] = card
		else
			card.Content.Content.Title.Text = worldTable.Name
		end

		-- click connection
		content.Teleport.Button.Activated:Connect(function()
			RequestTeleport(placeId)
		end)

		WorldUIController.Index += 1
	end
end

return WorldUIController
