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

local TableStatusService = require(script:WaitForChild("services"):WaitForChild("TableStatusService"))
TableStatusService.Init(tableModels)

local TableManager = require(script:WaitForChild("cafe"):WaitForChild("TableManager"))
TableManager.Init(tableModels, RoomManager)
TableManager.SetTableStatusService(TableStatusService)

-- Register callback so RoomManager notifies TableManager on state changes
RoomManager.SetStateChangeCallback(function(roomId, newState, playerCount)
	local tableId = TableManager.GetTableIdForRoom(roomId)
	if tableId then
		TableManager.OnRoomStateChanged(tableId, newState, playerCount)
	end
end)

-- Initialize MonetizationHandler if available
pcall(function()
	local MonetizationHandler = require(script:WaitForChild("handlers"):WaitForChild("MonetizationHandler"))
	MonetizationHandler.Init()
end)

-- Initialize DailyRewardsHandler
pcall(function()
	local DailyRewardsHandler = require(script:WaitForChild("handlers"):WaitForChild("DailyRewardsHandler"))
	DailyRewardsHandler.Init()
end)

-- Initialize DailyPuzzleHandler
pcall(function()
	local DailyPuzzleHandler = require(script:WaitForChild("handlers"):WaitForChild("DailyPuzzleHandler"))
	DailyPuzzleHandler.Init()
end)

-- Initialize SpinWheelHandler
pcall(function()
	local SpinWheelHandler = require(script:WaitForChild("handlers"):WaitForChild("SpinWheelHandler"))
	SpinWheelHandler.Init()
end)

-- Initialize FavoriteRewardHandler
pcall(function()
	local FavoriteRewardHandler = require(script:WaitForChild("handlers"):WaitForChild("FavoriteRewardHandler"))
	FavoriteRewardHandler.Init()
end)

-- Initialize AdminHandler
pcall(function()
	local AdminHandler = require(script:WaitForChild("handlers"):WaitForChild("AdminHandler"))
	AdminHandler.Init()
end)
