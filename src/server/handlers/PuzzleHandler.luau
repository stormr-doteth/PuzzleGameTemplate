local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ProgressionConfig = require(Shared.ProgressionConfig)
local ImageCatalog = require(Shared.ImageCatalog)

local ProfileService = require(script.Parent.Parent.data.ProfileService)

-- Rate limiting: track last completion time per player
local lastCompletionTime: { [number]: number } = {}

-- Optional: LeaderboardService (loaded if available)
local LeaderboardService = nil
pcall(function()
	LeaderboardService = require(script.Parent.Parent.data.LeaderboardService)
end)

local PuzzleHandler = {}

local function validateCompletionData(data: any): (boolean, string?)
	if type(data) ~= "table" then
		return false, "Invalid data format"
	end

	if type(data.imageId) ~= "string" or data.imageId == "" then
		return false, "Invalid imageId"
	end

	if type(data.difficultyId) ~= "string" or not ProgressionConfig.VALID_DIFFICULTIES[data.difficultyId] then
		return false, "Invalid difficultyId"
	end

	if type(data.completionTime) ~= "number" or data.completionTime <= 0 then
		return false, "Invalid completionTime"
	end

	-- Check minimum completion time (anti-cheat)
	local minTime = ProgressionConfig.MIN_COMPLETION_TIMES[data.difficultyId]
	if minTime and data.completionTime < minTime then
		return false, "Completion time too fast"
	end

	-- Validate image exists
	local imageEntry = ImageCatalog.getById(data.imageId)
	if not imageEntry then
		return false, "Unknown image"
	end

	return true, nil
end

local function hasGamePass(player: Player, gamePassId: number): boolean
	local MarketplaceService = game:GetService("MarketplaceService")
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	return ok and result == true
end

