-- StarterPlayer/StarterPlayerScripts/Client/Controllers/PortalController.luau
-- Adds promise handling + toast notifications when teleports are blocked (Studio).

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui    = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "PortalController" }

local player = Players.LocalPlayer

-- UI refs
local SurePortalFrame : Frame?
local YesPortalButton : TextButton?
local NoPortalButton  : TextButton?
local SureCloseButton : TextButton?
local PortalText      : TextLabel?

local _yesConn, _noConn, _closeConn

local function sendToast(title: string, text: string, dur: number?)
	local ok, err = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Notice";
			Text  = text or "";
			Duration = dur or 5;
		})
	end)
	if not ok then
		warn("[PortalController] SendNotification failed:", err)
	end
end

local function findDescendantByNames(root: Instance, names: {string}): Instance?
	for _, n in ipairs(names) do
		local inst = root:FindFirstChild(n, true)
		if inst then return inst end
	end
	return nil
end

local function captureUiRefs(): boolean
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return false end
	local main = gui:FindFirstChild("MainGui")
	if not main then return false end

	SurePortalFrame = main:FindFirstChild("SurePortalFrame") or main:FindFirstChild("SurePortalFrame", true)
	if not (SurePortalFrame and SurePortalFrame:IsA("Frame")) then
		warn("[PortalController] SurePortalFrame not found")
		return false
	end

	YesPortalButton = findDescendantByNames(SurePortalFrame, { "YesPortalButton", "YesResetProgressButton", "YesResetProgressButton" }) :: TextButton
	NoPortalButton  = findDescendantByNames(SurePortalFrame, { "NoPortalButton", "NoPortalProgressButton", "NoResetProgressButton" }) :: TextButton
	SureCloseButton = findDescendantByNames(SurePortalFrame, { "SureCloseButton" }) :: TextButton
	PortalText      = findDescendantByNames(SurePortalFrame, { "PortalText" }) :: TextLabel

	print("[PortalController] Found refs: Frame=",tostring(SurePortalFrame~=nil),
		"Yes=",tostring(YesPortalButton~=nil),
		"No=",tostring(NoPortalButton~=nil),
		"Close=",tostring(SureCloseButton~=nil),
		"Text=",tostring(PortalText~=nil))

	return true
end

local function setVisible(show: boolean)
	if SurePortalFrame then
		SurePortalFrame.Visible = show
		print("[PortalController] SurePortalFrame.Visible =", show)
	end
end

local function updateText()
	if not PortalText then return end
	local idx = player:GetAttribute("PortalTargetIndex")
	PortalText.Text = string.format("Are you sure you want to Teleported to World %d?", idx or 0)
	print("[PortalController] PortalText set to:", PortalText.Text)
end

local function closeUiAndCancel()
	local svc = Knit.GetService("PortalService")
	print("[PortalController] Closing UI → CancelTeleport()")
	if svc and svc.CancelTeleport then svc:CancelTeleport() end
	setVisible(false)
end

local function bindButtons()
	if _yesConn then _yesConn:Disconnect() end
	if _noConn then _noConn:Disconnect() end
	if _closeConn then _closeConn:Disconnect() end

	local svc = Knit.GetService("PortalService")
	if not svc then
		warn("[PortalController] PortalService not available")
		return
	end

	if YesPortalButton then
		_yesConn = YesPortalButton.MouseButton1Click:Connect(function()
			print("[PortalController] YES clicked → ConfirmTeleport()")
			setVisible(false)
			local p = svc:ConfirmTeleport()
			if p and p.andThen then
				p:andThen(function(ok)
					print("[PortalController] ConfirmTeleport resolved →", tostring(ok))
					if ok == false then
						-- server already set a PortalNotice; client will show it
					end
				end):catch(function(err)
					warn("[PortalController] ConfirmTeleport rejected:", tostring(err))
				end)
			else
				-- Knit may return boolean directly if configured that way
				print("[PortalController] ConfirmTeleport returned non-promise:", tostring(p))
			end
		end)
	else
		warn("[PortalController] YesPortalButton not found in UI")
	end

	if NoPortalButton then
		_noConn = NoPortalButton.MouseButton1Click:Connect(function()
			print("[PortalController] NO clicked")
			closeUiAndCancel()
		end)
	else
		warn("[PortalController] NoPortalButton not found in UI")
	end

	if SureCloseButton then
		_closeConn = SureCloseButton.MouseButton1Click:Connect(function()
			print("[PortalController] CLOSE clicked")
			closeUiAndCancel()
		end)
	else
		warn("[PortalController] SureCloseButton not found in UI")
	end
end

function Controller:KnitStart()
	print("[PortalController] KnitStart (client)")

	if captureUiRefs() then
		setVisible(false)
		bindButtons()
	end

	-- Open/close driven by server attribute
	player:GetAttributeChangedSignal("PortalUI"):Connect(function()
		local show = player:GetAttribute("PortalUI") == true
		if show then
			if captureUiRefs() then
				updateText(); bindButtons(); setVisible(true)
			else
				task.delay(0.2, function()
					if captureUiRefs() then updateText(); bindButtons(); setVisible(true) end
				end)
			end
		else
			setVisible(false)
		end
	end)

	-- Update text if destination changes while open
	player:GetAttributeChangedSignal("PortalTargetIndex"):Connect(function()
		if player:GetAttribute("PortalUI") == true then updateText() end
	end)

	-- Show notices coming from server (Studio block, TeleportInitFailed, etc.)
	player:GetAttributeChangedSignal("PortalNotice"):Connect(function()
		local msg = player:GetAttribute("PortalNotice")
		if msg and msg ~= "" then
			sendToast("Teleport", tostring(msg), 6)
			print("[PortalController] Notice:", msg)
			player:SetAttribute("PortalNotice", nil) -- clear
		end
	end)

	-- Re-capture when MainGui is recreated
	player:WaitForChild("PlayerGui").ChildAdded:Connect(function(child)
		if child.Name == "MainGui" then
			task.delay(0.2, function()
				if captureUiRefs() then
					bindButtons()
					setVisible(player:GetAttribute("PortalUI") == true)
					if player:GetAttribute("PortalUI") == true then updateText() end
				end
			end)
		end
	end)
end

return Controller
