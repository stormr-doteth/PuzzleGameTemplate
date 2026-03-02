local TitleConfig = {}

-- Weighted points per puzzle completion by difficulty
TitleConfig.POINTS_BY_DIFFICULTY = {
	["2x2"] = 1,
	["6x6"] = 3,
	["9x9"] = 5,
	["15x15"] = 8,
	["25x25"] = 15,
}

-- Title tiers (ordered by threshold, ascending)
TitleConfig.TITLES = {
	{ name = "Puzzle Newbie", threshold = 0 },
	{ name = "Puzzle Beginner", threshold = 5 },
	{ name = "Puzzle Learner", threshold = 15 },
	{ name = "Puzzle Solver", threshold = 30 },
	{ name = "Puzzle Enthusiast", threshold = 50 },
	{ name = "Puzzle Addict", threshold = 80 },
	{ name = "Puzzle Expert", threshold = 120 },
	{ name = "Puzzle Veteran", threshold = 170 },
	{ name = "Puzzle Pro", threshold = 230 },
	{ name = "Puzzle Master", threshold = 300 },
	{ name = "Puzzle Ace", threshold = 400 },
	{ name = "Puzzle Legend", threshold = 520 },
	{ name = "Puzzle Genius", threshold = 660 },
	{ name = "Puzzle Wizard", threshold = 820 },
	{ name = "Puzzle Champion", threshold = 1000 },
	{ name = "Puzzle Hero", threshold = 1250 },
	{ name = "Puzzle Titan", threshold = 1550 },
	{ name = "Puzzle Mythic", threshold = 1900 },
	{ name = "Puzzle Immortal", threshold = 2300 },
	{ name = "Puzzle God", threshold = 3000 },
}

-- Sum weighted points from puzzles completed by difficulty
function TitleConfig.getTitlePoints(puzzlesCompletedByDifficulty: { [string]: number }): number
	local total = 0
	for difficultyId, count in puzzlesCompletedByDifficulty do
		local points = TitleConfig.POINTS_BY_DIFFICULTY[difficultyId] or 0
		total += points * count
	end
	return total
end

-- Returns highest title name where threshold <= points
function TitleConfig.getTitleForPoints(points: number): string
	local bestTitle = TitleConfig.TITLES[1].name
	for _, tier in TitleConfig.TITLES do
		if points >= tier.threshold then
			bestTitle = tier.name
		else
			break
		end
	end
	return bestTitle
end

-- Convenience: get title name directly from completions table
function TitleConfig.getTitleFromCompletions(puzzlesCompletedByDifficulty: { [string]: number }): string
	local points = TitleConfig.getTitlePoints(puzzlesCompletedByDifficulty)
	return TitleConfig.getTitleForPoints(points)
end

return TitleConfig
