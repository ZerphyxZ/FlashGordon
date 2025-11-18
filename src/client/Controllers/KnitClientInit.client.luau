local Global =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Global"))
local Knit = Global.Knit
Knit.AddControllers(script.Parent)
Knit.Start():andThen(function()
	print("Knit started on client")
end)
