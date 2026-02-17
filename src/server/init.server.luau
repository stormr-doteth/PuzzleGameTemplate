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

-- Initialize MonetizationHandler if available
pcall(function()
	local MonetizationHandler = require(script:WaitForChild("handlers"):WaitForChild("MonetizationHandler"))
	MonetizationHandler.Init()
	print("MonetizationHandler started")
end)
