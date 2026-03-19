local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.MonetizationConfig)
local TitleConfig = require(Shared.TitleConfig)

local ProfileService = require(script.Parent.ProfileService)

local LeaderboardService = {}

local datastoreCache: { [string]: OrderedDataStore } = {}

-- Caches for faster leaderboard loading
local leaderboardCache: { [string]: { data: any, timestamp: number } } = {}
local CACHE_TTL = 30 -- seconds

local nameCache: { [number]: string } = {}

local function getDisplayName(userId: number): string
	if nameCache[userId] then return nameCache[userId] end
	local name = "Player"
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = name
	return name
end

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
	else
		-- Invalidate cache so new personal bests show up promptly
		leaderboardCache[difficultyId] = nil
	end
end

-- Get top N times for a difficulty
function LeaderboardService.getTopTimes(difficultyId: string, count: number): { { userId: number, displayName: string, time: number } }
	-- Check cache first
	local cached = leaderboardCache[difficultyId]
	if cached and (os.clock() - cached.timestamp) < CACHE_TTL then
		return cached.data
	end

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

		local displayName = getDisplayName(userId)

		-- Try to get title and VIP status from profile (online players only)
		local title = ""
		local isVIP = false
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local profileData = ProfileService.GetData(player)
			if profileData then
				title = TitleConfig.getTitleFromCompletions(profileData.PuzzlesCompletedByDifficulty or {})
			end
			local vipOk, vipOwns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(userId, MonetizationConfig.GAME_PASSES.VIP.id)
			end)
			if vipOk and vipOwns then
				isVIP = true
			end
		end

		table.insert(results, {
			userId = userId,
			displayName = displayName,
			time = timeSeconds,
			title = title,
			isVIP = isVIP,
		})
	end

	-- Cache the results
	leaderboardCache[difficultyId] = { data = results, timestamp = os.clock() }

	return results
end

return LeaderboardService
