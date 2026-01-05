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
local WorldsGui = PlayerGui:WaitForChild("WorldsGui")

local WorldsUI: Frame = WorldsGui:WaitForChild("Worlds")
local Content: Frame = WorldsUI:WaitForChild("Content")
local WorldParent: ScrollingFrame = Content:WaitForChild("ScrollingFrame")

local Types = { "Events", "Normal", "Gamemodes" }
local Seperators: { string: Frame } = {
	Events = WorldParent:WaitForChild("EventsSeparator"),
	Normal = WorldParent:WaitForChild("CampaignSeparator"),
	Gamemodes = WorldParent:WaitForChild("FeaturedSeparator"),
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
			print(`Setting visibility of separator for {typeOfWorld} to {Seperators[typeOfWorld].Visible}`)
			Seperators[typeOfWorld].LayoutOrder = self.Index
			self.Index += 1
		end

		LoadWorldsFromTable(typeOfWorld, configTable)
	end

	local player = LocalPlayer
    -- ensure it exists
    if player:GetAttribute("WorldIndex") == nil then
        player:SetAttribute("WorldIndex", 1)
    end

    local function getCurrentWorldIndex()
        return player:GetAttribute("WorldIndex") or 1
    end

    -- initial UI update
    self:SetWorldCardStates(getCurrentWorldIndex())

    -- listen for changes
    player:GetAttributeChangedSignal("WorldIndex"):Connect(function()
        print("WorldIndex changed!") -- debug
        local newIndex = getCurrentWorldIndex()
        self:SetWorldCardStates(newIndex)
    end)
end

function WorldUIController:Enable(Enabled: boolean)
	WorldsGui.Enabled = Enabled
	WorldsUI.Visible = Enabled
end

function RequestTeleport(placeId)
	print(`Requesting teleport to placeId: {placeId}`)
	if placeId ~= PlaceId then
	end
end

function getCurrentWorldIndex()
	return LocalPlayer:GetAttribute("CurrentMaxWorld") or 1
end

function WorldUIController:SetWorldCardStates(CurrentMaxWorld: number)
	for index, card in self.NormalCards do
		local isLocked = index > CurrentMaxWorld

		local content = card.Content.Content

		card.Overlay.Visible = isLocked
		content.Teleport.Visible = not isLocked and (index ~= CurrentMaxWorld)
		content.Current.Visible = index == CurrentMaxWorld
	end
end

function LoadWorldsFromTable(Type: string, ModeTable: {})
	if next(ModeTable) == nil then
		return
	end

	for placeId: number, worldTable: {} in ModeTable do
		print(`Processing world card for placeId: {placeId}, Type: {Type}`)
		local card = TemplateWorldCard:Clone()
		print(`Loading world card for placeId: {placeId}, Type: {Type}`)
		card.Parent = WorldParent
		card.LayoutOrder = WorldUIController.Index
		card.Visible = true
		card.Overlay.Visible = Type == "Normal" -- and worldTable.Index > 1

		local content = card.Content.Content

		if Type == "Normal" then
			card.Overlay.Title.Text = `Finish World {worldTable.Index - 1} to unlock`
			content.Title.Text = `World {worldTable.Index}`

			print(`Storing normal world card for index: {worldTable.Index}`)
			print(`WorldUIController.NormalCards before insert: {#WorldUIController.NormalCards}`)
			WorldUIController.NormalCards[worldTable.Index] = card
		else
			content.Title.Text = worldTable.Name
		end

		-- click connection
		content.Teleport.Button.Activated:Connect(function()
			RequestTeleport(placeId)
		end)

		WorldUIController.Index += 1
	end
end

return WorldUIController
