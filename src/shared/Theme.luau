local Theme = {}

-- === COLOR PALETTE === --

Theme.Colors = {
	-- Backgrounds (cozy cafe gradient, darkest → lightest)
	bgDeepest = Color3.fromRGB(30, 10, 9),
	bgDark = Color3.fromRGB(55, 17, 16),
	bgMedium = Color3.fromRGB(65, 30, 28),
	bgCard = Color3.fromRGB(78, 44, 38),
	bgElevated = Color3.fromRGB(95, 58, 50),
	bgInput = Color3.fromRGB(108, 70, 62),

	-- Text (warm cream tones)
	textPrimary = Color3.fromRGB(255, 245, 235),
	textSecondary = Color3.fromRGB(220, 200, 185),
	textMuted = Color3.fromRGB(180, 155, 140),
	textDisabled = Color3.fromRGB(140, 118, 105),

	-- Accent (sienna/terracotta primary interactive color)
	accentBlue = Color3.fromRGB(164, 84, 48),
	accentCyan = Color3.fromRGB(188, 115, 72),

	-- Status
	success = Color3.fromRGB(60, 160, 75),
	successLight = Color3.fromRGB(90, 185, 110),
	warning = Color3.fromRGB(240, 200, 80),
	gold = Color3.fromRGB(255, 200, 50),
	orange = Color3.fromRGB(220, 155, 55),
	danger = Color3.fromRGB(210, 70, 65),
	dangerDark = Color3.fromRGB(175, 55, 50),
	cashGreen = Color3.fromRGB(90, 220, 90),

	-- Utility
	black = Color3.fromRGB(0, 0, 0),
	bgHud = Color3.fromRGB(40, 14, 13),
	bgButton = Color3.fromRGB(108, 70, 60),
	bgButtonContrast = Color3.fromRGB(160, 120, 55),
	bgMuted = Color3.fromRGB(129, 93, 85),

	-- Borders & chrome
	border = Color3.fromRGB(110, 78, 68),
	borderDark = Color3.fromRGB(45, 20, 18),
	scrollbar = Color3.fromRGB(129, 93, 85),

	-- Header/Feature
	headerGold = Color3.fromRGB(196, 156, 130),
	closeRed = Color3.fromRGB(200, 55, 50),

	-- Player colors (multiplayer)
	player1 = Color3.fromRGB(80, 180, 230),
	player2 = Color3.fromRGB(230, 140, 80),
	player3 = Color3.fromRGB(80, 230, 140),
	player4 = Color3.fromRGB(230, 80, 180),

	-- Ranking
	rank1 = Color3.fromRGB(255, 215, 0),
	rank2 = Color3.fromRGB(200, 200, 210),
	rank3 = Color3.fromRGB(205, 127, 50),
}

-- === TYPOGRAPHY === --

Theme.Font = {
	heading = Enum.Font.FredokaOne,
	bold = Enum.Font.FredokaOne,
	medium = Enum.Font.FredokaOne,
	regular = Enum.Font.FredokaOne,
}

Theme.TextSize = {
	title = 32,
	heading = 28,
	large = 22,
	button = 18,
	body = 15,
	label = 14,
	small = 13,
	tiny = 11,
	display = 44,
}

-- === SPACING === --

Theme.Spacing = {
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 20,
	xxl = 24,
}

-- === CORNER RADIUS === --

Theme.Radius = {
	sm = UDim.new(0, 6),
	md = UDim.new(0, 10),
	lg = UDim.new(0, 14),
	modal = UDim.new(0, 16),
}

-- === COMMON SIZES === --

Theme.Size = {
	buttonHeight = 36,
	buttonHeightLarge = 48,
	buttonHeightSmall = 28,
	rowHeight = 32,
	topBar = 50,
	bottomBar = 44,
	headerBar = 56,
	iconButton = 40,
}

-- === TRANSPARENCY === --

Theme.Transparency = {
	overlay = 0.4,
	hudButton = 0.3,
	subtle = 0.2,
	disabled = 0.5,
}

-- === Z-INDEX LAYERS === --

Theme.ZIndex = {
	board = 0,
	hud = 10,
	confetti = 100,
	modal = 150,
	xpBar = 200,
}

return Theme
