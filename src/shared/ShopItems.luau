export type ShopItemCategory = "board_skins" | "confetti_styles" | "badges" | "hints"

export type ShopItem = {
	id: string,
	name: string,
	description: string,
	category: ShopItemCategory,
	cashPrice: number,
	previewColor: Color3?,
}

local ShopItems = {}

ShopItems.BOARD_SKINS = {
	{
		id = "skin_midnight",
		name = "Midnight",
		description = "Deep dark blue puzzle board",
		category = "board_skins",
		cashPrice = 50,
		previewColor = Color3.fromRGB(15, 15, 45),
	},
	{
		id = "skin_forest",
		name = "Forest",
		description = "Natural green puzzle board",
		category = "board_skins",
		cashPrice = 50,
		previewColor = Color3.fromRGB(20, 45, 20),
	},
	{
		id = "skin_sunset",
		name = "Sunset",
		description = "Warm orange puzzle board",
		category = "board_skins",
		cashPrice = 75,
		previewColor = Color3.fromRGB(60, 30, 15),
	},
	{
		id = "skin_royal",
		name = "Royal",
		description = "Rich purple puzzle board",
		category = "board_skins",
		cashPrice = 100,
		previewColor = Color3.fromRGB(40, 15, 60),
	},
	{
		id = "skin_gold",
		name = "Gold",
		description = "Luxurious gold puzzle board",
		category = "board_skins",
		cashPrice = 200,
		previewColor = Color3.fromRGB(60, 50, 15),
	},
}

ShopItems.CONFETTI_STYLES = {
	{
		id = "confetti_hearts",
		name = "Hearts",
		description = "Heart-shaped celebration confetti",
		category = "confetti_styles",
		cashPrice = 75,
	},
	{
		id = "confetti_stars",
		name = "Stars",
		description = "Star-shaped celebration confetti",
		category = "confetti_styles",
		cashPrice = 75,
	},
	{
		id = "confetti_rainbow",
		name = "Rainbow",
		description = "Extra vibrant rainbow confetti",
		category = "confetti_styles",
		cashPrice = 100,
	},
	{
		id = "confetti_fire",
		name = "Fire",
		description = "Hot red and orange confetti",
		category = "confetti_styles",
		cashPrice = 125,
	},
}

ShopItems.BADGES = {
	{
		id = "badge_puzzle_master",
		name = "Puzzle Master",
		description = "Show off your puzzle expertise",
		category = "badges",
		cashPrice = 100,
	},
	{
		id = "badge_speedrunner",
		name = "Speedrunner",
		description = "For those who live fast",
		category = "badges",
		cashPrice = 100,
	},
	{
		id = "badge_collector",
		name = "Collector",
		description = "A true image collector",
		category = "badges",
		cashPrice = 150,
	},
	{
		id = "badge_champion",
		name = "Champion",
		description = "The ultimate puzzle champion badge",
		category = "badges",
		cashPrice = 250,
	},
}

ShopItems.HINTS = {
	{
		id = "hint_pack_3",
		name = "3 Hints",
		description = "Highlights where a piece goes (3s glow)",
		category = "hints",
		cashPrice = 10,
		hintCount = 3,
	},
	{
		id = "hint_pack_10",
		name = "10 Hints",
		description = "Highlights where a piece goes (3s glow)",
		category = "hints",
		cashPrice = 25,
		hintCount = 10,
	},
}

function ShopItems.getAll(): { ShopItem }
	local all = {}
	for _, item in ShopItems.BOARD_SKINS do table.insert(all, item) end
	for _, item in ShopItems.CONFETTI_STYLES do table.insert(all, item) end
	for _, item in ShopItems.BADGES do table.insert(all, item) end
	for _, item in ShopItems.HINTS do table.insert(all, item) end
	return all
end

function ShopItems.getById(id: string): ShopItem?
	for _, item in ShopItems.getAll() do
		if item.id == id then
			return item
		end
	end
	return nil
end

return ShopItems
