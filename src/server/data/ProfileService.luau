local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ServerScriptService:WaitForChild("Packages")
local ProfileStore = require(Packages.ProfileStore)

local CURRENT_SCHEMA_VERSION = 6

local PROFILE_TEMPLATE = {
	SchemaVersion = CURRENT_SCHEMA_VERSION,
	Cash = 250,
	UnlockedImages = {},         -- { [string]: true }
	TotalPuzzlesCompleted = 0,
	TotalPlayTime = 0,
	TotalPiecesPlaced = 0,
	PuzzlesCompletedByDifficulty = {},  -- { ["2x2"]: count, ... }
	PersonalBests = {},          -- { ["imageId_difficultyId"]: bestTimeSeconds }
	Achievements = {},           -- reserved for future
	PurchaseHistory = {},        -- { { productId, timestamp } }
	OwnedBoardSkins = {},        -- { [string]: true }
	OwnedConfettiStyles = {},    -- { [string]: true }
	OwnedSnapEffects = {},       -- { [string]: true }
	HintsRemaining = 0,
	CashBoostsRemaining = 0,
	EquippedBoardSkin = "",
	EquippedConfettiStyle = "",
	EquippedSnapEffect = "",
	SavedPuzzles = {},  -- { SavedPuzzleData }, max 3 entries
	DailyReward_LastClaimTime = 0,       -- Unix timestamp
	DailyReward_Streak = 0,              -- 0-7
	DailyPuzzle_LastCompletionDate = "",  -- "YYYY-MM-DD"
	SpinWheel_LastFreeSpinDate = "",      -- "YYYY-MM-DD"
	HasClaimedFavoriteReward = false,
	StarterPack_FirstJoinTime = 0,
	StarterPack_Purchased = false,
}

-- Cap PurchaseHistory to prevent unbounded growth toward DataStore limits
local MAX_PURCHASE_HISTORY = 100

-- Migrate data from older schema versions to current
local function migrateProfile(data)
	local version = data.SchemaVersion or 0

	-- Migration from v0 (no schema version) to v1
	if version < 1 then
		-- Cap PurchaseHistory if it's grown too large
		if data.PurchaseHistory and #data.PurchaseHistory > MAX_PURCHASE_HISTORY then
			local trimmed = {}
			for i = #data.PurchaseHistory - MAX_PURCHASE_HISTORY + 1, #data.PurchaseHistory do
				table.insert(trimmed, data.PurchaseHistory[i])
			end
			data.PurchaseHistory = trimmed
		end
		data.SchemaVersion = 1
	end

	-- Migration from v1 to v2: remove XP/Level/Badge system
	if version < 2 then
		data.Level = nil
		data.XP = nil
		data.OwnedBadges = nil
		data.EquippedBadge = nil
		data.SchemaVersion = 2
	end

	-- Migration from v2 to v3: add daily rewards, daily puzzle, spin wheel fields
	if version < 3 then
		if data.DailyReward_LastClaimTime == nil then
			data.DailyReward_LastClaimTime = 0
		end
		if data.DailyReward_Streak == nil then
			data.DailyReward_Streak = 0
		end
		if data.DailyPuzzle_LastCompletionDate == nil then
			data.DailyPuzzle_LastCompletionDate = ""
		end
		if data.SpinWheel_LastFreeSpinDate == nil then
			data.SpinWheel_LastFreeSpinDate = ""
		end
		data.SchemaVersion = 3
	end

	-- Migration from v3 to v4: add CashBoostsRemaining
	if version < 4 then
		if data.CashBoostsRemaining == nil then
			data.CashBoostsRemaining = 0
		end
		data.SchemaVersion = 4
	end

	-- Migration from v4 to v5: add HasClaimedFavoriteReward
	if version < 5 then
		if data.HasClaimedFavoriteReward == nil then
			data.HasClaimedFavoriteReward = false
		end
		data.SchemaVersion = 5
	end

	-- Migration from v5 to v6: add Starter Pack fields
	if version < 6 then
		if data.StarterPack_FirstJoinTime == nil then
			data.StarterPack_FirstJoinTime = 0
		end
		if data.StarterPack_Purchased == nil then
			data.StarterPack_Purchased = false
		end
		data.SchemaVersion = 6
	end
