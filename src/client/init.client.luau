local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- Initialize client-side remotes (waits for server folder)
local Remotes = require(Shared.Remotes)
Remotes.Init()

local App = require(script:WaitForChild("ui"):WaitForChild("App"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(playerGui)
root:render(React.createElement(App))

script.Destroying:Connect(function()
	root:unmount()
end)
