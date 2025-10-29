-- WorldRouterService.luau
-- Loads exactly one world (World_###) directly into Workspace based on the *actual* PlaceId.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

local WorldRouterService = Knit.CreateService {
    Name = "WorldRouterService";
    Client = {};
}

-- === CONFIG: PlaceId ↔ World Info (UPDATE: real PlaceIds) ====================
local WORLD_REGISTRY = {
    [84612540807662]   = { Index = 1, Name = "Central City Ruins" }, -- Place 1
    [78474746786969]   = { Index = 2, Name = "Vortex Corridor"    }, -- Place 2
    [114974911901623]  = { Index = 3, Name = "Surface of Mongo"   }, -- Place 3
}

local DEFAULT_WORLD = { Index = 1, Name = "Central City Ruins" }

-- === INTERNAL HELPERS ========================================================

local function getWorldInfoForPlace(placeId: number)
    return WORLD_REGISTRY[placeId] or DEFAULT_WORLD
end

local function publishGlobal(info)
    ReplicatedStorage:SetAttribute("WorldIndex", info.Index)
    ReplicatedStorage:SetAttribute("WorldName",  info.Name)
    ReplicatedStorage:SetAttribute("PlaceId",    game.PlaceId)
end

local function publishToPlayer(player: Player, info)
    player:SetAttribute("WorldIndex", info.Index)
    player:SetAttribute("WorldName",  info.Name)
end

local function getWorldPackagesFolder(): Instance?
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if not shared then return nil end
    return shared:FindFirstChild("WorldPackages")
end

local function findWorldSource(worldIndex: number): Instance?
    local wp = getWorldPackagesFolder()
    if not wp then return nil end
    local name = string.format("World_%03d", worldIndex)
    local src = wp:FindFirstChild(name)
    if src then return src end
    -- graceful fallback names
    return wp:FindFirstChild("World_" .. tostring(worldIndex))
        or wp:FindFirstChild("World" .. tostring(worldIndex))
end

local function clearOldWorlds()
    for _, child in ipairs(Workspace:GetChildren()) do
        if (child:IsA("Folder") or child:IsA("Model")) and tostring(child.Name):match("^World_%d+") then
            child:Destroy()
        end
    end
end

local function activateWorld(worldIndex: number)
    clearOldWorlds()
    local src = findWorldSource(worldIndex)
    if not src then
        warn(("[WorldRouterService] Could not find World_%03d in ReplicatedStorage.Shared.WorldPackages"):format(worldIndex))
        return false
    end
    local clone = src:Clone()
    clone.Parent = Workspace
    print(("[WorldRouterService] Loaded '%s' directly into Workspace (World %d)"):format(clone.Name, worldIndex))
    return true
end

-- === CLIENT API ==============================================================

function WorldRouterService.Client:GetWorldInfo(player)
    return {
        Index   = player:GetAttribute("WorldIndex"),
        Name    = player:GetAttribute("WorldName"),
        PlaceId = game.PlaceId,
    }
end

-- === LIFECYCLE ===============================================================

function WorldRouterService:KnitStart()
    print("[WorldRouterService] KnitStart")

    local info = getWorldInfoForPlace(game.PlaceId)
    self.WorldInfo = info

    publishGlobal(info)
    activateWorld(info.Index)

    for _, plr in ipairs(Players:GetPlayers()) do
        publishToPlayer(plr, info)
    end
    Players.PlayerAdded:Connect(function(plr)
        publishToPlayer(plr, info)
    end)
end

return WorldRouterService
