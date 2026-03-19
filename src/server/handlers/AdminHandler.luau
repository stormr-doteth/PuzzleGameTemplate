local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	DailyReward_LastClaimTime = 0,
	DailyReward_Streak = 0,
	DailyPuzzle_LastCompletionDate = "",
	SpinWheel_LastFreeSpinDate = "",
	HasClaimedFavoriteReward = false,
}

local Players = game:GetService("Players")

local joinTimes: { [Player]: number } = {}

local AdminHandler = {}

function AdminHandler.Init()
	-- Track player join times
	local function onPlayerAdded(player: Player)
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
end

return AdminHandler
