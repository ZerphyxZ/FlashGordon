-- StarterPlayer/StarterPlayerScripts/Client/Controllers/SpinController.luau

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "SpinController" }
local LOCAL = Players.LocalPlayer

-- ====== UI refs ==============================================================
local SpinsFrame        : Frame?
local CloseButton       : ImageButton?  -- Spins.CloseButtonFrame.CloseButton
local TimeLabel         : TextLabel?    -- Spins.TimeLabel_DailySpin
local WheelInner        : ImageLabel?   -- Spins.MainSpinFrame.SpinWheelFrame.WheelInnter_SpinWheel
local PointerImage      : ImageLabel?   -- Spins.MainSpinFrame.SpinWheelFrame.Pointer_SpinWheel
local SpinButton        : TextButton?   -- Spins.SpinButtonsLineFrame.MainSpinButtonFrame.SpinButton
local SpinButtonText    : TextLabel?    -- SpinButton.SpinButtonText

-- Coins label (exact name under MainGui)
local CoinsTextLabel    : TextLabel?

local coinsPollConn: RBXScriptConnection? = nil
local lastCoinsValue: number? = nil

-- ====== State ================================================================
local spinsAvailable: number = 0
local nextUnix: number = 0
local isSpinning: boolean = false
local activeTween: Tween? = nil

local timerConn: RBXScriptConnection? = nil
local guiWatcherConn: RBXScriptConnection? = nil
local attrConnSpins: RBXScriptConnection? = nil
local attrConnNext : RBXScriptConnection? = nil
local attrConnCoins: RBXScriptConnection? = nil

-- leaderstats watchers (rebind if recreated)
local leaderstatsConn: RBXScriptConnection? = nil
local coinsAddedConn: RBXScriptConnection? = nil
local coinsChangedConn: RBXScriptConnection? = nil

-- Heartbeat tick control + zero-poll cooldown
local lastTimerSecond = -1
local lastZeroPollAt = 0
local ZERO_POLL_COOLDOWN = 3

-- Animation tunables (keep aligned with server)
local ANIM_SECONDS = 5.0
local WHOLE_ROTATIONS_DEG = 6 * 360
local EASING_STYLE = Enum.EasingStyle.Exponential
local EASING_DIR   = Enum.EasingDirection.Out

-- ====== Debug ================================================================
local function dprint(...) print("[SpinController]", ...) end
local function wprint(...) warn("[SpinController]", ...) end

-- ====== Helpers ==============================================================

local function getMainGui(): ScreenGui?
	local pg = LOCAL:FindFirstChild("PlayerGui")
	if not pg then return nil end
	return pg:FindFirstChild("MainGui") :: ScreenGui
end

local function findFirstDescByName(root: Instance?, name: string): Instance?
	if not (root and root:IsDescendantOf(game)) then return nil end
	return root:FindFirstChild(name, true)
end

