local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

return{
	ReplicatedStorage = ReplicatedStorage,
	Players = Players,
	TweenService = TweenService,
	UserInputService = UserInputService,
	RunService = RunService,
	Knit = require(ReplicatedStorage.Packages.Knit),
	Workspace = Workspace
}

