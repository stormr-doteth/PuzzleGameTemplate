local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Initialize remotes before anything else
Remotes.Init()

local ProfileService = require(script:WaitForChild("data"):WaitForChild("ProfileService"))
ProfileService.Start()

local PuzzleHandler = require(script:WaitForChild("handlers"):WaitForChild("PuzzleHandler"))
PuzzleHandler.Init()

local RoomManager = require(script:WaitForChild("handlers"):WaitForChild("RoomManager"))
RoomManager.Init()

-- Build cafe environment and initialize table manager
local CafeBuilder = require(script:WaitForChild("cafe"):WaitForChild("CafeBuilder"))
local tableModels = CafeBuilder.Build()

local TableManager = require(script:WaitForChild("cafe"):WaitForChild("TableManager"))
TableManager.Init(tableModels, RoomManager)

-- Initialize MonetizationHandler if available
pcall(function()
	local MonetizationHandler = require(script:WaitForChild("handlers"):WaitForChild("MonetizationHandler"))
	MonetizationHandler.Init()
end)
