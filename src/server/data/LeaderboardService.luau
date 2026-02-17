local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)

local LeaderboardService = {}

local datastoreCache: { [string]: OrderedDataStore } = {}

local function getDataStore(difficultyId: string): OrderedDataStore?
	if not datastoreCache[difficultyId] then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore("Leaderboard_" .. difficultyId)
		end)
		if not ok then
			return nil
		end
		datastoreCache[difficultyId] = store
	end
	return datastoreCache[difficultyId]
end

-- Submit a time (only saves if better than existing)
-- Times stored as milliseconds (integer), ascending sort = fastest first
function LeaderboardService.submitTime(userId: number, difficultyId: string, timeSeconds: number)
	local store = getDataStore(difficultyId)
	if not store then return end
	local timeMs = math.floor(timeSeconds * 1000)
	local key = tostring(userId)

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(oldValue)
			-- Only save if no existing time or new time is better (lower)
			if oldValue == nil or timeMs < oldValue then
				return timeMs
			end
			return nil -- Don't update
		end)
	end)

	if not ok then
		warn("[LeaderboardService] Failed to submit time:", err)
	end
end

-- Get top N times for a difficulty
function LeaderboardService.getTopTimes(difficultyId: string, count: number): { { userId: number, displayName: string, time: number } }
	local store = getDataStore(difficultyId)
	local results = {}
	if not store then return results end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, count) -- ascending = true (fastest first)
	end)

	if not ok or not pages then
		warn("[LeaderboardService] Failed to get leaderboard:", pages)
		return results
	end

	local entries = pages:GetCurrentPage()
	for _, entry in entries do
		local userId = tonumber(entry.key) or 0
		local timeMs = entry.value
		local timeSeconds = timeMs / 1000

		-- Try to get display name
		local displayName = "Player"
		pcall(function()
			displayName = Players:GetNameFromUserIdAsync(userId)
		end)

		-- Try to get equipped badge from profile (online players only)
		local badge = ""
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local profileData = ProfileService.GetData(player)
			if profileData then
				badge = profileData.EquippedBadge or ""
			end
		end

		table.insert(results, {
			userId = userId,
			displayName = displayName,
			time = timeSeconds,
			badge = badge,
		})
	end

	return results
end

return LeaderboardService
