local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("data"):WaitForChild("ProfileService"))

local ADMIN_IDS = {
	[3401001] = true,
}

local PROFILE_TEMPLATE = {
	SchemaVersion = 5,
	Cash = 250,
	UnlockedImages = {},
	TotalPuzzlesCompleted = 0,
	TotalPlayTime = 0,
	TotalPiecesPlaced = 0,
	PuzzlesCompletedByDifficulty = {},
	PersonalBests = {},
	Achievements = {},
	PurchaseHistory = {},
	OwnedBoardSkins = {},
	OwnedConfettiStyles = {},
	OwnedSnapEffects = {},
	HintsRemaining = 0,
	CashBoostsRemaining = 0,
	EquippedBoardSkin = "",
	EquippedConfettiStyle = "",
	EquippedSnapEffect = "",
	SavedPuzzles = {},
	DailyPuzzle_LastCompletionDate = "",
	HasClaimedFavoriteReward = false,
}

local Players = game:GetService("Players")

local joinTimes: { [Player]: number } = {}

-- Ban system
-- Note: the original "BanStore" datastore was marked deleted by Roblox
-- (likely a GDPR/right-to-be-forgotten request), so any GetAsync on that
-- name now throws DatastoreDeleted. Using a new name to recreate the store.
local BanStore = DataStoreService:GetDataStore("PlayerBans_v2")
local bannedPlayersCache: { [number]: { reason: string, bannedAt: number, duration: number, bannedBy: string } } = {}

local function getBanRecord(userId: number): { reason: string, bannedAt: number, duration: number, bannedBy: string }?
	-- Check cache first
	if bannedPlayersCache[userId] then
		return bannedPlayersCache[userId]
	end

	-- Read from DataStore
	local ok, data = pcall(function()
		return BanStore:GetAsync(tostring(userId))
	end)

	if ok and data then
		bannedPlayersCache[userId] = data
		return data
	end

	return nil
end

local function isBanActive(record: { reason: string, bannedAt: number, duration: number, bannedBy: string }): boolean
	if record.duration == 0 then
		return true -- permanent
	end
	local expiresAt = record.bannedAt + (record.duration * 60)
	return os.time() < expiresAt
end

local function removeBan(userId: number)
	bannedPlayersCache[userId] = nil
	pcall(function()
		BanStore:RemoveAsync(tostring(userId))
	end)
end

local AdminHandler = {}

