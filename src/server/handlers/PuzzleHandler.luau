local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ProgressionConfig = require(Shared.ProgressionConfig)
local ImageCatalog = require(Shared.ImageCatalog)

local ProfileService = require(script.Parent.Parent.data.ProfileService)
local TitleConfig = require(Shared.TitleConfig)

-- TitleService loaded optionally
local TitleService = nil
pcall(function()
	TitleService = require(script.Parent.Parent.services.TitleService)
end)

-- Rate limiting: track last completion time per player
local lastCompletionTime: { [number]: number } = {}
-- Per-player lock to prevent same-frame duplicate processing
local processingCompletion: { [number]: boolean } = {}
-- Rate limiting for GetPlayerData (1 call per second per player)
local lastGetDataTime: { [number]: number } = {}

-- Track which players have activated a cash boost for their current puzzle
local activatedBoosts: { [number]: boolean } = {}

-- Server-side puzzle start times for anti-cheat timing
local puzzleStartTimes: { [number]: { startTime: number, imageId: string, difficultyId: string } } = {}

-- Per-player processing locks to prevent race-condition double-spending
local processingHint: { [number]: boolean } = {}
local processingUnlock: { [number]: boolean } = {}

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

	if type(data.completionTime) ~= "number" or data.completionTime <= 0
		or data.completionTime ~= data.completionTime  -- NaN check
		or data.completionTime == math.huge then
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
	local Players = game:GetService("Players")

	local puzzleCompleted = Remotes.GetEvent("PuzzleCompleted")
	local xpAwarded = Remotes.GetEvent("XPAwarded")
	local getPlayerData = Remotes.GetFunction("GetPlayerData")

	-- Clean up activated boost flag when player leaves
	Players.PlayerRemoving:Connect(function(player)
		activatedBoosts[player.UserId] = nil
		lastCompletionTime[player.UserId] = nil
		processingCompletion[player.UserId] = nil
		lastGetDataTime[player.UserId] = nil
		puzzleStartTimes[player.UserId] = nil
		processingHint[player.UserId] = nil
		processingUnlock[player.UserId] = nil
	end)

	-- Handle PuzzleStarted — record server-side start time
	local puzzleStarted = Remotes.GetEvent("PuzzleStarted")
	puzzleStarted.OnServerEvent:Connect(function(player, data)
		if type(data) ~= "table" then return end
		if type(data.imageId) ~= "string" or data.imageId == "" then return end
		if type(data.difficultyId) ~= "string" or not ProgressionConfig.VALID_DIFFICULTIES[data.difficultyId] then return end

		local startTime = os.clock()

		-- Handle resumed puzzles: adjust start time to account for prior elapsed
		if data.resumedElapsed ~= nil then
			if type(data.resumedElapsed) ~= "number" or data.resumedElapsed < 0
				or data.resumedElapsed ~= data.resumedElapsed  -- NaN check
				or data.resumedElapsed == math.huge then
				return
			end
			-- Cap at 24 hours to prevent abuse
			if data.resumedElapsed > 86400 then return end
			-- Validate that a matching saved puzzle exists on server
			local profileData = ProfileService.GetData(player)
			if profileData and profileData.SavedPuzzles then
				local found = false
				for _, save in profileData.SavedPuzzles do
					if save.imageId == data.imageId and save.difficultyId == data.difficultyId then
						found = true
						break
					end
				end
				if not found then return end
			else
				return
			end
			startTime = os.clock() - data.resumedElapsed
		end

		puzzleStartTimes[player.UserId] = {
			startTime = startTime,
			imageId = data.imageId,
			difficultyId = data.difficultyId,
		}
	end)

	-- Handle puzzle completion
	puzzleCompleted.OnServerEvent:Connect(function(player, data)
		-- Prevent same-frame duplicate processing
		if processingCompletion[player.UserId] then
			return
		end

		-- Rate limiting
		local now = os.clock()
		local lastTime = lastCompletionTime[player.UserId]
		if lastTime and (now - lastTime) < ProgressionConfig.COMPLETION_COOLDOWN then
			warn("[PuzzleHandler] Rate limited:", player.Name)
			return
		end
		lastCompletionTime[player.UserId] = now
		processingCompletion[player.UserId] = true

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

		-- Use server-side timing instead of client-provided completionTime
		local startRecord = puzzleStartTimes[player.UserId]
		if not startRecord then
			warn("[PuzzleHandler] No start record for", player.Name)
			processingCompletion[player.UserId] = nil
			return
		end
		if startRecord.imageId ~= data.imageId or startRecord.difficultyId ~= data.difficultyId then
			warn("[PuzzleHandler] Start record mismatch for", player.Name)
			processingCompletion[player.UserId] = nil
			return
		end
		local completionTime = os.clock() - startRecord.startTime
		puzzleStartTimes[player.UserId] = nil

		-- Calculate base cash reward
		local baseCash = ProgressionConfig.COIN_REWARDS_BY_DIFFICULTY[difficultyId] or 0

		-- Check for speed bonus
		local parTime = ProgressionConfig.PAR_TIMES[difficultyId]
		local isSpeedBonus = parTime and completionTime <= parTime
		local cashGained = baseCash
		if isSpeedBonus then
			cashGained = math.floor(baseCash * ProgressionConfig.SPEED_BONUS_MULTIPLIER)
		end

		-- Check VIP GamePass for 2x Cash (MonetizationConfig loaded optionally)
		local MonetizationConfig = nil
		pcall(function()
			MonetizationConfig = require(Shared.MonetizationConfig)
		end)
		if MonetizationConfig and MonetizationConfig.GAME_PASSES and MonetizationConfig.GAME_PASSES.VIP then
			if hasGamePass(player, MonetizationConfig.GAME_PASSES.VIP.id) then
				cashGained = cashGained * 2
			end
		end

		-- Check for activated 2x Cash Boost
		local boostUsed = false
		if activatedBoosts[player.UserId] then
			cashGained = cashGained * 2
			profileData.CashBoostsRemaining = math.max(0, (profileData.CashBoostsRemaining or 0) - 1)
			activatedBoosts[player.UserId] = nil
			boostUsed = true
		end

		-- Update profile
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

		-- Update title billboard
		if TitleService then
			TitleService.UpdateTitle(player, profileData.PuzzlesCompletedByDifficulty)
		end

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

		-- Submit to leaderboard if personal best
		if isPersonalBest and LeaderboardService then
			task.spawn(function()
				LeaderboardService.submitTime(player.UserId, difficultyId, completionTime)
			end)
		end

		-- Fire reward data back to client
		xpAwarded:FireClient(player, {
			cashGained = cashGained,
			isPersonalBest = isPersonalBest,
			isSpeedBonus = isSpeedBonus,
			previousBest = previousBest,
			boostUsed = boostUsed,
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

		processingCompletion[player.UserId] = nil
	end)

	-- Handle GetPlayerData requests
	getPlayerData.OnServerInvoke = function(player)
		-- Rate limit: 1 call per second
		local now = os.clock()
		local lastTime = lastGetDataTime[player.UserId]
		if lastTime and (now - lastTime) < 1 then
			return nil
		end
		lastGetDataTime[player.UserId] = now

		-- Wait for profile to load (handles Play Solo race condition)
		local profileData = ProfileService.WaitForData(player, 10)
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
		-- Add any unlocked (from purchases etc.)
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

		-- Check for Expert gamepass
		local hasExpertPass = false
		if MonetizationConfig and MonetizationConfig.GAME_PASSES and MonetizationConfig.GAME_PASSES.EXPERT then
			hasExpertPass = hasGamePass(player, MonetizationConfig.GAME_PASSES.EXPERT.id)
		end

		local completions = profileData.PuzzlesCompletedByDifficulty or {}
		local titleName = TitleConfig.getTitleFromCompletions(completions)

		return {
			cash = profileData.Cash,
			unlockedImages = unlockedImages,
			personalBests = profileData.PersonalBests or {},
			hasExpertPass = hasExpertPass,
			titleName = titleName,
			equippedBoardSkin = profileData.EquippedBoardSkin or "",
			equippedConfettiStyle = profileData.EquippedConfettiStyle or "",
			equippedSnapEffect = profileData.EquippedSnapEffect or "",
			hintsRemaining = profileData.HintsRemaining or 0,
			cashBoostsRemaining = profileData.CashBoostsRemaining or 0,
			ownedBoardSkins = profileData.OwnedBoardSkins or {},
			ownedConfettiStyles = profileData.OwnedConfettiStyles or {},
			ownedSnapEffects = profileData.OwnedSnapEffects or {},
			totalPuzzlesCompleted = profileData.TotalPuzzlesCompleted or 0,
			totalPlayTime = profileData.TotalPlayTime or 0,
			totalPiecesPlaced = profileData.TotalPiecesPlaced or 0,
			puzzlesCompletedByDifficulty = completions,
			dailyReward_lastClaimTime = profileData.DailyReward_LastClaimTime or 0,
			dailyReward_streak = profileData.DailyReward_Streak or 0,
			dailyPuzzle_lastCompletionDate = profileData.DailyPuzzle_LastCompletionDate or "",
			spinWheel_lastFreeSpinDate = profileData.SpinWheel_LastFreeSpinDate or "",
			hasClaimedFavoriteReward = profileData.HasClaimedFavoriteReward == true,
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

		-- Validate imageAssetId format
		if not string.match(data.imageAssetId, "^rbxassetid://%d+$") then
			return { success = false }
		end

		-- Validate difficultyId is known
		if not ProgressionConfig.VALID_DIFFICULTIES[data.difficultyId] then
			return { success = false }
		end

		-- Validate rows/cols match difficulty and are in range
		local expectedGrid = ProgressionConfig.DIFFICULTY_GRID[data.difficultyId]
		if expectedGrid then
			if data.rows ~= expectedGrid.rows or data.cols ~= expectedGrid.cols then
				return { success = false }
			end
		end
		if data.rows < 2 or data.rows > 25 or data.cols < 2 or data.cols > 25 then
			return { success = false }
		end

		-- Validate imageId exists
		if not ImageCatalog.getById(data.imageId) then
			return { success = false }
		end

		-- Validate NaN/Infinity
		if data.elapsedSeconds ~= data.elapsedSeconds or data.elapsedSeconds == math.huge then
			return { success = false }
		end

		-- Validate puzzleDef has expected structure and piece count matches grid
		if type(data.puzzleDef.pieces) ~= "table" then
			return { success = false }
		end
		local expectedPieceCount = data.rows * data.cols
		if #data.puzzleDef.pieces ~= expectedPieceCount or #data.pieces > expectedPieceCount then
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

	-- Handle UseHint requests (with processing lock to prevent double-spend)
	local useHint = Remotes.GetFunction("UseHint")
	useHint.OnServerInvoke = function(player)
		if processingHint[player.UserId] then
			return { success = false, hintsRemaining = 0 }
		end
		processingHint[player.UserId] = true

		local profileData = ProfileService.GetData(player)
		if not profileData then
			processingHint[player.UserId] = nil
			return { success = false, hintsRemaining = 0 }
		end

		local hints = profileData.HintsRemaining or 0
		if hints <= 0 then
			processingHint[player.UserId] = nil
			return { success = false, hintsRemaining = 0 }
		end

		profileData.HintsRemaining = hints - 1
		processingHint[player.UserId] = nil
		return { success = true, hintsRemaining = profileData.HintsRemaining }
	end

	-- Handle ActivateCashBoost requests
	local activateBoost = Remotes.GetFunction("ActivateCashBoost")
	activateBoost.OnServerInvoke = function(player)
		local profileData = ProfileService.GetData(player)
		if not profileData then
			return { success = false, cashBoostsRemaining = 0 }
		end

		-- Toggle: if already activated, deactivate
		if activatedBoosts[player.UserId] then
			activatedBoosts[player.UserId] = nil
			return { success = true, active = false, cashBoostsRemaining = profileData.CashBoostsRemaining or 0 }
		end

		local boosts = profileData.CashBoostsRemaining or 0
		if boosts <= 0 then
			return { success = false, cashBoostsRemaining = 0 }
		end

		activatedBoosts[player.UserId] = true
		return { success = true, active = true, cashBoostsRemaining = profileData.CashBoostsRemaining or 0 }
	end

	-- Handle UnlockImage requests (coin purchase, with processing lock to prevent double-spend)
	local unlockImage = Remotes.GetFunction("UnlockImage")
	unlockImage.OnServerInvoke = function(player, imageId)
		if processingUnlock[player.UserId] then
			return { success = false, message = "Processing" }
		end
		processingUnlock[player.UserId] = true

		if type(imageId) ~= "string" or imageId == "" then
			processingUnlock[player.UserId] = nil
			return { success = false, message = "Invalid imageId" }
		end

		local entry = ImageCatalog.getById(imageId)
		if not entry then
			processingUnlock[player.UserId] = nil
			return { success = false, message = "Unknown image" }
		end

		local profileData = ProfileService.GetData(player)
		if not profileData then
			processingUnlock[player.UserId] = nil
			return { success = false, message = "Profile not loaded" }
		end

		if not profileData.UnlockedImages then
			profileData.UnlockedImages = {}
		end

		if profileData.UnlockedImages[imageId] or entry.defaultUnlocked then
			processingUnlock[player.UserId] = nil
			return { success = false, message = "Already unlocked" }
		end

		local price = ProgressionConfig.COIN_UNLOCK_PRICE
		if profileData.Cash < price then
			processingUnlock[player.UserId] = nil
			return { success = false, message = "Not enough coins" }
		end

		profileData.Cash = profileData.Cash - price
		profileData.UnlockedImages[imageId] = true
		processingUnlock[player.UserId] = nil
		return { success = true, newCash = profileData.Cash }
	end
end

return PuzzleHandler
