local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ServerScriptService:WaitForChild("Packages")
local ProfileStore = require(Packages.ProfileStore)

local PROFILE_TEMPLATE = {
	Cash = 10000,
	Level = 1,
	XP = 0,
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
	OwnedBadges = {},            -- { [string]: true }
	HintsRemaining = 0,
	EquippedBoardSkin = "",
	EquippedConfettiStyle = "",
	EquippedBadge = "",
	SavedPuzzles = {},  -- { SavedPuzzleData }, max 3 entries
}

local PlayerStore = ProfileStore.New("PlayerData", PROFILE_TEMPLATE)
local activeProfiles = {}
local started = false

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