function AdminHandler.Init()
	-- Check bans on player join (before profile load)
	local function checkBanOnJoin(player: Player)
		local record = getBanRecord(player.UserId)
		if record then
			if isBanActive(record) then
				local msg = "You are banned: " .. record.reason
				if record.duration > 0 then
					local remaining = (record.bannedAt + record.duration * 60) - os.time()
					local hours = math.floor(remaining / 3600)
					local mins = math.floor((remaining % 3600) / 60)
					msg = msg .. string.format(" (%dh %dm remaining)", hours, mins)
				else
					msg = msg .. " (Permanent)"
				end
				player:Kick(msg)
				return
			else
				-- Ban expired, clean it up
				removeBan(player.UserId)
			end
		end
	end

	-- Track player join times
	local function onPlayerAdded(player: Player)
		checkBanOnJoin(player)
		joinTimes[player] = os.clock()
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		joinTimes[player] = nil
	end)

	-- Record existing players (in case handler initializes after some joins)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Admin: get session times
	local adminGetSessionTimes = Remotes.GetFunction("AdminGetSessionTimes")
	adminGetSessionTimes.OnServerInvoke = function(player)
		if not ADMIN_IDS[player.UserId] then
			warn("[AdminHandler] Unauthorized session times request from", player.Name, player.UserId)
			return { success = false, message = "Unauthorized" }
		end

		local now = os.clock()
		local entries = {}
		for p, joinTime in joinTimes do
			table.insert(entries, {
				name = p.DisplayName,
				userId = p.UserId,
				sessionSeconds = math.floor(now - joinTime),
			})
		end

		table.sort(entries, function(a, b)
			return a.sessionSeconds > b.sessionSeconds
		end)

		return { success = true, players = entries }
	end

	local adminResetData = Remotes.GetFunction("AdminResetData")

	adminResetData.OnServerInvoke = function(player)
		if not ADMIN_IDS[player.UserId] then
			warn("[AdminHandler] Unauthorized reset attempt from", player.Name, player.UserId)
			return { success = false, message = "Unauthorized" }
		end

		local profile = ProfileService.GetProfile(player)
		if not profile then
			return { success = false, message = "No profile loaded" }
		end

		-- Overwrite all data fields with fresh template values
		for key, value in PROFILE_TEMPLATE do
			if type(value) == "table" then
				profile.Data[key] = {}
			else
				profile.Data[key] = value
			end
		end

		print("[AdminHandler] Data reset for", player.Name, player.UserId)
		return { success = true }
	end

	-- Admin: ban player
	local adminBanPlayer = Remotes.GetFunction("AdminBanPlayer")
	adminBanPlayer.OnServerInvoke = function(player, targetUserId, reason, durationMinutes)
		if not ADMIN_IDS[player.UserId] then
			warn("[AdminHandler] Unauthorized ban attempt from", player.Name, player.UserId)
			return { success = false, message = "Unauthorized" }
		end

		if type(targetUserId) ~= "number" or type(reason) ~= "string" or type(durationMinutes) ~= "number" then
			return { success = false, message = "Invalid arguments" }
		end

		if durationMinutes < 0 then
			return { success = false, message = "Invalid duration" }
		end

		if targetUserId == player.UserId then
			return { success = false, message = "Cannot ban yourself" }
		end

		local record = {
			reason = reason,
			bannedAt = os.time(),
			duration = durationMinutes,
			bannedBy = player.Name,
		}

		-- Save to DataStore
		local ok, err = pcall(function()
			BanStore:SetAsync(tostring(targetUserId), record)
		end)

		if not ok then
			warn("[AdminHandler] Failed to save ban:", err)
			return { success = false, message = "DataStore error" }
		end

		-- Update cache
		bannedPlayersCache[targetUserId] = record

		-- Kick player if online
		local targetPlayer = Players:GetPlayerByUserId(targetUserId)
		if targetPlayer then
			local kickMsg = "You are banned: " .. reason
			if durationMinutes > 0 then
				local hours = math.floor(durationMinutes / 60)
				local mins = durationMinutes % 60
				kickMsg = kickMsg .. string.format(" (%dh %dm)", hours, mins)
			else
				kickMsg = kickMsg .. " (Permanent)"
			end
			targetPlayer:Kick(kickMsg)
		end

		print("[AdminHandler] Banned user", targetUserId, "by", player.Name, "reason:", reason, "duration:", durationMinutes, "min")
		return { success = true }
	end

	-- Admin: unban player
	local adminUnbanPlayer = Remotes.GetFunction("AdminUnbanPlayer")
	adminUnbanPlayer.OnServerInvoke = function(player, targetUserId)
		if not ADMIN_IDS[player.UserId] then
			warn("[AdminHandler] Unauthorized unban attempt from", player.Name, player.UserId)
			return { success = false, message = "Unauthorized" }
		end

		if type(targetUserId) ~= "number" then
			return { success = false, message = "Invalid arguments" }
		end

		removeBan(targetUserId)

		print("[AdminHandler] Unbanned user", targetUserId, "by", player.Name)
		return { success = true }
	end

	-- Admin: get ban list
	local adminGetBanList = Remotes.GetFunction("AdminGetBanList")
	adminGetBanList.OnServerInvoke = function(player)
		if not ADMIN_IDS[player.UserId] then
			warn("[AdminHandler] Unauthorized ban list request from", player.Name, player.UserId)
			return { success = false, message = "Unauthorized" }
		end

		local bans = {}
		for userId, record in bannedPlayersCache do
			if isBanActive(record) then
				table.insert(bans, {
					userId = userId,
					reason = record.reason,
					bannedAt = record.bannedAt,
					duration = record.duration,
					bannedBy = record.bannedBy,
				})
			else
				-- Clean up expired bans
				task.spawn(function()
					removeBan(userId)
				end)
			end
		end

		return { success = true, bans = bans }
	end
end

return AdminHandler
