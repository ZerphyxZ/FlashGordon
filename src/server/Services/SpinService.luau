-- ServerScriptService/Server/Services/SpinService.luau
-- Knit server service handling the daily spin wheel logic.
-- Accrues spins over time, processes spin requests, randomly selects prizes
-- based on SpinPrizeConfig, and awards coins or UGC prizes.  After awarding,
-- it updates player attributes so the client UI can refresh.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local PlayerDataHandler = require(ReplicatedStorage.Shared.Modules.PlayerDataHandler)
local SpinPrizeConfig   = require(ReplicatedStorage.Shared.Modules.SpinPrizeConfig)

local SpinService = Knit.CreateService {
    Name   = "SpinService";
    Client = {};
}

-- Configuration
local MAX_SPINS        = 8
local GRANT_EVERY_SEC  = 15 -- adjust to 8*60*60 (8 hours) in production
local ANIM_SECONDS     = 5.0
local DEFAULT_FREE_SPINS_ON_JOIN = 2

local function dprint(...)
    print("[SpinService]", ...)
end

-- Helper to mirror spin counts and next accrual time into player attributes
local function refreshAccrual(profile, player)
    if not (profile and profile:IsActive()) then
        return 0, 0
    end
    local data = profile.Data
    data.Spin = data.Spin or { Available = DEFAULT_FREE_SPINS_ON_JOIN, LastUnix = os.time() }
    if data.Spin.Available == nil then data.Spin.Available = DEFAULT_FREE_SPINS_ON_JOIN end
    if data.Spin.LastUnix  == nil then data.Spin.LastUnix  = os.time() end

    local now       = os.time()
    local available = tonumber(data.Spin.Available) or 0
    local lastUnix  = tonumber(data.Spin.LastUnix)  or now

    if available < MAX_SPINS and now > lastUnix then
        local gained = math.floor((now - lastUnix) / GRANT_EVERY_SEC)
        if gained > 0 then
            local grant = math.min(gained, MAX_SPINS - available)
            available += grant
            lastUnix  += grant * GRANT_EVERY_SEC
            data.Spin.Available = available
            data.Spin.LastUnix  = lastUnix
            dprint(("Accrued %d spins (now=%d)"):format(grant, available))
        end
    end

    local nextUnix
    if available >= MAX_SPINS then
        nextUnix = 0
    else
        nextUnix = lastUnix + GRANT_EVERY_SEC
    end

    if player and player.Parent == Players then
        player:SetAttribute("SpinsAvailable", available)
        player:SetAttribute("SpinNextUnix", nextUnix)
    end
    return available, nextUnix
end

local function saveProfileAsync(profile)
    if profile and profile:IsActive() then
        local ok, err = pcall(function() profile:Save() end)
        if not ok then
            warn("[SpinService] Profile save failed:", err)
        end
    end
end

function SpinService:_ensureProfileReady(player)
    task.spawn(function()
        for _ = 1, 60 do
            local profile = PlayerDataHandler:GetProfile(player)
            if profile and profile:IsActive() then
                refreshAccrual(profile, player)
                saveProfileAsync(profile)
                return
            end
            task.wait(0.2)
        end
        dprint("Profile not active after wait for", player.Name)
    end)
end

-- Build a list of prize entries from SpinPrizeConfig
local function buildPrizeList()
    local list = {}
    for key, entry in pairs(SpinPrizeConfig) do
        if type(entry) == "table" and entry.location then
            local prob = tonumber(entry.probability) or 0
            table.insert(list, {
                key  = key,
                info = {
                    prize    = entry.prize or "Coins",
                    amount   = entry.amount or 0,
                    reward   = entry.reward,
                    location = entry.location,
                    probability = prob,
                },
                prob = math.max(0, prob)
            })
        end
    end
    return list
end

