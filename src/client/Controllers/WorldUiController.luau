-- WorldUiController.luau
-- Displays "Central City Ruins - World 1" in TopBarFrame.WorldNameText.
-- Works regardless of where the world folder is loaded (no ActiveWorld assumption).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "WorldUiControllerPrevious" }

local LOCAL_PLAYER = Players.LocalPlayer

-- Optional fallback names
local FALLBACK_NAMES = {
    [1] = "Central City Ruins",
    [2] = "Vortex Corridor",
    [3] = "Surface of Mongo",
}

-- Cached connections
local worldNameLabel: TextLabel? = nil
local playerGuiConn: RBXScriptConnection? = nil
local attrConnA: RBXScriptConnection? = nil
local attrConnB: RBXScriptConnection? = nil

local function getWorldLabel(): TextLabel?
    local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("MainGui")
    if not main then return nil end
    local top = main:FindFirstChild("TopBarFrame")
    if not top then return nil end
    local label = top:FindFirstChild("WorldNameText")
    if label and label:IsA("TextLabel") then return label end
    return nil
end

local function formatDisplay(idx: number?, name: string?)
    local i = tonumber(idx) or 0
    local n = (type(name) == "string" and name ~= "" and name) or FALLBACK_NAMES[i] or "Unknown World"
    if i > 0 then
        return string.format("%s - World %d", n, i)
    else
        return n
    end
end

local function applyLabel()
    worldNameLabel = getWorldLabel()
    if not worldNameLabel then return end
    local idx  = LOCAL_PLAYER:GetAttribute("WorldIndex")
    local name = LOCAL_PLAYER:GetAttribute("WorldName")
    worldNameLabel.Text = formatDisplay(idx, name)
end

local function bindAttributeListeners()
    if attrConnA then attrConnA:Disconnect() end
    if attrConnB then attrConnB:Disconnect() end

    attrConnA = LOCAL_PLAYER:GetAttributeChangedSignal("WorldIndex"):Connect(applyLabel)
    attrConnB = LOCAL_PLAYER:GetAttributeChangedSignal("WorldName"):Connect(applyLabel)
end

local function watchGuiRecreation()
    local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
    local function attach(guiRoot)
        guiRoot.ChildAdded:Connect(function(ch)
            if ch.Name == "MainGui" then
                task.delay(0.05, applyLabel)
            end
        end)
    end
    if pg then
        attach(pg)
    else
        task.spawn(function()
            local g = LOCAL_PLAYER:WaitForChild("PlayerGui")
            attach(g)
        end)
    end
end

function Controller:KnitStart()
    bindAttributeListeners()
    watchGuiRecreation()

    -- Mirror global attributes if player attributes not yet set
    if LOCAL_PLAYER:GetAttribute("WorldIndex") == nil then
        local idx = ReplicatedStorage:GetAttribute("WorldIndex")
        local name = ReplicatedStorage:GetAttribute("WorldName")
        if idx ~= nil then LOCAL_PLAYER:SetAttribute("WorldIndex", idx) end
        if name ~= nil then LOCAL_PLAYER:SetAttribute("WorldName", name) end
    end

    task.delay(0.05, applyLabel)
end

return Controller
