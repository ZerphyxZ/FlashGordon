-- DeathService.luau
-- Knit service used to replicate a player's death state to all clients by setting
-- an attribute.  Clients listen for this attribute to show the death effect.
local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages:WaitForChild("Knit"))

local DeathService = Knit.CreateService {
    Name = "DeathService";
    Client = {};
}

-- Client‑callable: mark this player as dead.  Returns true for acknowledgement.
function DeathService.Client:NotifyDeath(player)
    if not (player and player:IsA("Player")) then
        return false
    end
    -- Attribute replication from the server ensures all clients see the change.
    player:SetAttribute("IsDead", true)
    return true
end

-- Called by server services (RespawnService, ResetProgressService) to clear the death flag.
function DeathService:SetAlive(player)
    if not (player and player:IsA("Player")) then return end
    player:SetAttribute("IsDead", false)
end

return DeathService