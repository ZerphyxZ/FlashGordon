local Global = require(game.ReplicatedStorage.Shared.Modules.Global)
local Knit = Global.Knit

Knit.AddServices(script.Parent)
Knit.Start():andThen(function()
    print("Knit server started")
end):catch(function(err)
    warn(err)
end)