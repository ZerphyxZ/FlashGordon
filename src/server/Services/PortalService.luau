-- PortalService.luau
-- Uses the correct PlaceIds and opens a confirmation UI before teleporting.
-- (No logic changes beyond confirming the real IDs.)

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

-- === REAL PLACE IDS (UPDATED) ===============================================
local WORLD_PLACE_IDS = {
    [1] = 95954065660891,   -- Place 1 → World 1
    [2] = 129835454913823,   -- Place 2 → World 2
    [3] = 76680813943017,  -- Place 3 → World 3
}

local NEXT_PORTAL_NAME = "NextWorld"
local PREV_PORTAL_NAME = "PrevWorld"
local TOUCH_DEBOUNCE   = 1.0
local UI_TIMEOUT       = 10.0
local UI_DEBOUNCE      = 1.5

local PortalService = Knit.CreateService {
    Name = "PortalService";
    Client = {};
}

print("[PortalService] Loaded successfully")

local touchMap : {[Player]: number} = {}
local uiMap    : {[Player]: number} = {}

local function getCurrentWorldIndex()
    for idx, pid in pairs(WORLD_PLACE_IDS) do
        if pid == game.PlaceId then return idx end
    end
    return 1
end

local function getDestination(direction: "Next" | "Prev")
    local cur = getCurrentWorldIndex()
    if direction == "Next" then
        return cur + 1, WORLD_PLACE_IDS[cur + 1]
    else
        return cur - 1, WORLD_PLACE_IDS[cur - 1]
    end
end

local function openPortalUI(player: Player, destIndex: number, destPlaceId: number, direction: string)
    if not player or not player.Parent then return end
    local now = tick()
    if uiMap[player] and now - uiMap[player] < UI_DEBOUNCE then
        print("[PortalService] Skipped UI reopen for", player.Name)
        return
    end
    uiMap[player] = now

    print(string.format(
        "[PortalService] Opening PortalUI for %s → World %d (PlaceId %s, %s)",
        player.Name, destIndex or -1, tostring(destPlaceId), direction or "?"
    ))

    player:SetAttribute("PortalUI", true)
    player:SetAttribute("PortalTargetIndex", destIndex)
    player:SetAttribute("PortalTargetPlaceId", destPlaceId)
    player:SetAttribute("PortalDirection", direction)

    task.delay(UI_TIMEOUT, function()
        if player and player.Parent and player:GetAttribute("PortalUI") == true then
            print("[PortalService] Auto-closing PortalUI for", player.Name)
            player:SetAttribute("PortalUI", false)
            player:SetAttribute("PortalTargetIndex", nil)
            player:SetAttribute("PortalTargetPlaceId", nil)
            player:SetAttribute("PortalDirection", nil)
        end
    end)
end

local function bindPortal(part: BasePart, direction: "Next" | "Prev")
    if not part or not part:IsA("BasePart") then return end
    print(string.format("[PortalService] Binding %s portal: %s", direction, part:GetFullName()))

    part.Touched:Connect(function(hit)
        local char = hit and hit.Parent
        local player = char and Players:GetPlayerFromCharacter(char)
        if not player then return end

        local now = tick()
        if touchMap[player] and (now - touchMap[player]) < TOUCH_DEBOUNCE then return end
        touchMap[player] = now

        local destIndex, destPid = getDestination(direction)
        if not destPid then
            warn("[PortalService] No destination for", direction, "from PlaceId", game.PlaceId)
            return
        end

        print(string.format("[PortalService] %s touched %s → world %d (PlaceId %s)",
            player.Name, direction, destIndex, tostring(destPid)))

        openPortalUI(player, destIndex, destPid, direction)
    end)
end

local function bindAllPortals()
    task.wait(1)
    for _, folder in ipairs(Workspace:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            if tostring(folder.Name):match("^World_%d%d%d$") then
                local portals = folder:FindFirstChild("Portals")
                if portals then
                    for _, d in ipairs(portals:GetDescendants()) do
                        if d:IsA("BasePart") then
                            if d.Name == NEXT_PORTAL_NAME then bindPortal(d, "Next") end
                            if d.Name == PREV_PORTAL_NAME then bindPortal(d, "Prev") end
                        end
                    end
                    print("[PortalService] Bound portals inside", folder.Name)
                end
            end
        end
    end
end

function PortalService:KnitStart()
    print("[PortalService] KnitStart - scanning for World_XXX folders …")
    bindAllPortals()

    TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
        local msg = ("Teleport failed: %s"):format(errorMessage or tostring(result))
        print("[PortalService] TeleportInitFailed →", player and player.Name, msg)
        if player and player.Parent then
            player:SetAttribute("PortalNotice", msg)
        end
    end)
end

-- === Client RPCs ===
function PortalService.Client:ConfirmTeleport(player: Player)
    local pid = player:GetAttribute("PortalTargetPlaceId")
    local idx = player:GetAttribute("PortalTargetIndex")
    print(string.format("[PortalService] ConfirmTeleport from %s → World %d (PlaceId %s)", player.Name, idx or -1, tostring(pid)))

    if not pid then
        player:SetAttribute("PortalNotice", "No destination configured.")
        return false
    end

    if RunService:IsStudio() then
        local msg = "Teleport is blocked in Roblox Studio. Publish the experience and test in Play (client)."
        print("[PortalService] Studio detected → not teleporting. Message sent to", player.Name)
        player:SetAttribute("PortalNotice", msg)
        player:SetAttribute("PortalUI", false)
        return false
    end

    player:SetAttribute("PortalUI", false)

    local ok, err = pcall(function()
        print(string.format("[PortalService] Teleporting %s to PlaceId %s …", player.Name, tostring(pid)))
        TeleportService:TeleportAsync(pid, { player })
    end)
    if not ok then
        local msg = "Teleport failed: "..tostring(err)
        warn("[PortalService] TeleportAsync failed:", err)
        player:SetAttribute("PortalNotice", msg)
        return false
    end

    print("[PortalService] TeleportAsync issued successfully for", player.Name)
    return true
end

function PortalService.Client:CancelTeleport(player: Player)
    print("[PortalService] CancelTeleport called by", player.Name)
    player:SetAttribute("PortalUI", false)
    player:SetAttribute("PortalTargetIndex", nil)
    player:SetAttribute("PortalTargetPlaceId", nil)
    player:SetAttribute("PortalDirection", nil)
    return true
end

return PortalService
