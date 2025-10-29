-- ResetProgressController.luau (CLIENT)
-- Robust controller for Reset UI confirmation flow (RestartFrame → SureRestartFrame)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local ResetProgressController = Knit.CreateController { Name = "ResetProgressController" }

local player = Players.LocalPlayer

-- Dynamic UI refs
local RestartFrame, RestartButtonFrame, RestartProgressButton, CloseButton
local SureRestartFrame, SureCloseButton, YesRestartProgressButton, NoRestartProgressButton

-- When server flips ResetUI=true while GUI isn't bound yet, we cache this to open ASAP
local pendingShow = false
local boundOk = false

-- ==== UI binding ====

local function tryGetMainGui(): Instance?
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	return pg:FindFirstChild("MainGui")
end

local function bindGui()
	local mainGui = tryGetMainGui()
	if not mainGui then
		boundOk = false
		return false
	end

	RestartFrame = mainGui:FindFirstChild("RestartFrame")
	SureRestartFrame = mainGui:FindFirstChild("SureRestartFrame")

	if not (RestartFrame and SureRestartFrame) then
		boundOk = false
		return false
	end

	RestartButtonFrame      = RestartFrame:FindFirstChild("RestartButtonFrame")
	RestartProgressButton   = RestartButtonFrame and RestartButtonFrame:FindFirstChild("RestartProgressButton")
	local closeFrame        = RestartFrame:FindFirstChild("CloseButtonFrame")
	CloseButton             = closeFrame and closeFrame:FindFirstChild("CloseButton")

	local sureCloseFrame    = SureRestartFrame:FindFirstChild("SureCloseButtonFrame")
	SureCloseButton         = sureCloseFrame and sureCloseFrame:FindFirstChild("SureCloseButton")
	local yesFrame          = SureRestartFrame:FindFirstChild("YesRestartButtonFrame")
	YesRestartProgressButton= yesFrame and yesFrame:FindFirstChild("YesRestartProgressButton")
	local noFrame           = SureRestartFrame:FindFirstChild("NoRestartButtonFrame")
	NoRestartProgressButton = noFrame and noFrame:FindFirstChild("NoRestartProgressButton")

	-- default hidden
	RestartFrame.Visible = false
	SureRestartFrame.Visible = false

	-- Buttons
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			RestartFrame.Visible = false
			SureRestartFrame.Visible = false
		end)
	end

	if RestartProgressButton then
		RestartProgressButton.MouseButton1Click:Connect(function()
			if RestartFrame and SureRestartFrame then
				RestartFrame.Visible = false
				SureRestartFrame.Visible = true
			end
		end)
	end

	if SureCloseButton then
		SureCloseButton.MouseButton1Click:Connect(function()
			RestartFrame.Visible = false
			SureRestartFrame.Visible = false
		end)
	end

	if NoRestartProgressButton then
		NoRestartProgressButton.MouseButton1Click:Connect(function()
			RestartFrame.Visible = false
			SureRestartFrame.Visible = false
		end)
	end

	if YesRestartProgressButton then
		YesRestartProgressButton.MouseButton1Click:Connect(function()
			YesRestartProgressButton.Active = false
			YesRestartProgressButton.AutoButtonColor = false

			local resetService = Knit.GetService("ResetProgressService")
			if resetService then
				local ok = resetService:RequestReset()
				if ok then
					print("[ResetProgressController] Reset requested.")
				else
					warn("[ResetProgressController] Reset request failed.")
				end
			else
				warn("[ResetProgressController] ResetProgressService missing.")
			end

			task.delay(3, function()
				if YesRestartProgressButton then
					YesRestartProgressButton.Active = true
					YesRestartProgressButton.AutoButtonColor = true
				end
			end)
		end)
	end

	boundOk = true
	print("[ResetProgressController] Bound Restart + SureRestart UI successfully.")

	-- If server already told us to show, open now
	if pendingShow then
		pendingShow = false
		RestartFrame.Visible = true
		SureRestartFrame.Visible = false
	end

	return true
end

-- Try repeatedly for a short while (useful on slow streams)
local function ensureBoundShortBurst()
	if bindGui() then return end
	for _ = 1, 10 do
		task.wait(0.15)
		if bindGui() then return end
	end
end

-- Watch for MainGui recreation
local function watchGuiRecreation()
	local pg = player:FindFirstChild("PlayerGui")
	local function attach(guiRoot)
		guiRoot.ChildAdded:Connect(function(ch)
			if ch.Name == "MainGui" then
				task.delay(0.05, ensureBoundShortBurst)
			end
		end)
	end
	if pg then
		attach(pg)
	else
		task.spawn(function()
			local g = player:WaitForChild("PlayerGui")
			attach(g)
		end)
	end
end

-- ==== Attribute reactions ====

local function onResetUIChanged()
	local val = player:GetAttribute("ResetUI")
	if val == true then
		if boundOk and RestartFrame and SureRestartFrame then
			RestartFrame.Visible = true
			SureRestartFrame.Visible = false
		else
			pendingShow = true
			ensureBoundShortBurst()
		end
	else
		if RestartFrame then RestartFrame.Visible = false end
		if SureRestartFrame then SureRestartFrame.Visible = false end
	end
end

local function onResetResultChanged()
	local result = player:GetAttribute("ResetResult")
	local msg = player:GetAttribute("ResetResultMsg")
	if result == "Success" then
		if RestartFrame then RestartFrame.Visible = false end
		if SureRestartFrame then SureRestartFrame.Visible = false end
		print("[ResetProgressController] Reset succeeded:", msg)
	elseif result == "Failure" then
		if RestartFrame then RestartFrame.Visible = false end
		if SureRestartFrame then SureRestartFrame.Visible = false end
		warn("[ResetProgressController] Reset failed:", msg)
	end
end

-- ==== Knit lifecycle ====

function ResetProgressController:KnitStart()
	print("[ResetProgressController] KnitStart (client)")

	ensureBoundShortBurst()
	watchGuiRecreation()

	player:GetAttributeChangedSignal("ResetUI"):Connect(onResetUIChanged)
	player:GetAttributeChangedSignal("ResetResult"):Connect(onResetResultChanged)

	-- Handle the case where ResetUI was already set before we bound.
	if player:GetAttribute("ResetUI") == true then
		pendingShow = true
		onResetUIChanged() 
	end
end

return ResetProgressController
