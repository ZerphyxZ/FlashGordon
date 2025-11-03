-- ServerScriptService/Server/Services/PlayerDataServer.luau
-- Reads/writes per-world progress; mirrors current world to legacy fields,
-- and sets player attributes from the current world’s saved checkpoint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local PlayerDataServer = Knit.CreateService {
    Name = "PlayerDataServer";
    Client = {};
}

print("[PlayerDataServer] Service module loaded")

-- === helpers ================================================================

local function getCurrentWorldIndex(player: Player): number
    local idx = player:GetAttribute("WorldIndex")
    if typeof(idx) ~= "number" then
        idx = ReplicatedStorage:GetAttribute("WorldIndex")
    end
    if typeof(idx) ~= "number" then idx = 1 end
    if idx < 1 then idx = 1 end
    return idx
end

local function applyCheckpointAttributesFromWorld(player: Player)
    local data = PlayerDataHandler:GetData(player)
    if not data then return end

    -- Ensure containers + mirror legacy view to *current* world
    PlayerDataHandler:SyncFlatToWorldSnapshot(player)

    local w = getCurrentWorldIndex(player)
    data.LastCheckpointByWorld = data.LastCheckpointByWorld or {}
    local cp = data.LastCheckpointByWorld[w]

    if cp and type(cp) == "table" and cp[1] then
        player:SetAttribute("CheckpointX", cp[1])
        player:SetAttribute("CheckpointY", cp[2])
        player:SetAttribute("CheckpointZ", cp[3])
    else
        player:SetAttribute("CheckpointX", nil)
        player:SetAttribute("CheckpointY", nil)
        player:SetAttribute("CheckpointZ", nil)
    end
end

-- Only mirror the *current* world into the flat (legacy) snapshot so
-- existing systems see the correct per-place view. Do NOT migrate flats
-- back into a different world's slot on join (prevents cross-place bleed).
local function mirrorCurrentWorldToLegacy(player: Player)
    local data = PlayerDataHandler:GetData(player)
    if not data then return end
    PlayerDataHandler:SyncFlatToWorldSnapshot(player)
end

-- Teleport helper (used on CharacterAdded to spawn at last checkpoint for world)
local function teleportToLastCheckpointIfAny(player: Player, character: Model)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    applyCheckpointAttributesFromWorld(player)

    local x = player:GetAttribute("CheckpointX")
    local y = player:GetAttribute("CheckpointY")
    local z = player:GetAttribute("CheckpointZ")
    if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
        hrp.CFrame = CFrame.new(x, y, z)
        print(string.format("[PlayerDataServer] Teleported %s to World %d checkpoint at (%.2f, %.2f, %.2f)",
            player.Name, getCurrentWorldIndex(player), x, y, z))
    else
        print(string.format("[PlayerDataServer] No saved checkpoint for %s in World %d",
            player.Name, getCurrentWorldIndex(player)))
    end
end

-- === Knit lifecycle =========================================================

function PlayerDataServer:KnitStart()
    print("[PlayerDataServer] KnitStart called, initializing service and loading existing players")
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:PlayerAdded(player)
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        print("[PlayerDataServer] PlayerAdded event for", player.Name)
        self:PlayerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        print("[PlayerDataServer] PlayerRemoving event for", player.Name)
        self:PlayerRemoving(player)
    end)
end

function PlayerDataServer:ConnectCheckpoint() end -- (legacy no-op)

function PlayerDataServer:PlayerAdded(player: Player)
    print("[PlayerDataServer] Loading data for", player.Name)
    PlayerDataHandler:LoadProfile(player)

    local data = PlayerDataHandler:GetData(player)
    if data then
        -- leaderstats + coins attribute (unchanged)
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player

        local coinsVal = Instance.new("IntValue")
        coinsVal.Name = "Coins"
        coinsVal.Value = data.Coins or 0
        coinsVal.Parent = leaderstats

        player:SetAttribute("Coins", data.Coins or 0)

        -- Mirror ONLY current world into legacy fields & set checkpoint attrs
        mirrorCurrentWorldToLegacy(player)
        applyCheckpointAttributesFromWorld(player)

        -- If character already exists, place it now
        local char = player.Character
        if char then
            teleportToLastCheckpointIfAny(player, char)
        end
    end

    -- React to character spawns using per-world data only
    player.CharacterAdded:Connect(function(character)
        print("[PlayerDataServer] CharacterAdded for", player.Name)
        -- Keep legacy view mirrored to the *current* world only
        mirrorCurrentWorldToLegacy(player)
        teleportToLastCheckpointIfAny(player, character)
    end)

    -- If the current WorldIndex changes (rare on server; mostly on new place),
    -- keep legacy view mirrored so other systems see the right set.
    player:GetAttributeChangedSignal("WorldIndex"):Connect(function()
        print("[PlayerDataServer] WorldIndex changed for", player.Name, "→", tostring(player:GetAttribute("WorldIndex")))
        mirrorCurrentWorldToLegacy(player)
        applyCheckpointAttributesFromWorld(player)
    end)
end

function PlayerDataServer:PlayerRemoving(player: Player)
    print("[PlayerDataServer] Releasing data for", player.Name)
    PlayerDataHandler:ReleaseProfile(player)
end

function PlayerDataServer.Client:GetPlayerData(player: Player)
    print("[PlayerDataServer] Client.GetPlayerData called by", player.Name)
    local data = PlayerDataHandler:GetData(player)
    if data then
        return {
            Coins = data.Coins,
            Playtime = data.Playtime,
            LastCheckpoint = data.LastCheckpoint and { data.LastCheckpoint[1], data.LastCheckpoint[2], data.LastCheckpoint[3] } or nil,
        }
    end
    return nil
end

return PlayerDataServer
