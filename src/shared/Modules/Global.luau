local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PackagesFolder = ReplicatedStorage:WaitForChild("Packages")
local SharedFolder = ReplicatedStorage:WaitForChild("Shared")
local SharedModules = SharedFolder:WaitForChild("Modules")
local Knit = require(PackagesFolder:WaitForChild("Knit"))

return {
    Players = Players,
    ReplicatedStorage = ReplicatedStorage,
    Workspace = Workspace,
    Knit = Knit,
    TweenService = TweenService,
    ContextActionService = ContextActionService,
    RunService = RunService,
    UserInputService = UserInputService,
}
