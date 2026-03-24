local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local DailyPuzzleConfig = require(Shared.DailyPuzzleConfig)
local ProgressionConfig = require(Shared.ProgressionConfig)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

local DailyPuzzleHandler = {}

-- Server-side start times for daily puzzle timing
local dailyStartTimes: { [number]: number } = {}

local datastoreCache: { [string]: OrderedDataStore } = {}

local function getDailyStore(dateString: string): OrderedDataStore?
	local key = "DailyPuzzle_" .. dateString
	if not datastoreCache[key] then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(key)
		end)
		if not ok then
			return nil
		end
		datastoreCache[key] = store
	end
	return datastoreCache[key]
end

local function getLeaderboard(dateString: string, count: number): { any }
	local store = getDailyStore(dateString)
	local results = {}
	if not store then return results end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, count) -- ascending = fastest first
	end)

	if not ok or not pages then return results end

	local entries = pages:GetCurrentPage()
	for _, entry in entries do
		local userId = tonumber(entry.key) or 0
		local timeMs = entry.value
		local timeSeconds = timeMs / 1000

		local displayName = "Player"
		pcall(function()
			displayName = Players:GetNameFromUserIdAsync(userId)
		end)

		table.insert(results, {
			userId = userId,
			displayName = displayName,
			time = timeSeconds,
		})
	end

	return results
end

function DailyPuzzleHandler.Init()
	local getDailyPuzzle = Remotes.GetFunction("GetDailyPuzzle")
	local getDailyLeaderboard = Remotes.GetFunction("GetDailyPuzzleLeaderboard")
	local dailyCompleted = Remotes.GetEvent("DailyPuzzleCompleted")

	-- Listen for PuzzleStarted to record daily puzzle start times
	local puzzleStarted = Remotes.GetEvent("PuzzleStarted")
	puzzleStarted.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		local puzzle = DailyPuzzleConfig.getTodaysPuzzle()
		if not puzzle then return end
		if data.imageId == puzzle.imageId and data.difficultyId == puzzle.difficultyId then
			dailyStartTimes[player.UserId] = os.clock()
		end
	end)

	-- Clean up on player leave
	Players.PlayerRemoving:Connect(function(player)
		dailyStartTimes[player.UserId] = nil
	end)

	getDailyPuzzle.OnServerInvoke = function(player)
		local puzzle = DailyPuzzleConfig.getTodaysPuzzle()
		if not puzzle then
			return { puzzle = nil, completed = false, leaderboard = {} }
		end

		local data = ProfileService.GetData(player)
		local completed = false
		if data then
			completed = data.DailyPuzzle_LastCompletionDate == puzzle.dateString
		end

		local leaderboard = getLeaderboard(puzzle.dateString, 20)

		return {
			puzzle = puzzle,
			completed = completed,
			leaderboard = leaderboard,
		}
	end

	getDailyLeaderboard.OnServerInvoke = function(_player, dateString)
		if type(dateString) ~= "string" or #dateString ~= 10 then
			dateString = DailyPuzzleConfig.getTodaysDateString()
		end
		return getLeaderboard(dateString, 20)
	end

	dailyCompleted.OnServerEvent:Connect(function(player, completionData)
		if type(completionData) ~= "table" then return end

		local puzzle = DailyPuzzleConfig.getTodaysPuzzle()
		if not puzzle then return end

		-- Validate that submission matches today's puzzle
		if completionData.imageId ~= puzzle.imageId then return end
		if completionData.difficultyId ~= puzzle.difficultyId then return end

		-- Use server-side timing instead of client-provided completionTime
		local startTime = dailyStartTimes[player.UserId]
		if not startTime then return end
		local completionTime = os.clock() - startTime
		dailyStartTimes[player.UserId] = nil

		if completionTime <= 0 then return end

		-- Anti-cheat: minimum completion time
		local minTime = ProgressionConfig.MIN_COMPLETION_TIMES[puzzle.difficultyId]
		if minTime and completionTime < minTime then return end

		local data = ProfileService.GetData(player)
		if not data then return end

		-- Grant bonus cash on first completion today
		if data.DailyPuzzle_LastCompletionDate ~= puzzle.dateString then
			data.Cash = (data.Cash or 0) + DailyPuzzleConfig.BONUS_CASH
			data.DailyPuzzle_LastCompletionDate = puzzle.dateString

			-- Notify client of bonus cash
			local xpAwarded = Remotes.GetEvent("XPAwarded")
			xpAwarded:FireClient(player, {
				cashGained = DailyPuzzleConfig.BONUS_CASH,
			})
		end

		-- Submit time to daily leaderboard
		local store = getDailyStore(puzzle.dateString)
		if store then
			local timeMs = math.floor(completionTime * 1000)
			local key = tostring(player.UserId)
			task.spawn(function()
				pcall(function()
					store:UpdateAsync(key, function(oldValue)
						if oldValue == nil or timeMs < oldValue then
							return timeMs
						end
						return nil
					end)
				end)
			end)
		end
	end)
end

return DailyPuzzleHandler
