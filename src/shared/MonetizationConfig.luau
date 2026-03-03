local MonetizationConfig = {}

-- TODO: Replace all id = 0 values with actual IDs from Roblox Creator Dashboard before launch.
-- Purchases will silently fail while IDs are 0 (see isConfigured() guard below).

-- GamePass IDs (replace with actual IDs from Roblox after creating them)
MonetizationConfig.GAME_PASSES = {
	VIP = {
		id = 0, -- Replace with actual GamePass ID
		name = "VIP Pass",
		description = "2x Cash permanently + gold name on leaderboard",
		robuxPrice = 199,
		iconColor = Color3.fromRGB(255, 215, 0),
		iconText = "\u{1F451}",
	},
	ALL_IMAGES = {
		id = 0, -- Replace with actual GamePass ID
		name = "All Images Pack",
		description = "Unlock every puzzle image immediately",
		robuxPrice = 149,
		iconColor = Color3.fromRGB(80, 200, 255),
		iconText = "\u{1F5BC}",
	},
	EXPERT = {
		id = 0, -- Replace with actual GamePass ID
		name = "Expert Mode",
		description = "Unlock Expert (25x25) difficulty",
		robuxPrice = 199,
		iconColor = Color3.fromRGB(200, 80, 255),
		iconText = "\u{1F9E9}",
	},
}

-- DevProduct IDs (replace with actual IDs from Roblox after creating them)
MonetizationConfig.DEV_PRODUCTS = {
	CASH_100 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "100 Cash",
		description = "A small stack of coins to get started",
		cashAmount = 100,
		robuxPrice = 49,
		iconColor = Color3.fromRGB(80, 200, 120),
		iconText = "\u{1FA99}",
	},
	CASH_500 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "500 Cash",
		description = "A solid pile of coins for unlocks",
		cashAmount = 500,
		robuxPrice = 199,
		iconColor = Color3.fromRGB(80, 255, 80),
		iconText = "\u{1F4B0}",
	},
	CASH_1500 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "1,500 Cash",
		description = "A big bag of coins — great value!",
		cashAmount = 1500,
		robuxPrice = 499,
		iconColor = Color3.fromRGB(255, 220, 80),
		iconText = "\u{1F4B5}",
	},
	CASH_5000 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "5,000 Cash",
		description = "The mega bundle — best deal!",
		cashAmount = 5000,
		robuxPrice = 999,
		iconColor = Color3.fromRGB(255, 180, 50),
		iconText = "\u{1F48E}",
	},
	HINT_1 = {
		id = 3548789352,
		name = "Hint",
		description = "Reveals one puzzle piece placement",
		robuxPrice = 5,
		iconColor = Color3.fromRGB(255, 200, 80),
		iconText = "\u{1F4A1}",
	},
	UNLOCK_PUZZLE = {
		id = 3548796483,
		name = "Unlock Puzzle",
		description = "Unlock a single locked puzzle image",
		robuxPrice = 25,
		iconColor = Color3.fromRGB(100, 200, 255),
		iconText = "\u{1F513}",
	},
}

-- Returns true if all product IDs have been configured (non-zero)
function MonetizationConfig.isConfigured(): boolean
	for _, pass in MonetizationConfig.GAME_PASSES do
		if pass.id == 0 then
			return false
		end
	end
	for _, product in MonetizationConfig.DEV_PRODUCTS do
		if product.id == 0 then
			return false
		end
	end
	return true
end

-- Lookup DevProduct by its ID
function MonetizationConfig.getDevProductById(productId: number): any
	for _, product in MonetizationConfig.DEV_PRODUCTS do
		if product.id == productId then
			return product
		end
	end
	return nil
end

-- Lookup GamePass by its ID
function MonetizationConfig.getGamePassById(passId: number): any
	for _, pass in MonetizationConfig.GAME_PASSES do
		if pass.id == passId then
			return pass
		end
	end
	return nil
end

return MonetizationConfig
