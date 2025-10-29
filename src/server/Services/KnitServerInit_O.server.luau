-- KnitServerInit_O.server
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

-- Debug: indicate that server initialization script is executing
print("[KnitServerInit] Initializing server services")

-- Require core services. Keep ProgressBarService required BEFORE CheckpointService
print("[KnitServerInit] Requiring PlayerDataServer")
require(script.Parent:WaitForChild("PlayerDataServer"))

print("[KnitServerInit] Requiring CurrencyService")
require(script.Parent:WaitForChild("CurrencyService"))

print("[KnitServerInit] Requiring ProgressBarService")
require(script.Parent:WaitForChild("ProgressBarService"))

print("[KnitServerInit] Requiring DeathService")
require(script.Parent:WaitForChild("WorldRouterService"))

print("[KnitServerInit] Requiring CheckpointService")
require(script.Parent:WaitForChild("CheckpointService"))

print("[KnitServerInit] Requiring DeathService")
require(script.Parent:WaitForChild("DeathService"))

print("[KnitServerInit] Requiring DeathService")
require(script.Parent:WaitForChild("ObstacleSyncService"))

print("[KnitServerInit] Requiring DeathService")
require(script.Parent:WaitForChild("PortalService"))

-- Optional/other services you use — ensure these exist in the folder
if script.Parent:FindFirstChild("ResetProgressService") then
    print("[KnitServerInit] Requiring ResetProgressService")
    require(script.Parent:WaitForChild("ResetProgressService"))
end

if script.Parent:FindFirstChild("RespawnService") then
    print("[KnitServerInit] Requiring RespawnService")
    require(script.Parent:WaitForChild("RespawnService"))
end

-- Start Knit on the server. Use a promise catch to handle startup errors.
print("[KnitServerInit] Starting Knit on server")
Knit.Start():catch(function(err)
    warn("[KnitServerInit] Knit server startup error: " .. tostring(err))
end)
print("[KnitServerInit] Knit server started successfully")