end

local PlayerStore = ProfileStore.New("PlayerData", PROFILE_TEMPLATE)
local activeProfiles = {}
local started = false

-- Optional: PhysicalLeaderboardService (loaded if available)
local PhysicalLeaderboardService = nil
pcall(function()
	PhysicalLeaderboardService = require(script.Parent.Parent.services.PhysicalLeaderboardService)
end)

local ProfileService = {}

local function loadProfile(player)
	local profileKey = ("Player_%d"):format(player.UserId)
	local profile = PlayerStore:StartSessionAsync(profileKey, {
		Cancel = function()
			return player.Parent == nil
		end,
	})

	if profile == nil then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrateProfile(profile.Data)

	-- Set StarterPack first join time on very first load
	if profile.Data.StarterPack_FirstJoinTime == 0 then
		profile.Data.StarterPack_FirstJoinTime = os.time()
	end

	-- Seed test data in Studio so shop items are testable (double-check PlaceId to prevent accidental activation)
	if RunService:IsStudio() and game.PlaceId == 0 then
		local data = profile.Data
		-- Give enough cash to buy things
		if data.Cash < 50000 then
			data.Cash = 50000
		end
		-- Own one of each item category for testing
		data.OwnedBoardSkins["skin_midnight"] = true
		data.OwnedBoardSkins["skin_forest"] = true
		data.OwnedConfettiStyles["confetti_stars"] = true
		data.OwnedSnapEffects["snap_sparkle"] = true
		data.OwnedSnapEffects["snap_ripple"] = true
		-- Equip defaults if nothing equipped
		if data.EquippedBoardSkin == "" then
			data.EquippedBoardSkin = "skin_midnight"
		end
		if data.EquippedSnapEffect == "" then
			data.EquippedSnapEffect = "snap_sparkle"
		end
		-- Give some hints
		if data.HintsRemaining < 5 then
			data.HintsRemaining = 5
		end
		-- Give some boosts
		if data.CashBoostsRemaining < 3 then
			data.CashBoostsRemaining = 3
		end
		-- Reset starter pack timer for testing (grant snap effect so it's visible in shop)
		data.StarterPack_FirstJoinTime = os.time()
		data.StarterPack_Purchased = false
		data.OwnedSnapEffects["snap_starter"] = true
		-- Seed some puzzle completions for title testing
		if not data.PuzzlesCompletedByDifficulty or not next(data.PuzzlesCompletedByDifficulty) then
			data.PuzzlesCompletedByDifficulty = {
				["2x2"] = 10,
				["6x6"] = 5,
				["9x9"] = 3,
			}
		end
	end

	profile.OnSessionEnd:Connect(function()
		activeProfiles[player] = nil
		if player.Parent ~= nil then
			player:Kick("Your data session ended. Please rejoin.")
		end
	end)

	if player.Parent == nil then
		profile:EndSession()
		return
	end

	activeProfiles[player] = profile

	-- Submit existing stats to physical leaderboards
	if PhysicalLeaderboardService then
		task.spawn(PhysicalLeaderboardService.submitAllScores, player.UserId, profile.Data)
	end
end

local function releaseProfile(player)
	local profile = activeProfiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function ProfileService.GetProfile(player)
	return activeProfiles[player]
end

function ProfileService.GetData(player)
	local profile = activeProfiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

-- Wait for a player's profile to finish loading (up to timeoutSeconds).
-- Returns profile Data, or nil if the player left or timed out.
function ProfileService.WaitForData(player, timeoutSeconds: number?)
	local deadline = os.clock() + (timeoutSeconds or 10)
	while os.clock() < deadline do
		if player.Parent == nil then
			return nil
		end
		local profile = activeProfiles[player]
		if profile then
			return profile.Data
		end
		task.wait(0.1)
	end
	return nil
end

function ProfileService.Start()
	if started then
		return
	end
	started = true

	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(releaseProfile)
end

return ProfileService