local function choosePrizeEntry()
    local list = buildPrizeList()
    if #list == 0 then
        -- Default: small coin wedge
        local fallback = {
            prize      = "Coins",
            amount     = 50,
            location   = NumberRange.new(-257, -205),
            probability = 1,
        }
        return "Fallback", fallback
    end
    local total = 0
    for _, entry in ipairs(list) do total += entry.prob end
    if total <= 0 then
        local pick = list[math.random(#list)]
        return pick.key, pick.info
    end
    local r = math.random() * total
    local running = 0
    for _, entry in ipairs(list) do
        running += entry.prob
        if r <= running then
            return entry.key, entry.info
        end
    end
    return list[#list].key, list[#list].info
end

local function randomDelta(range)
    local min = math.floor(range.Min)
    local max = math.floor(range.Max)
    if max < min then min, max = max, min end
    return math.random(min, max)
end

-- Client API
function SpinService.Client:GetState(player)
    dprint("GetState from", player.Name)
    local profile = PlayerDataHandler:GetProfile(player)
    if not (profile and profile:IsActive()) then
        return { ok = true, spins = 0, nextUnix = 0 }
    end
    local spins, nextUnix = refreshAccrual(profile, player)
    return { ok = true, spins = spins, nextUnix = nextUnix }
end

function SpinService.Client:Spin(player)
    dprint("Spin request from", player.Name)
    local profile = PlayerDataHandler:GetProfile(player)
    if not (profile and profile:IsActive()) then
        return { ok = false, reason = "NoProfile" }
    end
    local spins, nextUnix = refreshAccrual(profile, player)
    if spins <= 0 then
        return { ok = false, reason = "NoSpins", spins = spins, nextUnix = nextUnix }
    end
    local data = profile.Data
    local before = spins
    data.Spin.Available = spins - 1
    spins = data.Spin.Available
    dprint(("Deducted 1 spin → remaining=%d"):format(spins))
    local now = os.time()
    if before >= MAX_SPINS then
        data.Spin.LastUnix = now
    end
    if spins <= 0 then
        data.Spin.LastUnix = now
        nextUnix = now + GRANT_EVERY_SEC
    else
        local _, computedNext = refreshAccrual(profile, player)
        nextUnix = computedNext
    end
    local prizeKey, prizeInfo = choosePrizeEntry()
    local deltaDeg = randomDelta(prizeInfo.location)
    player:SetAttribute("SpinsAvailable", spins)
    player:SetAttribute("SpinNextUnix", nextUnix)
    saveProfileAsync(profile)
    if prizeInfo.prize == "Coins" then
        local amount = tonumber(prizeInfo.amount) or 0
        task.delay(ANIM_SECONDS + 0.15, function()
            local p2 = PlayerDataHandler:GetProfile(player)
            if p2 and p2:IsActive() then
                dprint(("Awarding %d coins to %s"):format(amount, player.Name))
                local ok, err = pcall(function()
                    PlayerDataHandler:IncrementCoins(player, amount)
                end)
                if not ok then
                    warn("[SpinService] IncrementCoins failed:", err)
                else
                    -- Update player's coin attributes so the client UI refreshes
                    local data2 = p2.Data
                    player:SetAttribute("Coins", data2.Coins or 0)
                    player:SetAttribute("CoinsBalance", data2.Coins or 0)
                    saveProfileAsync(p2)
                end
            end
        end)
    elseif prizeInfo.prize == "UGC" and type(prizeInfo.reward) == "function" then
        task.delay(ANIM_SECONDS + 0.15, function()
            dprint(("Granting UGC prize %s to %s"):format(prizeKey, player.Name))
            pcall(prizeInfo.reward, player)
        end)
    end
    return {
        ok        = true,
        deltaDeg  = deltaDeg,
        spins     = spins,
        nextUnix  = nextUnix,
        prizeKey  = prizeKey,
    }
end

function SpinService:GrantFreeSpins(player, count)
    count = math.max(0, math.floor(count or 0))
    if count <= 0 then return end
    local profile = PlayerDataHandler:GetProfile(player)
    if not (profile and profile:IsActive()) then
        return
    end
    local data = profile.Data
    data.Spin = data.Spin or { Available = DEFAULT_FREE_SPINS_ON_JOIN, LastUnix = os.time() }
    local before = data.Spin.Available or 0
    local grant  = math.min(count, MAX_SPINS - before)
    if grant <= 0 then return end
    data.Spin.Available = before + grant
    refreshAccrual(profile, player)
    saveProfileAsync(profile)
end

function SpinService:KnitStart()
    dprint("KnitStart")
    Players.PlayerAdded:Connect(function(player)
        self:_ensureProfileReady(player)
    end)
end

return SpinService