local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Initialize remotes before anything else
Remotes.Init()

local ProfileService = require(script:WaitForChild("data"):WaitForChild("ProfileService"))
ProfileService.Start()

local TitleService = require(script:WaitForChild("services"):WaitForChild("TitleService"))
TitleService.Init(ProfileService)

local PuzzleHandler = require(script:WaitForChild("handlers"):WaitForChild("PuzzleHandler"))
PuzzleHandler.Init()

local RoomManager = require(script:WaitForChild("handlers"):WaitForChild("RoomManager"))
RoomManager.Init()

-- Discover manually-placed tables from Workspace.CafeTables
local Workspace = game:GetService("Workspace")
local cafeFolder = Workspace:WaitForChild("CafeTables")
local tableModels: { [string]: Model } = {}
for _, child in cafeFolder:GetChildren() do
	if child:IsA("Model") and child:FindFirstChild("TableType") then
		tableModels[child.Name] = child
	end
end

local TableManager = require(script:WaitForChild("cafe"):WaitForChild("TableManager"))
TableManager.Init(tableModels, RoomManager)

-- Initialize MonetizationHandler if available
pcall(function()
	local MonetizationHandler = require(script:WaitForChild("handlers"):WaitForChild("MonetizationHandler"))
	MonetizationHandler.Init()
end)
