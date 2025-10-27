--[[
    KnitClientInit_O.client

    This script initializes the Knit framework on the client.  It
    loads any client controllers found in the `Controllers` folder
    inside this script's parent, then calls `Knit.Start()` to begin
    running them.  Catching the promise ensures that any errors
    during startup are reported via `warn`.

    Place this script in `StarterPlayer → StarterPlayerScripts → Client`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require Knit from ReplicatedStorage.Packages.  Knit is shared
-- between the server and client via ReplicatedStorage.
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

-- Debug: indicate that client initialization script is executing
print("[KnitClientInit] Initializing client controllers and services")

-- Load controllers from the parent folder.  Knit will look for any
-- ModuleScripts inside `script.Parent` (which is the `Client` folder)
-- that have been defined using `Knit.CreateController`.  This
-- simplifies loading controllers and mirrors the structure used in
-- your working game code.
Knit.AddControllers(script.Parent)

-- Start Knit on the client.  Use a promise catch to handle
-- initialization errors gracefully.
Knit.Start():andThen(function()
    print("[KnitClientInit] Knit started successfully!")
end):catch(function(err)
    warn("[KnitClientInit] Knit client startup error:", err)
end)