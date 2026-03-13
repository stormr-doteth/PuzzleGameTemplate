local DailyRewardsConfig = {}

DailyRewardsConfig.STREAK_LENGTH = 7
DailyRewardsConfig.RESET_HOURS = 48
DailyRewardsConfig.MIN_CLAIM_HOURS = 20

DailyRewardsConfig.REWARDS = {
	[1] = { cash = 25, label = "$25" },
	[2] = { cash = 50, label = "$50" },
	[3] = { cash = 75, label = "$75" },
	[4] = { cash = 100, label = "$100" },
	[5] = { cash = 125, label = "$125" },
	[6] = { cash = 150, label = "$150" },
	[7] = { cash = 200, label = "$200 + Bonus!", isBonus = true },
}

-- Bonus pool for Day 7: snap effects and hint packs
DailyRewardsConfig.DAY7_BONUS_POOL = {
	{ type = "snap_effect", id = "snap_sparkle", name = "Sparkle Snap" },
	{ type = "snap_effect", id = "snap_ripple", name = "Ripple Snap" },
	{ type = "snap_effect", id = "snap_glow", name = "Glow Snap" },
	{ type = "snap_effect", id = "snap_pop", name = "Pop Snap" },
	{ type = "snap_effect", id = "snap_star", name = "Star Snap" },
	{ type = "hints", count = 3, name = "3 Hints" },
	{ type = "hints", count = 5, name = "5 Hints" },
	{ type = "cash_boost", count = 1, name = "2x Cash Boost" },
}

return DailyRewardsConfig
