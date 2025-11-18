-- StarterPlayer/StarterPlayerScripts/Client/Controllers/ResetProgressController.luau
-- Client controller for PLACE-ONLY reset UI.
-- Listens to both ResetProgressUI (new) and ResetUI (legacy).
-- Shows ResetProgressFrame; confirmation in SureResetProgressFrame.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "ResetProgressController" }

local player = Players.LocalPlayer

-- UI refs
local FramePrimary  : Frame?      -- ResetProgressFrame
local FrameConfirm  : Frame?      -- SureResetProgressFrame
local BtnPrimary    : TextButton? -- ResetProgressButton
local BtnClosePrim  : TextButton?
local BtnYes        : TextButton?
local BtnNo         : TextButton?
local BtnCloseConf  : TextButton?

local _bound = false
local _bindConn

-- ---------- helpers ----------------------------------------------------------

local function findDesc(root: Instance?, names: {string}): Instance?
	if not root then return nil end
	for _, n in ipairs(names) do
		local inst = root:FindFirstChild(n, true)
		if inst then return inst end
	end
	return nil
end

local function bindUi(): boolean
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then print("[ResetProgressController] MainGui not ready"); return false end
	local main = pg:FindFirstChild("MainGui")
	if not main then print("[ResetProgressController] MainGui not ready"); return false end

	FramePrimary = (findDesc(main, { "ResetProgressFrame", "RestartFrame" })) :: Frame
	FrameConfirm = (findDesc(main, { "SureResetProgressFrame", "SureRestartFrame" })) :: Frame

	if not (FramePrimary and FrameConfirm) then
		print("[ResetProgressController] MainGui not ready")
		return false
	end

	BtnPrimary   = (findDesc(FramePrimary, { "ResetProgressButton", "RestartProgressButton" })) :: TextButton
	BtnClosePrim = (findDesc(FramePrimary, { "CloseButton", "CloseRestartButton" })) :: TextButton
	BtnYes       = (findDesc(FrameConfirm, { "YesResetProgressButton", "YesRestartProgressButton" })) :: TextButton
	BtnNo        = (findDesc(FrameConfirm, { "NoResetProgressButton", "NoRestartProgressButton" })) :: TextButton
	BtnCloseConf = (findDesc(FrameConfirm, { "SureCloseButton", "CloseButton" })) :: TextButton

	FramePrimary.Visible = false
	FrameConfirm.Visible = false

	if BtnPrimary then
		BtnPrimary.MouseButton1Click:Connect(function()
			print("[ResetProgressController] Primary clicked → open confirm")
			if FramePrimary then FramePrimary.Visible = false end
			if FrameConfirm then FrameConfirm.Visible = true end
		end)
	end
	if BtnClosePrim then
		BtnClosePrim.MouseButton1Click:Connect(function()
			if FramePrimary then FramePrimary.Visible = false end
			if FrameConfirm then FrameConfirm.Visible = false end
			player:SetAttribute("ResetProgressUI", false)
			player:SetAttribute("ResetUI", false)
		end)
	end
	if BtnNo then
		BtnNo.MouseButton1Click:Connect(function()
			print("[ResetProgressController] NO clicked")
			if FrameConfirm then FrameConfirm.Visible = false end
			if FramePrimary then FramePrimary.Visible = false end
			player:SetAttribute("ResetProgressUI", false)
			player:SetAttribute("ResetUI", false)
		end)
	end
	if BtnCloseConf then
		BtnCloseConf.MouseButton1Click:Connect(function()
			if FrameConfirm then FrameConfirm.Visible = false end
			if FramePrimary then FramePrimary.Visible = false end
			player:SetAttribute("ResetProgressUI", false)
			player:SetAttribute("ResetUI", false)
		end)
	end
	if BtnYes then
		BtnYes.MouseButton1Click:Connect(function()
			print("[ResetProgressController] YES clicked → ConfirmPlaceReset()")
			local svc = Knit.GetService("ResetProgressService")
			if not svc then
				warn("[ResetProgressController] ResetProgressService missing")
				return
			end
			if svc.ConfirmPlaceReset then
				local r = svc:ConfirmPlaceReset()
				print("[ResetProgressController] ConfirmPlaceReset returned:", r)
			elseif svc.RequestReset then
				local r = svc:RequestReset()
				print("[ResetProgressController] RequestReset returned:", r)
			else
				warn("[ResetProgressController] No confirm/reset method on service")
			end
		end)
	end

	_bound = true
	print("[ResetProgressController] UI bound successfully")
	return true
end

local function watchGui()
	if _bindConn then _bindConn:Disconnect() end
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
	_bindConn = pg.ChildAdded:Connect(function(ch)
		if ch.Name == "MainGui" then
			task.delay(0.05, bindUi)
		end
	end)
end

-- ---------- attribute reactions ---------------------------------------------

local function applyVisibility(open: boolean)
	if not _bound then
		if not bindUi() then return end
	end
	if FramePrimary and FrameConfirm then
		FramePrimary.Visible = open
		FrameConfirm.Visible = false
	end
end

local function onNewAttr()
	local v = player:GetAttribute("ResetProgressUI")
	print("[ResetProgressController] ResetProgressUI changed →", v)
	applyVisibility(v == true)
end

local function onLegacyAttr()
	local v = player:GetAttribute("ResetUI")
	print("[ResetProgressController] ResetUI (legacy) changed →", v)
	applyVisibility(v == true)
end

-- ---------- Knit lifecycle ---------------------------------------------------

function Controller:KnitStart()
	print("[ResetProgressController] KnitStart (client/place-only)")
	bindUi()
	watchGui()

	-- Listen to both names, so either server spelling opens the UI
	player:GetAttributeChangedSignal("ResetProgressUI"):Connect(onNewAttr)
	player:GetAttributeChangedSignal("ResetUI"):Connect(onLegacyAttr)

	-- If server already set before we bound, honor it
	if player:GetAttribute("ResetProgressUI") == true then
		onNewAttr()
	elseif player:GetAttribute("ResetUI") == true then
		onLegacyAttr()
	end
end

return Controller
