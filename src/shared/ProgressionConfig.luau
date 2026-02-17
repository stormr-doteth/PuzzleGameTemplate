local ImageCatalog = require(script.Parent.ImageCatalog)

local ProgressionConfig = {}

-- XP awarded per difficulty
ProgressionConfig.XP_BY_DIFFICULTY = {
	["2x2"] = 10,
	["6x6"] = 100,
	["9x9"] = 250,
	["15x15"] = 600,
	["25x25"] = 1500,
}

-- Par times in seconds per difficulty (for speed bonus)
ProgressionConfig.PAR_TIMES = {
	["2x2"] = 15,
	["6x6"] = 180,
	["9x9"] = 480,
	["15x15"] = 1200,
	["25x25"] = 3600,
}

-- Speed bonus multiplier when completing under par time
ProgressionConfig.SPEED_BONUS_MULTIPLIER = 1.5

-- Cash earned = XP * this ratio
ProgressionConfig.CASH_PER_XP = 0.5

-- Minimum completion times in seconds (anti-cheat)
ProgressionConfig.MIN_COMPLETION_TIMES = {
	["2x2"] = 2,
	["6x6"] = 20,
	["9x9"] = 45,
	["15x15"] = 120,
	["25x25"] = 300,
}

-- Rate limit: minimum seconds between completions per player
ProgressionConfig.COMPLETION_COOLDOWN = 3

-- Level formula: XP needed to reach a given level
function ProgressionConfig.getXPForLevel(level: number): number
	if level <= 1 then return 0 end
	return math.floor(100 * level ^ 1.5)
end

-- Calculate level from total XP
function ProgressionConfig.getLevelFromXP(totalXP: number): number
	local level = 1
	while ProgressionConfig.getXPForLevel(level + 1) <= totalXP do
		level += 1
	end
	return level
end

-- Get XP progress within current level (for UI bar)
function ProgressionConfig.getLevelProgress(totalXP: number): (number, number)
	local level = ProgressionConfig.getLevelFromXP(totalXP)
	local currentLevelXP = ProgressionConfig.getXPForLevel(level)
	local nextLevelXP = ProgressionConfig.getXPForLevel(level + 1)
	local progressXP = totalXP - currentLevelXP
	local neededXP = nextLevelXP - currentLevelXP
	return progressXP, neededXP
end

-- Get images that should be unlocked at a given level
function ProgressionConfig.getUnlockedImagesAtLevel(level: number): { string }
	local unlocked = {}
	for _, entry in ImageCatalog.getAll() do
		if entry.defaultUnlocked or (entry.unlockLevel and entry.unlockLevel <= level) then
			table.insert(unlocked, entry.id)
		end
	end
	return unlocked
end

-- Valid difficulty IDs
ProgressionConfig.VALID_DIFFICULTIES = {
	["2x2"] = true,
	["6x6"] = true,
	["9x9"] = true,
	["15x15"] = true,
	["25x25"] = true,
}

ProgressionConfig.DIFFICULTY_GRID = {
	["2x2"] = { rows = 2, cols = 2 },
	["6x6"] = { rows = 6, cols = 6 },
	["9x9"] = { rows = 9, cols = 9 },
	["15x15"] = { rows = 15, cols = 15 },
	["25x25"] = { rows = 25, cols = 25 },
}

return ProgressionConfig
