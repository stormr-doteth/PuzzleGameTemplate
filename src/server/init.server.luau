local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Initialize remotes before anything else
Remotes.Init()

local ProfileService = require(script:WaitForChild("data"):WaitForChild("ProfileService"))
ProfileService.Start()
print("ProfileService started")

local PuzzleHandler = require(script:WaitForChild("handlers"):WaitForChild("PuzzleHandler"))
PuzzleHandler.Init()
print("PuzzleHandler started")

local RoomManager = require(script:WaitForChild("handlers"):WaitForChild("RoomManager"))
RoomManager.Init()
print("RoomManager started")

-- Build cafe environment and initialize table manager
local CafeBuilder = require(script:WaitForChild("cafe"):WaitForChild("CafeBuilder"))
local tableModels = CafeBuilder.Build()
print("CafeBuilder built")

local TableManager = require(script:WaitForChild("cafe"):WaitForChild("TableManager"))
TableManager.Init(tableModels, RoomManager)
print("TableManager started")

-- Initialize MonetizationHandler if available
pcall(function()
	local MonetizationHandler = require(script:WaitForChild("handlers"):WaitForChild("MonetizationHandler"))
	MonetizationHandler.Init()
	print("MonetizationHandler started")
end)
