-- PlayerDataHandler.luau
local Players = game:GetService("Players")

local PlayerDataTemplate = require(script.Parent:WaitForChild("PlayerDataTemplate"))
local ProfileService = require(game.ServerScriptService.Server.Services.ProfileService)

local PlayerDataHandler = {}

print("[PlayerDataHandler] Module loaded")

local ProfileStore = ProfileService.GetProfileStore("PlayerData", PlayerDataTemplate)

local Profiles = {}
local JoinTimes = {}

function PlayerDataHandler:LoadProfile(player)
    print("[PlayerDataHandler] Loading profile for", player.Name)
    local key = "Player_v3_" .. tostring(player.UserId)
    local profile = ProfileStore:LoadProfileAsync(key)
    if profile then
        print("[PlayerDataHandler] Profile loaded for", player.Name)
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            Profiles[player] = nil
            JoinTimes[player] = nil
            if player and player.Parent then
                player:Kick("Data conflict: profile released elsewhere")
            end
        end)
        if player:IsDescendantOf(Players) then
            Profiles[player] = profile
            JoinTimes[player] = os.time()
            print("[PlayerDataHandler] Active profile data for", player.Name, profile.Data)
        else
            profile:Release()
        end
    else
        warn("[PlayerDataHandler] Failed to load profile for", player.Name)
        player:Kick("Failed to load your data. Please rejoin later.")
    end
end

function PlayerDataHandler:ReleaseProfile(player)
    print("[PlayerDataHandler] Releasing profile for", player.Name)
    local profile = Profiles[player]
    if profile then
        local joinStamp = JoinTimes[player]
        if joinStamp then
            local elapsed = os.time() - joinStamp
            profile.Data.Playtime = (profile.Data.Playtime or 0) + elapsed
            print("[PlayerDataHandler] Added playtime", elapsed, "seconds for", player.Name)
        end
        JoinTimes[player] = nil
        pcall(function() profile:Save() end)
        profile:Release()
        print("[PlayerDataHandler] Profile released for", player.Name)
        Profiles[player] = nil
    end
end

function PlayerDataHandler:GetProfile(player)
    return Profiles[player]
end

function PlayerDataHandler:GetData(player)
    local profile = Profiles[player]
    if profile then
        return profile.Data
    end
    return nil
end

function PlayerDataHandler:IncrementCoins(player, amount)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        profile.Data.Coins = (profile.Data.Coins or 0) + amount
        print("[PlayerDataHandler] IncrementCoins: Added", amount, "coins to", player.Name, "new total", profile.Data.Coins)
        if profile:IsActive() then
            pcall(function() profile:Save() end)
        end
    end
end

function PlayerDataHandler:SetLastCheckpoint(player, positionTable)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        profile.Data.LastCheckpoint = {positionTable[1], positionTable[2], positionTable[3]}
        print("[PlayerDataHandler] SetLastCheckpoint for", player.Name, "to", positionTable[1], positionTable[2], positionTable[3])
        if profile:IsActive() then
            pcall(function() profile:Save() end)
        end
    end
end

-- Checkpoint helpers
function PlayerDataHandler:HasVisitedCheckpoint(player, checkpointKey)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        profile.Data.VisitedCheckpoints = profile.Data.VisitedCheckpoints or {}
        return profile.Data.VisitedCheckpoints[checkpointKey] == true
    end
    return false
end

function PlayerDataHandler:MarkCheckpointVisited(player, checkpointKey)
    local profile = Profiles[player]
    if profile and profile:IsActive() then
        profile.Data.VisitedCheckpoints = profile.Data.VisitedCheckpoints or {}
        profile.Data.VisitedCheckpoints[checkpointKey] = true
        print("[PlayerDataHandler] MarkCheckpointVisited:", player.Name, checkpointKey)
        if profile:IsActive() then
            pcall(function() profile:Save() end)
        end
    end
end

-- Reset profile to template defaults (server-side).
-- Returns true on success, false + message on failure.
function PlayerDataHandler:ResetProfileToTemplate(player)
    local profile = Profiles[player]
    if not profile or not profile:IsActive() then
        return false, "Profile not active"
    end

    -- Apply template defaults
    profile.Data.Coins = PlayerDataTemplate.Coins or 0
    profile.Data.Playtime = PlayerDataTemplate.Playtime or 0
    profile.Data.LastCheckpoint = PlayerDataTemplate.LastCheckpoint -- probably nil
    profile.Data.VisitedCheckpoints = {}

    -- Save (guarded)
    local ok, err = pcall(function() profile:Save() end)
    if not ok then
        return false, ("Save failed: %s"):format(tostring(err))
    end

    -- Update attributes/leaderstats immediately
    pcall(function()
        if player and player.Parent then
            player:SetAttribute("Coins", profile.Data.Coins or 0)
            player:SetAttribute("CheckpointX", nil)
            player:SetAttribute("CheckpointY", nil)
            player:SetAttribute("CheckpointZ", nil)
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local coinsVal = leaderstats:FindFirstChild("Coins")
                if coinsVal then
                    coinsVal.Value = profile.Data.Coins or 0
                end
            end
        end
    end)

    print("[PlayerDataHandler] Profile reset to template for", player.Name)
    return true
end

return PlayerDataHandler
