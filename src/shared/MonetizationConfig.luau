local MonetizationConfig = {}

-- GamePass IDs (replace with actual IDs from Roblox after creating them)
MonetizationConfig.GAME_PASSES = {
	VIP = {
		id = 0, -- Replace with actual GamePass ID
		name = "VIP Pass",
		description = "2x XP permanently + gold name on leaderboard",
		robuxPrice = 199,
	},
	ALL_IMAGES = {
		id = 0, -- Replace with actual GamePass ID
		name = "All Images Pack",
		description = "Unlock every puzzle image immediately",
		robuxPrice = 149,
	},
}

-- DevProduct IDs (replace with actual IDs from Roblox after creating them)
MonetizationConfig.DEV_PRODUCTS = {
	CASH_50 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "50 Cash",
		description = "Add 50 Cash to your balance",
		cashAmount = 50,
		robuxPrice = 49,
	},
	CASH_100 = {
		id = 0, -- Replace with actual DevProduct ID
		name = "100 Cash",
		description = "Add 100 Cash to your balance",
		cashAmount = 100,
		robuxPrice = 79,
	},
	SKIP_LEVEL = {
		id = 0, -- Replace with actual DevProduct ID
		name = "Skip Level",
		description = "Grant enough XP to reach the next level",
		robuxPrice = 99,
	},
}

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
