local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- Initialize client-side remotes (waits for server folder)
local Remotes = require(Shared.Remotes)
Remotes.Init()

local SeatingService = require(script:WaitForChild("services"):WaitForChild("SeatingService"))
SeatingService.Init()

local MusicService = require(script:WaitForChild("services"):WaitForChild("MusicService"))
MusicService.Init()


local App = require(script:WaitForChild("ui"):WaitForChild("App"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Use a Folder as React root so React doesn't destroy other PlayerGui children
-- (e.g. TouchGui, Freecam). ScreenGuis are portaled into playerGui from App.
local reactRoot = Instance.new("Folder")
reactRoot.Name = "ReactRoot"
reactRoot.Parent = playerGui

local root = ReactRoblox.createRoot(reactRoot)
root:render(React.createElement(App, { playerGui = playerGui }))

script.Destroying:Connect(function()
	root:unmount()
end)
