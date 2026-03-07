local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ImageCatalog = require(Shared.ImageCatalog)
local ProgressionConfig = require(Shared.ProgressionConfig)

local DailyPuzzleConfig = {}

DailyPuzzleConfig.DIFFICULTIES = { "6x6", "9x9" }
DailyPuzzleConfig.BONUS_CASH = 75

function DailyPuzzleConfig.getTodaysDateString(): string
	local utcTime = os.time()
	local utcDate = os.date("!*t", utcTime)
	return string.format("%04d-%02d-%02d", utcDate.year, utcDate.month, utcDate.day)
end

function DailyPuzzleConfig.getTodaysPuzzle(): {
	imageId: string,
	imageAssetId: string,
	imageName: string,
	thumbnailId: string,
	difficultyId: string,
	rows: number,
	cols: number,
	dateString: string,
}
	local utcTime = os.time()
	local utcDate = os.date("!*t", utcTime)

	-- Deterministic seed: year * 1000 + dayOfYear
	local seed = utcDate.year * 1000 + utcDate.yday

	-- Get all valid images (with assets)
	local allImages = ImageCatalog.getAll()
	if #allImages == 0 then
		-- Fallback: should not happen in production
		return nil :: any
	end

	-- Pick image deterministically
	local imageIndex = (seed % #allImages) + 1
	local image = allImages[imageIndex]

	-- Pick difficulty deterministically (rotate through available difficulties)
	local difficulties = DailyPuzzleConfig.DIFFICULTIES
	local diffIndex = (seed % #difficulties) + 1
	local difficultyId = difficulties[diffIndex]

	local grid = ProgressionConfig.DIFFICULTY_GRID[difficultyId]

	local dateString = DailyPuzzleConfig.getTodaysDateString()

	return {
		imageId = image.id,
		imageAssetId = image.assetId,
		imageName = image.name,
		thumbnailId = image.thumbnailId,
		difficultyId = difficultyId,
		rows = grid.rows,
		cols = grid.cols,
		dateString = dateString,
	}
end

return DailyPuzzleConfig
