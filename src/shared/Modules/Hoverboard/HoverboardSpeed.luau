--// HoverboardHUD.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HoverboardSpeed = {}
local player = Players.LocalPlayer
local mainGUI = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local speedGUI = mainGUI:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
local bars = speedGUI:WaitForChild("Bars")
local speedBars = {}
local connection

local MAX_BARS = 10
local MAX_BAR_HEIGHT = 0.6
local MAX_BAR_WIDTH = 0.08
local BASE_TWEEN_DURATION = 1
local SMOOTHING_FACTOR = 0.18     -- how smooth the bar grows
local TWEEN_EASING = Enum.EasingStyle.Quad
local TWEEN_DIR = Enum.EasingDirection.Out

-- Animation config
local TWEEN_INFO = TweenInfo.new(
	BASE_TWEEN_DURATION,                         -- smoothness
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local function GetTweenInfo(speed)
	--local duration = BASE_TWEEN_DURATION + (1 - math.clamp(speed / 100, 0, 1)) * SMOOTHING_FACTOR
	local duration = BASE_TWEEN_DURATION * SMOOTHING_FACTOR
	-- Higher speed = faster fill animation
	return TweenInfo.new(duration, TWEEN_EASING, TWEEN_DIR)
end

---------------------------------------------------------------------
-- Initialize GUI References
---------------------------------------------------------------------
local function LoadGUI()
	local pg = player:WaitForChild("PlayerGui")
	mainGUI = pg:WaitForChild("MainGui")
	speedGUI = mainGUI:WaitForChild("SpeedGUI")
	speedLabel = speedGUI:WaitForChild("SpeedVal")
	bars = speedGUI:WaitForChild("Bars")
	speedBars = {}
	for i = 1, MAX_BARS do
		local bar = bars:WaitForChild("Bar"..i)
		table.insert(speedBars, bar)
		bar.Visible = true
		bar.Size = UDim2.new(0,0,MAX_BAR_HEIGHT,0)
	end
end

---------------------------------------------------------------------
-- Animate frame to target scale
---------------------------------------------------------------------
local function AnimateFrame(frame, scale, visible, speed)
	local tweenInfo = GetTweenInfo(speed)
	
	TweenService:Create(frame, tweenInfo, {
		Size = UDim2.new(scale, 0, MAX_BAR_HEIGHT, 0)
	}):Play()
	frame.Visible = visible
end

function HoverboardSpeed.UpdateSpeed(getSpeedFunc, getMaxSpeedFunc)
	if connection then connection:Disconnect() end
	LoadGUI()
	connection = RunService.Heartbeat:Connect(function()
		local speed = getSpeedFunc()
		local rawMax = getMaxSpeedFunc()
		if not rawMax or rawMax <= 0 then return end
		
		-- Round up to nearest multiple of 10
		local maxSpeed = math.ceil(rawMax / 10) * 10
		
		speedLabel.Text = string.format("Speed: %.0f", speed or 0)
		local segment = maxSpeed / 12  -- threshold per frame
		for i = 1, MAX_BARS do
			local threshold = segment * i

			if speed >= threshold then
				AnimateFrame(speedBars[i], MAX_BAR_WIDTH, true, speed)	-- expand to full size
			else
				AnimateFrame(speedBars[i], 0, false, speed)	-- collapse smoothly
			end
		end
	end)
end

function HoverboardSpeed.RefreshSpeedGUI()
	LoadGUI()
end

function HoverboardSpeed.Cleanup(speedGui)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if speedGui then
		speedGui:Destroy()
		speedGui = nil
	end
end

return HoverboardSpeed