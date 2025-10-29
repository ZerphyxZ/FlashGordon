-- LoadingScreenService.luau
-- Shows a loading-gate on join and closes it only after server + player data are ready.
-- Also teleports the character to the saved checkpoint BEFORE the gate opens to avoid the visual snap.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local LoadingScreenService = Knit.CreateService {
    Name = "LoadingScreenService";
    Client = {};
}

-- ---- helpers ---------------------------------------------------------------

local function findActiveWorldFolder(): Instance?
    for _, ch in ipairs(Workspace:GetChildren()) do
        if (ch:IsA("Folder") or ch:IsA("Model")) and tostring(ch.Name):match("^World_%d+") then
            return ch
        end
    end
    return nil
end

local function findSpawnInWorld(): BasePart?
    local world = findActiveWorldFolder()
    if world then
        local s = world:FindFirstChild("StartSpawn") or world:FindFirstChild("SpawnLocation")
        if s and s:IsA("BasePart") then return s end
    end
    -- legacy fallbacks
    local s2 = Workspace:FindFirstChild("StartSpawn") or Workspace:FindFirstChild("SpawnLocation")
    if s2 and s2:IsA("BasePart") then return s2 end
    return nil
end

local function placeCharacterAt(player: Player, cf: CFrame)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- zero motion to avoid drift
    pcall(function()
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    hrp.CFrame = cf
end

local function placeCharacterToCheckpointOrSpawn(player: Player)
    -- Try checkpoint from attributes (set by PlayerDataServer / Profile load)
    local cx = player:GetAttribute("CheckpointX")
    local cy = player:GetAttribute("CheckpointY")
    local cz = player:GetAttribute("CheckpointZ")
    if typeof(cx) == "number" and typeof(cy) == "number" and typeof(cz) == "number" then
        placeCharacterAt(player, CFrame.new(cx, cy, cz))
        return true
    end

    -- Fallback to world spawn
    local spawnPart = findSpawnInWorld()
    if spawnPart then
        placeCharacterAt(player, spawnPart.CFrame + Vector3.new(0, 3, 0))
        return true
    end
    return false
end

local function waitForCharacter(player: Player, timeout: number?): boolean
    timeout = timeout or 8
    local t0 = os.clock()
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", math.max(0.1, timeout - (os.clock() - t0)))
    return hrp ~= nil
end

local function waitForProfile(player: Player, timeout: number?): boolean
    timeout = timeout or 8
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if PlayerDataHandler:GetData(player) then return true end
        task.wait(0.1)
    end
    return false
end

local function waitForWorld(timeout: number?): boolean
    timeout = timeout or 8
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if findActiveWorldFolder() then return true end
        task.wait(0.1)
    end
    return false
end

local function preparePlayerAndCloseGate(player: Player)
    -- Open the gate instantly for new joins
    player:SetAttribute("LoadingUI", true)
    player:SetAttribute("LoadingUISkipped", false)

    -- Wait for world + data + character
    waitForWorld(8)
    waitForProfile(player, 8)
    waitForCharacter(player, 8)

    -- Ensure immediate placement before revealing the world
    pcall(function()
        placeCharacterToCheckpointOrSpawn(player)
    end)

    -- Small settle to avoid popping while physics wakes
    task.wait(0.05)

    -- Signal client to close
    player:SetAttribute("LoadingUI", false)
end

-- ---- lifecycle -------------------------------------------------------------

function LoadingScreenService:KnitStart()
    -- Existing players (rare on hot-reload servers)
    for _, plr in ipairs(Players:GetPlayers()) do
        task.spawn(preparePlayerAndCloseGate, plr)
    end

    Players.PlayerAdded:Connect(function(plr)
        task.spawn(preparePlayerAndCloseGate, plr)
    end)

    Players.PlayerRemoving:Connect(function(plr)
        -- cleanup attrs (not strictly required)
        pcall(function()
            plr:SetAttribute("LoadingUI", false)
            plr:SetAttribute("LoadingUISkipped", nil)
        end)
    end)
end

return LoadingScreenService