local function findUi()
	local main = getMainGui()
	if not main then
		dprint("MainGui not present yet")
		return false
	end

	local spins = main:FindFirstChild("Spins")
	if not (spins and spins:IsA("Frame")) then
		dprint("UI not ready yet (Spins hierarchy not found)")
		return false
	end

	local closeFrame = spins:FindFirstChild("CloseButtonFrame")
	local closeBtn   = closeFrame and closeFrame:FindFirstChild("CloseButton")
	local timeLbl    = spins:FindFirstChild("TimeLabel_DailySpin")

	local mainSpin   = spins:FindFirstChild("MainSpinFrame")
	local wheelWrap  = mainSpin and mainSpin:FindFirstChild("SpinWheelFrame")
	local wheelInner = wheelWrap and wheelWrap:FindFirstChild("WheelInnter_SpinWheel")
	local pointer    = wheelWrap and wheelWrap:FindFirstChild("Pointer_SpinWheel")

	local btnLine    = spins:FindFirstChild("SpinButtonsLineFrame")
	local btnFrame   = btnLine and btnLine:FindFirstChild("MainSpinButtonFrame")
	local spinBtn    = btnFrame and btnFrame:FindFirstChild("SpinButton")
	local spinTxt    = spinBtn and spinBtn:FindFirstChild("SpinButtonText")

	if closeBtn and closeBtn:IsA("ImageButton") then
		CloseButton = closeBtn
		dprint("CloseButton wired (class:", CloseButton.ClassName, ")")
	else
		CloseButton = nil
	end

	SpinsFrame     = spins
	TimeLabel      = timeLbl and timeLbl:IsA("TextLabel") and (timeLbl :: any) or nil
	WheelInner     = wheelInner and wheelInner:IsA("ImageLabel") and (wheelInner :: any) or nil
	PointerImage   = pointer and pointer:IsA("ImageLabel") and (pointer :: any) or nil
	SpinButton     = spinBtn and spinBtn:IsA("TextButton") and (spinBtn :: any) or nil
	SpinButtonText = spinTxt and spinTxt:IsA("TextLabel") and (spinTxt :: any) or nil

	local coins = findFirstDescByName(main, "CoinsTextLabel")
	if coins and coins:IsA("TextLabel") then
		CoinsTextLabel = coins
		dprint("CoinsTextLabel wired:", CoinsTextLabel:GetFullName())
	else
		CoinsTextLabel = nil
		wprint("CoinsTextLabel not found under MainGui (named exactly 'CoinsTextLabel')")
	end

	dprint("Spins UI bound:",
		"SpinsFrame=", SpinsFrame and SpinsFrame:GetFullName() or "nil",
		"CloseButton=", CloseButton and CloseButton:GetFullName() or "nil",
		"TimeLabel=", TimeLabel and TimeLabel:GetFullName() or "nil",
		"WheelInner=", WheelInner and WheelInner:GetFullName() or "nil",
		"Pointer=", PointerImage and PointerImage:GetFullName() or "nil",
		"SpinButton=", SpinButton and SpinButton:GetFullName() or "nil",
		"SpinButtonText=", SpinButtonText and SpinButtonText:GetFullName() or "nil"
	)

	return true
end

