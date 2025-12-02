-- StarterPlayer/StarterPlayerScripts/Client/Controllers/ResetGameDataController.luau
-- Client controller for GLOBAL reset UI.
-- Robust binding, clear prints, and calls ConfirmGlobalReset() (falls back to RequestGlobalReset()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController({ Name = "ResetGameDataController" })

local player = Players.LocalPlayer

-- UI refs (auto-rebound when MainGui is recreated)
local FramePrimary: Frame? -- ResetGameDataFrame
local FrameConfirm: Frame? -- SureResetGameDataFrame
local BtnPrimary: TextButton? -- Main button inside primary frame
local BtnClosePrimary: TextButton?
local BtnYes: TextButton?
local BtnNo: TextButton?
local BtnCloseConfirm: TextButton?

local _bindConn
local _uiBound = false

-- ---- helpers ---------------------------------------------------------------

local function findDesc(root: Instance?, names: { string }): Instance?
	if not root then
		return nil
	end
	for _, n in ipairs(names) do
		local inst = root:FindFirstChild(n, true)
		if inst then
			return inst
		end
	end
	return nil
end

local function bindUi()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		print("[ResetGameDataController] MainGui not ready")
		return false
	end
	local main = pg:FindFirstChild("MainGui")
	if not main then
		print("[ResetGameDataController] MainGui not ready")
		return false
	end

	FramePrimary = (findDesc(main, { "ResetGameDataFrame" })) :: Frame
	FrameConfirm = (findDesc(main, { "SureResetGameDataFrame" })) :: Frame

	if not (FramePrimary and FrameConfirm) then
		print("[ResetGameDataController] MainGui not ready")
		return false
	end

	-- Buttons (be flexible with possible names in UI)
	BtnPrimary = (findDesc(FramePrimary, { "ResetGameDataButton", "ResetButton", "PrimaryButton" })) :: TextButton
	BtnClosePrimary = (findDesc(FramePrimary, { "CloseButton", "CloseResetGameDataButton" })) :: TextButton

	BtnYes = (findDesc(FrameConfirm, { "YesResetGameDataButton", "YesButton" })) :: TextButton
	BtnNo = (findDesc(FrameConfirm, { "NoResetGameDataButton", "NoButton" })) :: TextButton
	BtnCloseConfirm = (findDesc(FrameConfirm, { "CloseButton", "SureCloseButton" })) :: TextButton

	-- Default hidden; server toggles via attribute
	FramePrimary.Visible = false
	FrameConfirm.Visible = false

	-- Wire buttons
	if BtnPrimary then
		BtnPrimary.MouseButton1Click:Connect(function()
			print("[ResetGameDataController] Primary button clicked → show confirmation")
			if FramePrimary then
				FramePrimary.Visible = false
			end
			if FrameConfirm then
				FrameConfirm.Visible = true
			end
		end)
	end

	if BtnClosePrimary then
		BtnClosePrimary.MouseButton1Click:Connect(function()
			if FramePrimary then
				FramePrimary.Visible = false
			end
			if FrameConfirm then
				FrameConfirm.Visible = false
			end
			player:SetAttribute("ResetGameDataUI", false)
		end)
	end

	if BtnNo then
		BtnNo.MouseButton1Click:Connect(function()
			print("[ResetGameDataController] NO clicked")
			if FrameConfirm then
				FrameConfirm.Visible = false
			end
			if FramePrimary then
				FramePrimary.Visible = false
			end
			player:SetAttribute("ResetGameDataUI", false)
		end)
	end

	if BtnCloseConfirm then
		BtnCloseConfirm.MouseButton1Click:Connect(function()
			if FrameConfirm then
				FrameConfirm.Visible = false
			end
			if FramePrimary then
				FramePrimary.Visible = false
			end
			player:SetAttribute("ResetGameDataUI", false)
		end)
	end

	if BtnYes then
		BtnYes.MouseButton1Click:Connect(function()
			print("[ResetGameDataController] YES clicked → Request/Confirm Global Reset")
			local svc = Knit.GetService("ResetGameDataService")
			if not svc then
				warn("[ResetGameDataController] ResetGameDataService not available")
				return
			end

			-- Prefer the new name; fall back to old if needed.
			local called = false
			if svc.ConfirmGlobalReset then
				local r = svc:ConfirmGlobalReset()
				called = true
				print("[ResetGameDataController] ConfirmGlobalReset returned:", r)
			elseif svc.RequestGlobalReset then
				local r = svc:RequestGlobalReset()
				called = true
				print("[ResetGameDataController] RequestGlobalReset returned:", r)
			end

			if not called then
				warn("[ResetGameDataController] Neither ConfirmGlobalReset nor RequestGlobalReset exists on service")
			end
		end)
	end

	_uiBound = true
	print("[ResetGameDataController] UI bound successfully")
	return true
end

local function watchMainGui()
	if _bindConn then
		_bindConn:Disconnect()
	end
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
	_bindConn = pg.ChildAdded:Connect(function(ch)
		if ch.Name == "MainGui" then
			task.delay(0.05, bindUi)
		end
	end)
end

-- ---- attribute reactions ---------------------------------------------------

local function onResetAttr()
	local v = player:GetAttribute("ResetGameDataUI")
	print("[ResetGameDataController] ResetGameDataUI changed →", v)
	if not _uiBound then
		if not bindUi() then
			return
		end
	end
	if v == true then
		if FramePrimary then
			FramePrimary.Visible = true
		end
		if FrameConfirm then
			FrameConfirm.Visible = false
		end
	else
		if FramePrimary then
			FramePrimary.Visible = false
		end
		if FrameConfirm then
			FrameConfirm.Visible = false
		end
	end
end

-- ---- Knit lifecycle --------------------------------------------------------

function Controller:KnitStart()
	print("[ResetGameDataController] KnitStart (client/global)")
	bindUi()
	watchMainGui()
	player:GetAttributeChangedSignal("ResetGameDataUI"):Connect(onResetAttr)

	-- If server already set it before we bound
	if player:GetAttribute("ResetGameDataUI") == true then
		onResetAttr()
	end
end

return Controller
