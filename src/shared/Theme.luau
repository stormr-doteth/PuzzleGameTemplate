local Theme = {}

-- === COLOR PALETTE === --

Theme.Colors = {
	-- Backgrounds (dark navy gradient, darkest → lightest)
	bgDeepest = Color3.fromRGB(15, 15, 25),
	bgDark = Color3.fromRGB(25, 25, 35),
	bgMedium = Color3.fromRGB(30, 30, 40),
	bgCard = Color3.fromRGB(35, 35, 50),
	bgElevated = Color3.fromRGB(40, 40, 55),
	bgInput = Color3.fromRGB(45, 45, 60),

	-- Text
	textPrimary = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(200, 200, 220),
	textMuted = Color3.fromRGB(160, 160, 180),
	textDisabled = Color3.fromRGB(120, 120, 150),

	-- Accent (primary interactive color)
	accentBlue = Color3.fromRGB(80, 140, 230),
	accentCyan = Color3.fromRGB(80, 200, 255),

	-- Status
	success = Color3.fromRGB(50, 180, 80),
	successLight = Color3.fromRGB(80, 200, 120),
	warning = Color3.fromRGB(255, 220, 80),
	gold = Color3.fromRGB(255, 215, 0),
	orange = Color3.fromRGB(255, 180, 50),
	danger = Color3.fromRGB(255, 80, 80),
	dangerDark = Color3.fromRGB(200, 60, 60),
	cashGreen = Color3.fromRGB(80, 255, 80),

	-- Utility
	black = Color3.fromRGB(0, 0, 0),
	bgHud = Color3.fromRGB(20, 20, 30),
	bgButton = Color3.fromRGB(55, 55, 75),
	bgMuted = Color3.fromRGB(100, 100, 120),

	-- Borders & chrome
	border = Color3.fromRGB(60, 60, 80),
	borderDark = Color3.fromRGB(20, 25, 40),
	scrollbar = Color3.fromRGB(80, 80, 100),

	-- Header/Feature
	headerGold = Color3.fromRGB(255, 200, 40),
	closeRed = Color3.fromRGB(220, 50, 50),

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
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
	regular = Enum.Font.Gotham,
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
