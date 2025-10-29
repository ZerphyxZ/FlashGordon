-- LoadingScreenController.luau
-- Shows MainGui.LoadingScreenFrame while server readies the player.
-- Skip button unlocks after 5s in the *current place*.
-- "Loading" text animates with increasing dots every 0.2s.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit              = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local Controller = Knit.CreateController { Name = "LoadingScreenController" }
local LocalPlayer = Players.LocalPlayer

-- UI refs (rebound when MainGui is recreated)
local LoadingFrame: Frame?
local SkipButton: TextButton?
local LoadingText: TextLabel?

-- state
local _animRunning = false
local _skipEnabled = false
local _bindConn -- reconnect on MainGui recreation
local _btnConn

-- ---- UI binding ------------------------------------------------------------

local function tryBind(): boolean
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local main = pg:FindFirstChild("MainGui")
    if not main then return false end

    local lf = main:FindFirstChild("LoadingScreenFrame")
    if not (lf and lf:IsA("Frame")) then return false end

    LoadingFrame = lf
    LoadingText  = lf:FindFirstChild("LoadingText")  :: TextLabel
    SkipButton   = lf:FindFirstChild("SkipLSButtonFrame")
                    and (lf:FindFirstChild("SkipLSButtonFrame") :: Instance):FindFirstChild("SkipButton") :: TextButton

    -- Default hidden (server will open via attribute)
    LoadingFrame.Visible = false

    -- Wire skip
    if _btnConn then _btnConn:Disconnect() end
    if SkipButton then
        _btnConn = SkipButton.MouseButton1Click:Connect(function()
            if _skipEnabled and LoadingFrame then
                LoadingFrame.Visible = false
                LocalPlayer:SetAttribute("LoadingUISkipped", true)
            end
        end)
    end

    return true
end

local function bindOnMainGui()
    if _bindConn then _bindConn:Disconnect() end
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    _bindConn = pg.ChildAdded:Connect(function(ch)
        if ch.Name == "MainGui" then
            task.delay(0.05, function()
                tryBind()
                -- re-apply current attribute state after rebind
                local show = LocalPlayer:GetAttribute("LoadingUI") == true
                if LoadingFrame then
                    LoadingFrame.Visible = show
                end
                if show then
                    -- restart animation and 5s timer
                    task.spawn(function()
                        _animRunning = false
                        task.wait() -- yield once to ensure UI exists
                        Controller:_startAnimation()
                        Controller:_armSkipTimer()
                    end)
                end
            end)
        end
    end)
end

-- ---- animation & skip timer ------------------------------------------------

function Controller:_startAnimation()
    if not LoadingText then return end
    if _animRunning then return end
    _animRunning = true

    task.spawn(function()
        local dots = 0
        while _animRunning and LoadingFrame and LoadingFrame.Visible do
            dots = (dots + 1) % 4 -- 0..3
            local suffix = string.rep(".", dots)
            LoadingText.Text = "Loading" .. suffix
            task.wait(0.2)
        end
    end)
end

function Controller:_stopAnimation()
    _animRunning = false
end

function Controller:_armSkipTimer()
    _skipEnabled = false
    if SkipButton then
        SkipButton.AutoButtonColor = false
        SkipButton.Active = false
        SkipButton.TextTransparency = 0.4
    end
    task.delay(5.0, function()
        _skipEnabled = true
        if SkipButton then
            SkipButton.Active = true
            SkipButton.AutoButtonColor = true
            SkipButton.TextTransparency = 0
        end
    end)
end

-- ---- attribute reactions ---------------------------------------------------

local function onLoadingAttrChanged()
    local show = LocalPlayer:GetAttribute("LoadingUI") == true
    if not LoadingFrame then
        if not tryBind() then return end
    end
    if show then
        LoadingFrame.Visible = true
        Controller:_startAnimation()
        Controller:_armSkipTimer()
    else
        Controller:_stopAnimation()
        if LoadingFrame then
            LoadingFrame.Visible = false
        end
    end
end

-- ---- Knit lifecycle --------------------------------------------------------

function Controller:KnitStart()
    -- initial bind (handles MainGui recreation too)
    tryBind()
    bindOnMainGui()

    -- listen for server gate
    LocalPlayer:GetAttributeChangedSignal("LoadingUI"):Connect(onLoadingAttrChanged)

    -- apply current state if server already set it
    onLoadingAttrChanged()
end

return Controller