function PuzzleHandler.Init()
	local puzzleCompleted = Remotes.GetEvent("PuzzleCompleted")
	local xpAwarded = Remotes.GetEvent("XPAwarded")
	local getPlayerData = Remotes.GetFunction("GetPlayerData")

	-- Handle puzzle completion
	puzzleCompleted.OnServerEvent:Connect(function(player, data)
		-- Rate limiting
		local now = os.clock()
		local lastTime = lastCompletionTime[player.UserId]
		if lastTime and (now - lastTime) < ProgressionConfig.COMPLETION_COOLDOWN then
			warn("[PuzzleHandler] Rate limited:", player.Name)
			return
		end
		lastCompletionTime[player.UserId] = now

		-- Validate data
		local valid, err = validateCompletionData(data)
		if not valid then
			warn("[PuzzleHandler] Invalid completion data from", player.Name, ":", err)
			return
		end

		-- Get profile
		local profileData = ProfileService.GetData(player)
		if not profileData then
			warn("[PuzzleHandler] No profile for", player.Name)
			return
		end

		local difficultyId = data.difficultyId
		local completionTime = data.completionTime

		-- Calculate base XP
		local baseXP = ProgressionConfig.XP_BY_DIFFICULTY[difficultyId] or 0

		-- Check for speed bonus
		local parTime = ProgressionConfig.PAR_TIMES[difficultyId]
		local isSpeedBonus = parTime and completionTime <= parTime
		local xpGained = baseXP
		if isSpeedBonus then
			xpGained = math.floor(baseXP * ProgressionConfig.SPEED_BONUS_MULTIPLIER)
		end

		-- Check VIP GamePass for 2x XP (MonetizationConfig loaded optionally)
		local MonetizationConfig = nil
		pcall(function()
			MonetizationConfig = require(Shared.MonetizationConfig)
		end)
		if MonetizationConfig and MonetizationConfig.GAME_PASSES and MonetizationConfig.GAME_PASSES.VIP then
			if hasGamePass(player, MonetizationConfig.GAME_PASSES.VIP.id) then
				xpGained = xpGained * 2
			end
		end

		-- Calculate cash
		local cashGained = math.floor(xpGained * ProgressionConfig.CASH_PER_XP)

		-- Update profile
		local oldLevel = profileData.Level
		profileData.XP = profileData.XP + xpGained
		profileData.Cash = profileData.Cash + cashGained
		profileData.TotalPuzzlesCompleted = (profileData.TotalPuzzlesCompleted or 0) + 1
		profileData.TotalPlayTime = (profileData.TotalPlayTime or 0) + completionTime

		local grid = ProgressionConfig.DIFFICULTY_GRID[difficultyId]
		if grid then
			profileData.TotalPiecesPlaced = (profileData.TotalPiecesPlaced or 0) + (grid.rows * grid.cols)
		end
		if not profileData.PuzzlesCompletedByDifficulty then
			profileData.PuzzlesCompletedByDifficulty = {}
		end
		profileData.PuzzlesCompletedByDifficulty[difficultyId] = (profileData.PuzzlesCompletedByDifficulty[difficultyId] or 0) + 1

		-- Calculate new level
		local newLevel = ProgressionConfig.getLevelFromXP(profileData.XP)
		profileData.Level = newLevel

		-- Check for personal best
		local bestKey = data.imageId .. "_" .. difficultyId
		if not profileData.PersonalBests then
			profileData.PersonalBests = {}
		end
		local previousBest = profileData.PersonalBests[bestKey]
		local isPersonalBest = not previousBest or completionTime < previousBest
		if isPersonalBest then
			profileData.PersonalBests[bestKey] = completionTime
		end

		-- Check for new image unlocks
		local newlyUnlocked = {}
		if newLevel > oldLevel then
			if not profileData.UnlockedImages then
				profileData.UnlockedImages = {}
			end
			local allUnlocked = ProgressionConfig.getUnlockedImagesAtLevel(newLevel)
			for _, imgId in allUnlocked do
				if not profileData.UnlockedImages[imgId] then
					profileData.UnlockedImages[imgId] = true
					table.insert(newlyUnlocked, imgId)
				end
			end
		end

		-- Submit to leaderboard if personal best
		if isPersonalBest and LeaderboardService then
			task.spawn(function()
				LeaderboardService.submitTime(player.UserId, difficultyId, completionTime)
			end)
		end

		-- Fire reward data back to client
		xpAwarded:FireClient(player, {
			xpGained = xpGained,
			cashGained = cashGained,
			newLevel = if newLevel > oldLevel then newLevel else nil,
			unlockedImages = if #newlyUnlocked > 0 then newlyUnlocked else nil,
			isPersonalBest = isPersonalBest,
			isSpeedBonus = isSpeedBonus,
			previousBest = previousBest,
		})

		-- Clear any matching saved puzzle (same imageId + difficultyId)
		if profileData.SavedPuzzles then
			for i = #profileData.SavedPuzzles, 1, -1 do
				local save = profileData.SavedPuzzles[i]
				if save.imageId == data.imageId and save.difficultyId == data.difficultyId then
					table.remove(profileData.SavedPuzzles, i)
				end
			end
		end

		print(string.format(
			"[PuzzleHandler] %s completed %s on %s in %.1fs (+%dXP +%dCash%s%s)",
			player.Name, difficultyId, data.imageId, completionTime,
			xpGained, cashGained,
			if isSpeedBonus then " SPEED BONUS" else "",
			if newLevel > oldLevel then " LEVEL UP to " .. newLevel else ""
		))
	end)

	-- Handle GetPlayerData requests
	getPlayerData.OnServerInvoke = function(player)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return nil
		end

		-- Build unlocked images map
		local unlockedImages = {}
		-- Add default unlocked
		for _, entry in ImageCatalog.getAll() do
			if entry.defaultUnlocked then
				unlockedImages[entry.id] = true
			end
		end
		-- Add level-unlocked
		local levelUnlocks = ProgressionConfig.getUnlockedImagesAtLevel(profileData.Level)
		for _, imgId in levelUnlocks do
			unlockedImages[imgId] = true
		end
		-- Add any manually unlocked (from purchases etc.)
		if profileData.UnlockedImages then
			for imgId, val in profileData.UnlockedImages do
				if val then
					unlockedImages[imgId] = true
				end
			end
		end

		-- Check for All Images GamePass
		local MonetizationConfig = nil
		pcall(function()
			MonetizationConfig = require(Shared.MonetizationConfig)
		end)
		if MonetizationConfig and MonetizationConfig.GAME_PASSES and MonetizationConfig.GAME_PASSES.ALL_IMAGES then
			if hasGamePass(player, MonetizationConfig.GAME_PASSES.ALL_IMAGES.id) then
				for _, entry in ImageCatalog.getAll() do
					unlockedImages[entry.id] = true
				end
			end
		end

		return {
			level = profileData.Level,
			xp = profileData.XP,
			cash = profileData.Cash,
			unlockedImages = unlockedImages,
			personalBests = profileData.PersonalBests or {},
			equippedBoardSkin = profileData.EquippedBoardSkin or "",
			equippedConfettiStyle = profileData.EquippedConfettiStyle or "",
			equippedBadge = profileData.EquippedBadge or "",
			hintsRemaining = profileData.HintsRemaining or 0,
			ownedBoardSkins = profileData.OwnedBoardSkins or {},
			ownedConfettiStyles = profileData.OwnedConfettiStyles or {},
			ownedBadges = profileData.OwnedBadges or {},
			totalPuzzlesCompleted = profileData.TotalPuzzlesCompleted or 0,
			totalPlayTime = profileData.TotalPlayTime or 0,
			totalPiecesPlaced = profileData.TotalPiecesPlaced or 0,
			puzzlesCompletedByDifficulty = profileData.PuzzlesCompletedByDifficulty or {},
		}
	end

	-- Handle GetLeaderboard requests (Phase 3)
	local getLeaderboard = Remotes.GetFunction("GetLeaderboard")
	getLeaderboard.OnServerInvoke = function(player, difficultyId)
		if not LeaderboardService then
			return {}
		end
		if type(difficultyId) ~= "string" or not ProgressionConfig.VALID_DIFFICULTIES[difficultyId] then
			return {}
		end
		return LeaderboardService.getTopTimes(difficultyId, 50)
	end

	-- Handle SavePuzzle requests
	local savePuzzle = Remotes.GetFunction("SavePuzzle")
	savePuzzle.OnServerInvoke = function(player, data)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false }
		end

		-- Validate data
		if type(data) ~= "table" then
			return { success = false }
		end
		if type(data.imageId) ~= "string" or type(data.imageAssetId) ~= "string" then
			return { success = false }
		end
		if type(data.difficultyId) ~= "string" or type(data.rows) ~= "number" or type(data.cols) ~= "number" then
			return { success = false }
		end
		if type(data.elapsedSeconds) ~= "number" or type(data.savedAt) ~= "number" then
			return { success = false }
		end
		if type(data.puzzleDef) ~= "table" or type(data.pieces) ~= "table" then
			return { success = false }
		end

		profileData.SavedPuzzles = profileData.SavedPuzzles or {}

		-- Replace existing save for same imageId + difficultyId if present
		for i, save in profileData.SavedPuzzles do
			if save.imageId == data.imageId and save.difficultyId == data.difficultyId then
				profileData.SavedPuzzles[i] = data
				return { success = true, slotIndex = i }
			end
		end

		local slotIndex
		if #profileData.SavedPuzzles < 3 then
			table.insert(profileData.SavedPuzzles, data)
			slotIndex = #profileData.SavedPuzzles
		else
			-- Replace oldest (lowest savedAt)
			local oldestIdx = 1
			local oldestTime = profileData.SavedPuzzles[1].savedAt or 0
			for i, save in profileData.SavedPuzzles do
				local t = save.savedAt or 0
				if t < oldestTime then
					oldestTime = t
					oldestIdx = i
				end
			end
			profileData.SavedPuzzles[oldestIdx] = data
			slotIndex = oldestIdx
		end

		return { success = true, slotIndex = slotIndex }
	end

	-- Handle LoadSavedPuzzles requests
	local loadSavedPuzzles = Remotes.GetFunction("LoadSavedPuzzles")
	loadSavedPuzzles.OnServerInvoke = function(player)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return {}
		end
		return profileData.SavedPuzzles or {}
	end

	-- Handle DeleteSavedPuzzle requests
	local deleteSavedPuzzle = Remotes.GetFunction("DeleteSavedPuzzle")
	deleteSavedPuzzle.OnServerInvoke = function(player, slotIndex)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false }
		end

		profileData.SavedPuzzles = profileData.SavedPuzzles or {}

		if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > #profileData.SavedPuzzles then
			return { success = false }
		end

		table.remove(profileData.SavedPuzzles, math.floor(slotIndex))
		return { success = true }
	end

	-- Handle UseHint requests
	local useHint = Remotes.GetFunction("UseHint")
	useHint.OnServerInvoke = function(player)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, hintsRemaining = 0 }
		end

		local hints = profileData.HintsRemaining or 0
		if hints <= 0 then
			return { success = false, hintsRemaining = 0 }
		end

		profileData.HintsRemaining = hints - 1
		return { success = true, hintsRemaining = profileData.HintsRemaining }
	end
end

return PuzzleHandler
