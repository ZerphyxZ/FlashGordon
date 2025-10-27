--[[
    PlayerDataServer.luau

    A Knit service responsible for managing player data using the
    PlayerDataHandler module and handling checkpoint logic.  This
    service loads and releases profiles on player join/leave, creates
    a `leaderstats` folder with a `Coins` IntValue for each player to
    replicate the coin amount to the client, exposes methods to clients
    for retrieving their data, and ensures players spawn at their last
    checkpoint when rejoining.

    It also connects to checkpoint parts in the workspace.  When a
    player's character touches a checkpoint part (a BasePart named
    "checkpoint" in the `workspace.Checkpoints` folder), the
    service awards the player 5 coins and saves the checkpoint
    position.  Checkpoints are only rewarded once per session to
    prevent exploiting the reward system.

    Place this script in `ServerScriptService -> Server -> Services`.
]]

local Players = game:GetService("Players")

local Knit = require(game:GetService("ReplicatedStorage").Packages:WaitForChild("Knit"))
-- Load the PlayerDataHandler module from the shared modules folder
local PlayerDataHandler = require(game.ReplicatedStorage.Shared.Modules.PlayerDataHandler)

local PlayerDataServer = Knit.CreateService {
    Name = "PlayerDataServer";
    Client = {};
}

-- Emit a debug message when the service module is first required.
print("[PlayerDataServer] Service module loaded")

-- When the service starts, set up player listeners and load existing profiles
function PlayerDataServer:KnitStart()
    -- Debug: indicate that the service is starting up
    print("[PlayerDataServer] KnitStart called, initializing service and loading existing players")
    -- Load profiles for players already in server before Knit started
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:PlayerAdded(player)
        end)
    end

    -- Set up listeners for players joining/leaving
    Players.PlayerAdded:Connect(function(player)
        -- Debug: player joined
        print("[PlayerDataServer] PlayerAdded event for", player.Name)
        self:PlayerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        -- Debug: player leaving
        print("[PlayerDataServer] PlayerRemoving event for", player.Name)
        self:PlayerRemoving(player)
    end)
end

-- This service no longer manages checkpoint touches; see CheckpointService
function PlayerDataServer:ConnectCheckpoint() end

-- Called when a player joins.  Loads their data and sets up spawn behavior
function PlayerDataServer:PlayerAdded(player)
    -- Debug: notify that we're loading data for this player
    print("[PlayerDataServer] Loading data for", player.Name)
    -- Load or create the player's profile
    PlayerDataHandler:LoadProfile(player)

    -- After loading, retrieve the player's data and set replicated attributes
    local data = PlayerDataHandler:GetData(player)
    if data then
        -- Create leaderstats folder and Coins IntValue for leaderboard replication
        local leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
        local coinsVal = Instance.new("IntValue")
        coinsVal.Name = "Coins"
        coinsVal.Value = data.Coins or 0
        coinsVal.Parent = leaderstats

        -- Store coin balance in a replicated attribute
        player:SetAttribute("Coins", data.Coins or 0)
        -- Store last checkpoint coordinates in replicated attributes if present
        if data.LastCheckpoint then
            local cx, cy, cz = data.LastCheckpoint[1], data.LastCheckpoint[2], data.LastCheckpoint[3]
            player:SetAttribute("CheckpointX", cx)
            player:SetAttribute("CheckpointY", cy)
            player:SetAttribute("CheckpointZ", cz)
            -- If the character has already spawned by the time the profile is
            -- loaded, teleport it immediately to the saved checkpoint.  This
            -- ensures that players who join quickly after the server starts
            -- are placed at their last checkpoint even if CharacterAdded
            -- fired before this script connected the event.
            local char = player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = CFrame.new(cx, cy, cz)
                end
            end
        end
    end

    -- Listen for character spawns to teleport to last checkpoint
    player.CharacterAdded:Connect(function(character)
        print("[PlayerDataServer] CharacterAdded for", player.Name)
        -- Attempt to teleport the player to their saved checkpoint using attributes
        local cx = player:GetAttribute("CheckpointX")
        local cy = player:GetAttribute("CheckpointY")
        local cz = player:GetAttribute("CheckpointZ")
        if cx and cy and cz then
            print("[PlayerDataServer] Teleporting", player.Name, "to last checkpoint at", cx, cy, cz)
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            if hrp then
                hrp.CFrame = CFrame.new(cx, cy, cz)
            end
        else
            print("[PlayerDataServer] No checkpoint attributes found for", player.Name)
        end
    end)
end

-- Called when a player leaves.  Releases their profile and cleans up
function PlayerDataServer:PlayerRemoving(player)
    -- Debug: releasing player's data
    print("[PlayerDataServer] Releasing data for", player.Name)
    -- Save playtime and release the profile
    PlayerDataHandler:ReleaseProfile(player)
end

-- Client‑accessible method to get a copy of the player's data.  Do not
-- expose the actual Profile object to the client.
function PlayerDataServer.Client:GetPlayerData(player)
    -- Debug: client is requesting their data
    print("[PlayerDataServer] Client.GetPlayerData called by", player.Name)
    local data = PlayerDataHandler:GetData(player)
    if data then
        -- Return a shallow copy to avoid exposing internal references
        return {
            Coins = data.Coins,
            Playtime = data.Playtime,
            LastCheckpoint = data.LastCheckpoint and {data.LastCheckpoint[1], data.LastCheckpoint[2], data.LastCheckpoint[3]} or nil,
        }
    end
    return nil
end

return PlayerDataServer