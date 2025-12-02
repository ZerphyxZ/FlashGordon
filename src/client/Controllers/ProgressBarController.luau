-- ProgressBarController.luau (robust GUI rebind)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local LocalPlayer = Players.LocalPlayer
local ProgressBarController = Knit.CreateController({ Name = "ProgressBarController" })

local ARROW_LOCAL = "rbxassetid://128437370719899"
local ARROW_OTHER = "rbxassetid://70872990203726"

-- Internal state that must be re-created when MainGui is recreated
local topBar, progressFrame, progressBarFrame, progressText
local template -- PlayerLocationTemplateFrame (hidden)
local locationsFolder
local markers = {}
local attrConn = nil
local playerGuiConn = nil

local function clampPercent(n)
	if not n then
		return 0
	end
	if n < 0 then
		return 0
	end
	if n > 100 then
		return 100
	end
	return math.floor(n + 0.000001)
end

local function positionMarkerFrame(frame, pct)
	local x = pct / 100
	local yScale = template.Position.Y.Scale
	local yOffset = template.Position.Y.Offset
	frame.Position = UDim2.new(x, -20, yScale, yOffset)
end

local function clearMarkers()
	for pl, m in pairs(markers) do
		if m.conn then
			m.conn:Disconnect()
		end
		if m.frame and m.frame.Parent then
			m.frame:Destroy()
		end
		markers[pl] = nil
	end
end

local function createMarkerForPlayer(player)
	if markers[player] then
		return
	end
	if not player or not player.Parent then
		return
	end
	if not template or not template.Parent then
		return
	end

	local clone = template:Clone()
	clone.Name = "Marker_" .. player.Name
	clone.Parent = locationsFolder
	clone.Visible = true

	local avatar = clone:FindFirstChild("PlayerAvatar_ImageLabel")
	if not avatar then
		avatar = clone:FindFirstChildWhichIsA("ImageLabel")
	end
	local arrow = clone:FindFirstChild("PlayerArrow_ImageLabel")

	markers[player] = {
		frame = clone,
		avatar = avatar,
		arrow = arrow,
		conn = nil,
	}

	-- listen for attribute changes on this player
	local dataConn
	dataConn = player:GetAttributeChangedSignal("ProgressPercent"):Connect(function()
		local pct = clampPercent(player:GetAttribute("ProgressPercent"))
		if clone and clone.Parent then
			positionMarkerFrame(clone, pct)
		end
	end)
	markers[player].conn = dataConn

	-- initial position
	task.delay(0.05, function()
		if player and player.Parent and clone and clone.Parent then
			local pct = clampPercent(player:GetAttribute("ProgressPercent"))
			positionMarkerFrame(clone, pct)
		end
	end)

	-- arrow image
	if arrow then
		if player == LocalPlayer then
			arrow.Image = ARROW_LOCAL
		else
			arrow.Image = ARROW_OTHER
		end
	end

	-- thumbnail fetch (safe)
	if avatar then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok and url then
				avatar.Image = url
			end
		end)
	end
end

local function removeMarker(player)
	local m = markers[player]
	if not m then
		return
	end
	if m.conn then
		pcall(function()
			m.conn:Disconnect()
		end)
	end
	if m.frame and m.frame.Parent then
		m.frame:Destroy()
	end
	markers[player] = nil
end

local function updateLocalBar()
	if not progressBarFrame or not progressText then
		return
	end
	local pct = clampPercent(LocalPlayer:GetAttribute("ProgressPercent"))
	progressText.Text = string.format("PROGRESS: %02d%%", pct)
	progressBarFrame.Size = UDim2.new(pct / 100, 0, 1, 0)
end

-- call when MainGui exists (rebind GUI references)
local function bindGui()
	-- clear previous marker connections and UI refs
	clearMarkers()

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		-- wait briefly until PlayerGui appears
		playerGui = LocalPlayer:WaitForChild("PlayerGui")
	end
	local mainGui = playerGui:FindFirstChild("MainGui")
	if not mainGui then
		-- nothing to bind yet
		topBar, progressFrame, progressBarFrame, progressText = nil, nil, nil, nil
		template = nil
		locationsFolder = nil
		return
	end

	local topBarFrame = mainGui:FindFirstChild("TopBarFrame")
	if not topBarFrame then
		topBar, progressFrame, progressBarFrame, progressText = nil, nil, nil, nil
		template = nil
		locationsFolder = nil
		return
	end

	topBar = topBarFrame
	progressFrame = topBar:FindFirstChild("ProgressFrame")
	if progressFrame then
		progressBarFrame = progressFrame:FindFirstChild("ProgressBarFrame")
		progressText = progressFrame:FindFirstChild("ProgressPercentageText")
		locationsFolder = progressFrame:FindFirstChild("PlayerLocations")
		if not locationsFolder then
			locationsFolder = Instance.new("Folder")
			locationsFolder.Name = "PlayerLocations"
			locationsFolder.Parent = progressFrame
		end
	end

	template = topBar:FindFirstChild("PlayerLocationTemplateFrame")
	if template then
		template.Visible = false
	end

	-- recreate markers for all players
	for _, pl in ipairs(Players:GetPlayers()) do
		createMarkerForPlayer(pl)
	end

	-- initial local bar update
	updateLocalBar()
end

function ProgressBarController:KnitStart()
	print("[ProgressBarController] KnitStart called (robust)")

	-- initial bind (will wait if necessary)
	bindGui()

	-- watch for MainGui recreation
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		if playerGuiConn then
			playerGuiConn:Disconnect()
		end
		playerGuiConn = pgui.ChildAdded:Connect(function(child)
			if child and child.Name == "MainGui" then
				-- small delay so nested frames are created
				task.delay(0.05, function()
					bindGui()
				end)
			end
		end)
	else
		task.spawn(function()
			local g = LocalPlayer:WaitForChild("PlayerGui")
			playerGuiConn = g.ChildAdded:Connect(function(child)
				if child and child.Name == "MainGui" then
					task.delay(0.05, bindGui)
				end
			end)
		end)
	end

	-- attribute tracking for local percent
	if attrConn then
		attrConn:Disconnect()
	end
	attrConn = LocalPlayer:GetAttributeChangedSignal("ProgressPercent"):Connect(updateLocalBar)

	-- create/remove player markers
	Players.PlayerAdded:Connect(function(pl)
		task.delay(0.08, function()
			createMarkerForPlayer(pl)
		end)
	end)
	Players.PlayerRemoving:Connect(function(pl)
		removeMarker(pl)
	end)

	-- init existing players (already handled in bindGui but keep safe)
	for _, pl in ipairs(Players:GetPlayers()) do
		if not markers[pl] then
			createMarkerForPlayer(pl)
		end
	end

	-- periodic ensure-sync (same behavior as before)
	task.spawn(function()
		while true do
			for pl, m in pairs(markers) do
				if pl and pl.Parent and m and m.frame then
					local pct = clampPercent(pl:GetAttribute("ProgressPercent"))
					if m.frame and m.frame.Parent then
						positionMarkerFrame(m.frame, pct)
						if m.arrow then
							if pl == LocalPlayer then
								m.arrow.Image = ARROW_LOCAL
							else
								m.arrow.Image = ARROW_OTHER
							end
						end
					end
				end
			end
			-- update local bar too
			updateLocalBar()
			task.wait(0.8)
		end
	end)
end

return ProgressBarController
