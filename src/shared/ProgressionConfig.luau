local ProgressionConfig = {}

-- Flat coin cost to unlock any locked puzzle
ProgressionConfig.COIN_UNLOCK_PRICE = 100

-- Coin rewards displayed per difficulty (floor(XP * 0.5))
ProgressionConfig.COIN_REWARDS_BY_DIFFICULTY = {
	["2x2"] = 5,
	["6x6"] = 50,
	["9x9"] = 125,
	["15x15"] = 300,
	["25x25"] = 750,
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
