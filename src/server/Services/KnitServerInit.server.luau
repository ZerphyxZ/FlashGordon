local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))

-- -- Debug: indicate that server initialization script is executing
-- print("[KnitServerInit] Initializing server services")

-- -- === Load order matters ===
-- -- 1) WorldRouterService must run FIRST so WorldIndex/WorldName are published
-- --    before any service (especially PlayerDataServer) reads them.
-- print("[KnitServerInit] Requiring WorldRouterService")
-- require(script.Parent:WaitForChild("WorldRouterService"))

-- -- 2) Core data/profile services
-- print("[KnitServerInit] Requiring PlayerDataServer")
-- require(script.Parent:WaitForChild("PlayerDataServer"))

-- print("[KnitServerInit] Requiring CurrencyService")
-- require(script.Parent:WaitForChild("CurrencyService"))

-- -- 3) Gameplay services that read per-world data
-- print("[KnitServerInit] Requiring ProgressBarService")
-- require(script.Parent:WaitForChild("ProgressBarService"))

-- print("[KnitServerInit] Requiring CheckpointService")
-- require(script.Parent:WaitForChild("CheckpointService"))

-- print("[KnitServerInit] Requiring DeathService")
-- require(script.Parent:WaitForChild("DeathService"))

-- print("[KnitServerInit] Requiring ObstacleSyncService")
-- require(script.Parent:WaitForChild("ObstacleSyncService"))

-- print("[KnitServerInit] Requiring PortalService")
-- require(script.Parent:WaitForChild("PortalService"))

-- print("[KnitServerInit] Requiring ResetGameDataService")
-- require(script.Parent:WaitForChild("ResetGameDataService"))

-- print("[KnitServerInit] Requiring DailySpinService.luau")
-- require(script.Parent:WaitForChild("SpinService"))

-- -- Optional/other services you use — ensure these exist in the folder
-- if script.Parent:FindFirstChild("ResetProgressService") then
-- 	print("[KnitServerInit] Requiring ResetProgressService")
-- 	require(script.Parent:WaitForChild("ResetProgressService"))
-- end

-- if script.Parent:FindFirstChild("RespawnService") then
-- 	print("[KnitServerInit] Requiring RespawnService")
-- 	require(script.Parent:WaitForChild("RespawnService"))
-- end

-- -- If you have a LoadingScreenService in Services, it is safe to start it early.
-- if script.Parent:FindFirstChild("LoadingScreenService") then
-- 	print("[KnitServerInit] Requiring LoadingScreenService")
-- 	require(script.Parent:WaitForChild("LoadingScreenService"))
-- end

Knit.AddServices(script.Parent)
-- Start Knit on the server. Use a promise catch to handle startup errors.
print("[KnitServerInit] Starting Knit on server")
Knit.Start():catch(function(err)
	warn("[KnitServerInit] Knit server startup error: " .. tostring(err))
end)
print("[KnitServerInit] Knit server started successfully")
