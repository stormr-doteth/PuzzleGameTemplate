local SpinWheelConfig = {}

SpinWheelConfig.FREE_SPIN_COOLDOWN_HOURS = 24

-- 8 segments with weights summing to 100
-- colorKey references Theme.Colors keys for client rendering
SpinWheelConfig.SEGMENTS = {
	{ label = "$10", type = "cash", amount = 10, weight = 20, colorKey = "bgElevated" },
	{ label = "$25", type = "cash", amount = 25, weight = 18, colorKey = "accentBlue" },
	{ label = "$50", type = "cash", amount = 50, weight = 15, colorKey = "success" },
	{ label = "$100", type = "cash", amount = 100, weight = 10, colorKey = "accentCyan" },
	{ label = "1 Hint", type = "hints", amount = 1, weight = 12, colorKey = "warning" },
	{ label = "3 Hints", type = "hints", amount = 3, weight = 8, colorKey = "orange" },
	{ label = "$200", type = "cash", amount = 200, weight = 5, colorKey = "gold" },
	{ label = "Snap Effect", type = "snap_effect", amount = 1, weight = 5, colorKey = "danger" },
	{ label = "2x Boost", type = "cash_boost", amount = 1, weight = 7, colorKey = "gold" },
}

-- Precompute total weight
SpinWheelConfig.TOTAL_WEIGHT = 0
for _, seg in SpinWheelConfig.SEGMENTS do
	SpinWheelConfig.TOTAL_WEIGHT = SpinWheelConfig.TOTAL_WEIGHT + seg.weight
end

return SpinWheelConfig
