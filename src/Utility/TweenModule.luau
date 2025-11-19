local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackagesFolder: Folder = ReplicatedStorage:WaitForChild("Packages")
local TroveModule = require(PackagesFolder:WaitForChild("trove"))
local Constants = require(ReplicatedStorage.EnumsAndContants.Constants)
-- local SoundModule = require(ReplicatedStorage.Utility.SoundModule)

local Tweener = {}
Tweener.__index = Tweener

-- Utility function to create a tween with common parameters
local function CreateTween(
	target: Instance,
	duration: number,
	properties: { [string]: any },
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
): Tween
	local tweenInfo =
		TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Linear, easingDirection or Enum.EasingDirection.Out)
	return TweenService:Create(target, tweenInfo, properties)
end

-- TweenProperty: Tweens one or more properties of an object
function Tweener.DOTween(
	target: Instance,
	duration: number,
	properties: { [string]: any },
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
): Tween
	local tween = CreateTween(target, duration, properties, easingStyle, easingDirection)
	tween:Play()
	return tween
end

-- Handle Button Hover with improved efficiency
function Tweener.HandleButtonHover(button: TextButton | ImageButton, hoverSoundName: string?, clickSoundName: string?)
	local duration = 0.15
	local scaleAmount = 1.1
	local hoverSoundName = hoverSoundName or Constants.Sounds.BUTTON_HOVER_SOUND
	local clickSoundName = clickSoundName or Constants.Sounds.BUTTON_CLick_SOUND

	local size = button.Size
	local hoverSize = UDim2.new(
		size.X.Scale * scaleAmount,
		size.X.Offset * scaleAmount,
		size.Y.Scale * scaleAmount,
		size.Y.Offset * scaleAmount
	)

	-- Create tweens using CreateTween
	local hoverTween = CreateTween(button, duration, { Size = hoverSize })
	local returnTween = CreateTween(button, duration, { Size = size })

	local trove = TroveModule.new()

	-- Connect events using single function for efficiency
	local function onButtonEvent(_hover: string)
		if hoverSoundName then
			--SoundModule.PlayTouchSound(hoverSoundName)
		end
		if _hover == "Enter" then
			hoverTween:Play()
		elseif _hover == "Exit" then
			returnTween:Play()
		end
	end
	trove:Add(button)
	trove:Connect(button.MouseEnter, function()
		onButtonEvent("Enter")
	end)
	trove:Connect(button.MouseLeave, function()
		onButtonEvent("Exit")
	end)

	return trove
end

-- Toggle UI
function Tweener.ToggleShop(frame: GuiObject, duration: number, desiredPos: number)
	local goalProperties = { Position = frame.Position }
	local tween = CreateTween(frame, duration, goalProperties)
	tween:Play()
	return tween
end

-- Fading Methods
function Tweener.FadeIn(frame: GuiObject, duration: number)
	local tween = CreateTween(frame, duration, { BackgroundTransparency = 0 })
	tween:Play()
	return tween
end

function Tweener.FadeOut(frame: GuiObject, duration: number)
	local tween = CreateTween(frame, duration, { BackgroundTransparency = 1 })
	tween:Play()
	return tween
end

function Tweener.TextFadeIn(textObj: TextLabel | TextButton | TextBox, duration: number)
	local tween = CreateTween(textObj, duration, { TextTransparency = 0 })
	tween:Play()
	return tween
end

function Tweener.ImageTransparency(textObj: ImageLabel | TextButton | TextBox, duration: number, Transparency: number)
	local tween = CreateTween(textObj, duration, { ImageTransparency = Transparency })
	tween:Play()
	return tween
end

function Tweener.TextFadeOut(textObj: TextLabel | TextButton | TextBox, duration: number)
	local tween = CreateTween(textObj, duration, { TextTransparency = 1 })
	tween:Play()
	return tween
end

-- Movement Methods
function Tweener.Move(frame: GuiObject, duration: number, targetPosition: UDim2)
	local tween = CreateTween(frame, duration, { Position = targetPosition }, Enum.EasingStyle.Sine)
	tween:Play()
	return tween
end

function Tweener.MoveBounce(frame: GuiObject, duration: number, targetPosition: UDim2)
	local tween =
		CreateTween(frame, duration, { Position = targetPosition }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	tween:Play()
	return tween
end

-- Sizing Methods
function Tweener.Grow(frame: GuiObject, duration: number, multiplier: number)
	local targetSize = UDim2.new(frame.Size.X.Scale * multiplier, 0, frame.Size.Y.Scale * multiplier, 0)
	local tween = CreateTween(frame, duration, { Size = targetSize })
	tween:Play()
	return tween
end

function Tweener.GrowBounce(frame: GuiObject, duration: number, multiplier: number)
	local targetSize
	if frame:IsA("UIScale") then
		targetSize = multiplier
	else
		targetSize = UDim2.new(frame.Size.X.Scale * multiplier, 0, frame.Size.Y.Scale * multiplier, 0)
	end

	local tween =
		CreateTween(frame, duration, { Scale = targetSize }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	tween:Play()
	return tween
end

-- Rotation Methods
function Tweener.Rotate(
	frame: GuiObject,
	duration: number,
	targetRotation: number,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?
)
	local tween = CreateTween(
		frame,
		duration,
		{ Rotation = targetRotation },
		EasingStyle or Enum.EasingStyle.Sine,
		EasingDirection or Enum.EasingDirection.Out
	)
	tween:Play()
	return tween
end

function Tweener.RotateBounce(frame: GuiObject, duration: number, targetRotation: number)
	local tween =
		CreateTween(frame, duration, { Rotation = targetRotation }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	tween:Play()
	return tween
end

-- Advanced Rotation Methods
function Tweener.Teeter(frame: GuiObject, duration: number, rotationAmount: number)
	local function PerformTeeter()
		Tweener.Rotate(frame, duration, -rotationAmount)
		task.wait(duration)
		Tweener.Rotate(frame, duration, rotationAmount)
	end

	task.spawn(PerformTeeter)
end

function Tweener.Spin(frame: GuiObject, duration: number)
	Tweener.Rotate(frame, duration, 360)
end

-- Optional: Add event handling for tween completion
function Tweener.OnTweenCompleted(tween: Tween, callback: () -> ()): RBXScriptConnection
	return tween.Completed:Connect(callback)
end

return Tweener