-- Format helpers
local function formatHMS(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function formatCoins(n: number): string
	local s = tostring(math.floor(n))
	repeat
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	until false
	return s
end

-- ====== UI updates ===========================================================
local function refreshButtonLabel()
	if not SpinButtonText then return end
	local txt
	if spinsAvailable and spinsAvailable > 0 then
		txt = string.format("Spin (%d)", spinsAvailable)
	else
		txt = "Spin"
	end
	SpinButtonText.Text = txt
	dprint("SpinButtonText →", txt)
end

local function updateTimerText()
	if not TimeLabel then return end
	if (not nextUnix) or nextUnix == 0 then
		if spinsAvailable >= 8 then
			TimeLabel.Text = "You reached maximum limit of Spin which is 8"
		else
			TimeLabel.Text = "Get next Spin in: 00:00:00"
		end
		return
	end

	local now = os.time()
	local remain = nextUnix - now
	if remain <= 0 then
		TimeLabel.Text = "Get next Spin in: 00:00:00"
	else
		TimeLabel.Text = "Get next Spin in: " .. formatHMS(remain)
	end
end

local function updateCoinsLabel(numberValue: number?)
	if not CoinsTextLabel then return end
	if typeof(numberValue) == "number" then
		CoinsTextLabel.Text = formatCoins(numberValue)
		dprint("CoinsTextLabel updated →", CoinsTextLabel.Text)
	end
end

-- Try attribute first, then leaderstats fallback
local function updateCoinsLabelFromSources()
	local a = LOCAL:GetAttribute("Coins") or LOCAL:GetAttribute("CoinsBalance") or LOCAL:GetAttribute("Coin")
	if typeof(a) == "number" then
		updateCoinsLabel(a)
		return
	end
	local ls = LOCAL:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	if c and (c:IsA("IntValue") or c:IsA("NumberValue")) then
		updateCoinsLabel(c.Value)
	end
end

local function flashSpinTextRedTwice()
	if not SpinButtonText then return end
	local original = SpinButtonText.TextColor3
	for _ = 1, 2 do
		SpinButtonText.TextColor3 = Color3.fromRGB(255, 60, 60)
		task.wait(0.12)
		SpinButtonText.TextColor3 = original
		task.wait(0.12)
	end
end

local function setSpinButtonEnabled(enabled: boolean)
	if SpinButton then
		SpinButton.AutoButtonColor = enabled
		SpinButton.Active = enabled
		SpinButton.Selectable = enabled
		SpinButton.Modal = false
		SpinButton.BackgroundTransparency = enabled and 0 or 0.2
	end
end

-- ====== Wheel animation ======================================================
local function killActiveTween()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
end

local function animateWheelToDelta(deltaDeg: number, onComplete: (() -> ())?)
	if not WheelInner then
		wprint("WheelInner missing; cannot animate")
		if onComplete then onComplete() end
		return
	end

	local startRot = (WheelInner.Rotation % 360 + 360) % 360
	local targetRot = startRot + WHOLE_ROTATIONS_DEG + deltaDeg

	dprint(("Animating wheel start=%.1f target=%.1f (delta=%d)"):format(startRot, targetRot, deltaDeg))

	killActiveTween()
	activeTween = TweenService:Create(
		WheelInner,
		TweenInfo.new(ANIM_SECONDS, EASING_STYLE, EASING_DIR),
		{ Rotation = targetRot }
	)

	activeTween.Completed:Once(function(state)
		dprint("Wheel tween Completed with state:", tostring(state))
		if WheelInner and WheelInner.Parent then
			WheelInner.Rotation = ((WheelInner.Rotation % 360) + 360) % 360
		end
		activeTween = nil

		-- force HUD reconcile via CoinsController (if it’s loaded)
		local coinsCtrl = Knit.GetController("CoinsController")
		if coinsCtrl and coinsCtrl.RefreshDisplay then
			coinsCtrl:RefreshDisplay()
			-- nudge again shortly in case leaderstats/attrs arrive a tick later
			task.delay(0.5, function()
				local c = Knit.GetController("CoinsController")
				if c and c.RefreshDisplay then c:RefreshDisplay() end
			end)
		end

		if onComplete then onComplete() end
	end)

	activeTween:Play()
end

-- ====== Promise helper =======================================================
local function isPromise(x: any): boolean
	return type(x) == "table" and x.andThen and type(x.andThen) == "function"
end

-- ====== Knit calls ===========================================================
local function applyServerState(tbl)
	if type(tbl) ~= "table" then return end
	spinsAvailable = tonumber(tbl.spins) or 0
	nextUnix = tonumber(tbl.nextUnix) or 0
	dprint(("Server state → spins=%s nextUnix=%s"):format(tostring(spinsAvailable), tostring(nextUnix)))
	refreshButtonLabel()
	updateTimerText()
end

local function requestStateFromServer()
	local svc = Knit.GetService("SpinService")
	dprint("Requesting state from server …")
	local ok, ret = pcall(function() return svc:GetState() end)
	if not ok then
		wprint("GetState pcall failed:", ret)
		return
	end
	if isPromise(ret) then
		ret:andThen(function(tbl)
			applyServerState(tbl)
		end):catch(function(err)
			wprint("GetState promise rejected:", err)
		end)
	elseif typeof(ret) == "table" then
		applyServerState(ret)
	else
		wprint("GetState returned unexpected type; ignoring")
	end
end

local function callSpinAndAnimate()
	if isSpinning then
		dprint("Spin click ignored (already spinning)")
		return
	end
	if (spinsAvailable or 0) <= 0 then
		dprint("SpinButton clicked with 0 spins → flashing red")
		flashSpinTextRedTwice()
		return
	end

	local svc = Knit.GetService("SpinService")
	dprint("Requesting spin from server …")
	isSpinning = true
	setSpinButtonEnabled(false)

	local function handleResult(res: any)
		if type(res) ~= "table" then
			dprint("Spin returned non-table → treating as failure")
			isSpinning = false
			setSpinButtonEnabled(true)
			return
		end
		if not res.ok then
			dprint("Spin rejected by server")
			isSpinning = false
			setSpinButtonEnabled(true)
			if res.reason == "NoSpins" then flashSpinTextRedTwice() end
			return
		end

		local deltaDeg = math.floor(tonumber(res.deltaDeg) or 0)

		-- Immediate local UI update (no waiting for attrs)
		if typeof(res.spins) == "number" then
			spinsAvailable = res.spins
			refreshButtonLabel()
		end
		if typeof(res.nextUnix) == "number" then
			nextUnix = res.nextUnix
			updateTimerText()
		end

		dprint(("Spin accepted → deltaDeg=%d, prize=%s, spinsLeft=%s nextUnix=%s")
			:format(deltaDeg, tostring(res.prizeKey), tostring(res.spins), tostring(res.nextUnix)))

		animateWheelToDelta(deltaDeg, function()
			-- Post-animation probes to catch delayed coin updates or recreated leaderstats
			local delays = {0.15, 0.5, 1.0, 2.0, 3.0}
			for _, t in ipairs(delays) do
				task.delay(t, updateCoinsLabelFromSources)
			end

			-- Refresh spins/timer from authoritative server state
			task.delay(0.2, function()
				requestStateFromServer()
				refreshButtonLabel()
				updateTimerText()
			end)

			isSpinning = false
			setSpinButtonEnabled(true)
		end)
	end

	local ok, ret = pcall(function() return svc:Spin() end)
	if ok and isPromise(ret) then
		ret:andThen(handleResult):catch(function(err)
			wprint("[SpinController] Spin promise rejected:", err)
			isSpinning = false
			setSpinButtonEnabled(true)
		end)
	elseif ok and typeof(ret) == "table" then
		handleResult(ret)
	else
		wprint("[SpinController] Spin call failed (pcall not ok or unexpected return)")
		isSpinning = false
		setSpinButtonEnabled(true)
	end
end

-- ====== Attribute + leaderstats listeners ===================================
local function onAttrChange(attrName: string, val: any)
	if attrName == "SpinsAvailable" then
		spinsAvailable = tonumber(val) or 0
		dprint("Attribute → SpinsAvailable =", spinsAvailable)
		refreshButtonLabel()
	elseif attrName == "SpinNextUnix" then
		nextUnix = tonumber(val) or 0
		dprint("Attribute → SpinNextUnix =", nextUnix)
		updateTimerText()
	elseif attrName == "Coins" or attrName == "CoinsBalance" or attrName == "Coin" then
		dprint("Attribute →", attrName, "=", tostring(val))
		updateCoinsLabelFromSources()
	end
end

local function disconnectLeaderstatsWatchers()
	if coinsChangedConn then coinsChangedConn:Disconnect() coinsChangedConn = nil end
	if coinsAddedConn then coinsAddedConn:Disconnect() coinsAddedConn = nil end
	if leaderstatsConn then leaderstatsConn:Disconnect() leaderstatsConn = nil end
end

local function bindLeaderstatsCoins()
	disconnectLeaderstatsWatchers()

	local ls = LOCAL:FindFirstChild("leaderstats")
	if ls then
		-- when Coins value appears (or is replaced), (re)bind its .Changed
		local function hookCoins(v)
			if coinsChangedConn then coinsChangedConn:Disconnect() coinsChangedConn = nil end
			if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
				coinsChangedConn = v.Changed:Connect(function(newVal)
					dprint("leaderstats.Coins changed →", tostring(newVal))
					updateCoinsLabel(v.Value)
				end)
				updateCoinsLabel(v.Value)
			end
		end

		coinsAddedConn = ls.ChildAdded:Connect(function(ch)
			if ch.Name == "Coins" then
				hookCoins(ch)
			end
		end)
		ls.ChildRemoved:Connect(function(ch)
			if ch.Name == "Coins" then
				if coinsChangedConn then coinsChangedConn:Disconnect() coinsChangedConn = nil end
				-- label will be re-seeded when new Coins appears
			end
		end)

		local existing = ls:FindFirstChild("Coins")
		if existing then
			hookCoins(existing)
		end
	else
		-- leaderstats not present yet; watch for it to appear
		leaderstatsConn = LOCAL.ChildAdded:Connect(function(ch)
			if ch.Name == "leaderstats" then
				bindLeaderstatsCoins()
			end
		end)
	end
end

local function bindAttributeMirrors()
	if attrConnSpins then attrConnSpins:Disconnect() end
	if attrConnNext  then attrConnNext :Disconnect() end
	if attrConnCoins then attrConnCoins:Disconnect() end

	attrConnSpins = LOCAL:GetAttributeChangedSignal("SpinsAvailable"):Connect(function()
		onAttrChange("SpinsAvailable", LOCAL:GetAttribute("SpinsAvailable"))
		refreshButtonLabel()
	end)
	attrConnNext = LOCAL:GetAttributeChangedSignal("SpinNextUnix"):Connect(function()
		onAttrChange("SpinNextUnix", LOCAL:GetAttribute("SpinNextUnix"))
		updateTimerText()
	end)
	attrConnCoins = LOCAL:GetAttributeChangedSignal("Coins"):Connect(function()
		onAttrChange("Coins", LOCAL:GetAttribute("Coins"))
		local coinsCtrl = Knit.GetController("CoinsController")
		if coinsCtrl and coinsCtrl.RefreshDisplay then
			coinsCtrl:RefreshDisplay()
		end
	end)

	-- Seed from current attrs and coins sources
	onAttrChange("SpinsAvailable", LOCAL:GetAttribute("SpinsAvailable"))
	onAttrChange("SpinNextUnix", LOCAL:GetAttribute("SpinNextUnix"))
	updateCoinsLabelFromSources()
	bindLeaderstatsCoins()
end

-- ====== Timer loop with persistent zero polling ==============================
local function startTimerLoop()
	if timerConn then timerConn:Disconnect() end
	lastTimerSecond = -1
	lastZeroPollAt = 0

	timerConn = RunService.Heartbeat:Connect(function()
		local now = os.time()
		if now == lastTimerSecond then return end
		lastTimerSecond = now

		updateTimerText()

		if nextUnix and nextUnix > 0 then
			local remain = nextUnix - now
			if remain <= 0 then
				if (now - lastZeroPollAt) >= ZERO_POLL_COOLDOWN then
					lastZeroPollAt = now
					dprint("Timer reached 00:00:00 → polling server for updated spins …")
					requestStateFromServer()
					updateCoinsLabelFromSources()
					refreshButtonLabel()
					updateTimerText()
				end
			end
		end
	end)
	dprint("Timer loop started")
end

-- REPLACE your whole findUi() with this exact version
local function findUi()
	local main = getMainGui()
	if not main then
		dprint("MainGui not present yet")
		return false
	end

	local spins = main:FindFirstChild("Spins")
	if not (spins and spins:IsA("Frame")) then
		dprint("UI not ready yet (Spins hierarchy not found)")
		return false
	end

	local closeFrame = spins:FindFirstChild("CloseButtonFrame")
	local closeBtn   = closeFrame and closeFrame:FindFirstChild("CloseButton")
	local timeLbl    = spins:FindFirstChild("TimeLabel_DailySpin")

	local mainSpin   = spins:FindFirstChild("MainSpinFrame")
	local wheelWrap  = mainSpin and mainSpin:FindFirstChild("SpinWheelFrame")
	local wheelInner = wheelWrap and wheelWrap:FindFirstChild("WheelInnter_SpinWheel")
	local pointer    = wheelWrap and wheelWrap:FindFirstChild("Pointer_SpinWheel")

	local btnLine    = spins:FindFirstChild("SpinButtonsLineFrame")
	local btnFrame   = btnLine and btnLine:FindFirstChild("MainSpinButtonFrame")
	local spinBtn    = btnFrame and btnFrame:FindFirstChild("SpinButton")
	local spinTxt    = spinBtn and spinBtn:FindFirstChild("SpinButtonText")

	if closeBtn and closeBtn:IsA("ImageButton") then
		CloseButton = closeBtn
		dprint("CloseButton wired (class:", CloseButton.ClassName, ")")
	else
		CloseButton = nil
	end

	SpinsFrame     = spins
	TimeLabel      = timeLbl and timeLbl:IsA("TextLabel") and (timeLbl :: any) or nil
	WheelInner     = wheelInner and wheelInner:IsA("ImageLabel") and (wheelInner :: any) or nil
	PointerImage   = pointer and pointer:IsA("ImageLabel") and (pointer :: any) or nil
	SpinButton     = spinBtn and spinBtn:IsA("TextButton") and (spinBtn :: any) or nil
	SpinButtonText = spinTxt and spinTxt:IsA("TextLabel") and (spinTxt :: any) or nil

	-- *** CoinsTextLabel exact path ***
	local coinsFrame = main:FindFirstChild("CoinsFrame")
	local coinLbl = coinsFrame and coinsFrame:FindFirstChild("CoinsTextLabel")
	if coinLbl and coinLbl:IsA("TextLabel") then
		CoinsTextLabel = coinLbl
		dprint("CoinsTextLabel wired (exact path):", CoinsTextLabel:GetFullName())
	else
		CoinsTextLabel = nil
		warn("[SpinController] CoinsTextLabel not found at MainGui → CoinsFrame → CoinsTextLabel")
	end

	dprint("Spins UI bound:",
		"SpinsFrame=", SpinsFrame and SpinsFrame:GetFullName() or "nil",
		"CloseButton=", CloseButton and CloseButton:GetFullName() or "nil",
		"TimeLabel=", TimeLabel and TimeLabel:GetFullName() or "nil",
		"WheelInner=", WheelInner and WheelInner:GetFullName() or "nil",
		"Pointer=", PointerImage and PointerImage:GetFullName() or "nil",
		"SpinButton=", SpinButton and SpinButton:GetFullName() or "nil",
		"SpinButtonText=", SpinButtonText and SpinButtonText:GetFullName() or "nil"
	)

	return true
end

-- ADD helper to read coins from either attribute or leaderstats
local function readCoinsValue(): number?
	-- Prefer attributes if your economy mirrors them
	local a = LOCAL:GetAttribute("Coins") or LOCAL:GetAttribute("CoinsBalance") or LOCAL:GetAttribute("Coin")
	if typeof(a) == "number" then return a end

	-- Fallback: leaderstats.Coins
	local ls = LOCAL:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Coins")
	if c and (c:IsA("IntValue") or c:IsA("NumberValue")) then
		return tonumber(c.Value)
	end
	return nil
end

-- Poll 10× per second so label never gets stuck, even if Values are recreated
local function startCoinsWatcher()
	if coinsPollConn then coinsPollConn:Disconnect() coinsPollConn = nil end
	coinsPollConn = RunService.Heartbeat:Connect(function()
		local v = readCoinsValue()
		if v ~= nil and v ~= lastCoinsValue then
			lastCoinsValue = v
			updateCoinsLabel(v) -- uses your existing formatter + label writer
		end
	end)
	dprint("Coins watcher started")
end

local function bindUi()
	if not findUi() then return end

	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			dprint("CloseButton clicked → hiding Spins frame")
			if SpinsFrame then SpinsFrame.Visible = false end
		end)
	end

	if SpinButton then
		SpinButton.MouseButton1Click:Connect(function()
			dprint("SpinButton clicked")
			callSpinAndAnimate()
		end)
	end

	refreshButtonLabel()
	updateTimerText()
	updateCoinsLabelFromSources()

	local coinsCtrl = Knit.GetController("CoinsController")
	if coinsCtrl and coinsCtrl.RefreshDisplay then
		coinsCtrl:RefreshDisplay()
	end

	startCoinsWatcher() -- <<< ADD THIS LINE

	startTimerLoop()
end

local function watchMainGui()
	if guiWatcherConn then guiWatcherConn:Disconnect() end
	local pg = LOCAL:FindFirstChild("PlayerGui") or LOCAL:WaitForChild("PlayerGui")
	guiWatcherConn = pg.ChildAdded:Connect(function(ch)
		if ch.Name == "MainGui" then
			dprint("MainGui detected/recreated → (re)binding Spins UI")
			task.defer(bindUi)
		end
	end)
end

-- ====== Knit lifecycle =======================================================
function Controller:KnitStart()
	dprint("KnitStart (client)")
	bindUi()
	watchMainGui()
	bindAttributeMirrors()
	requestStateFromServer()
end

return Controller