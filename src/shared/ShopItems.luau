export type ShopItemCategory = "board_skins" | "confetti_styles" | "hints" | "snap_effects"

export type ShopItem = {
	id: string,
	name: string,
	description: string,
	category: ShopItemCategory,
	cashPrice: number,
	previewColor: Color3?,
	backgroundImage: string?,
}

local ShopItems = {}

ShopItems.BOARD_SKINS = {
	{
		id = "skin_lightwood",
		name = "Light Wood",
		description = "Warm light wood texture",
		category = "board_skins",
		cashPrice = 75,
		previewColor = Color3.fromRGB(180, 145, 100),
		backgroundImage = "rbxassetid://75824089972863",
	},
	{
		id = "skin_wood",
		name = "Wood Grain",
		description = "Classic wood grain puzzle board",
		category = "board_skins",
		cashPrice = 100,
		previewColor = Color3.fromRGB(90, 60, 30),
		backgroundImage = "rbxassetid://123416350069330",
	},
	{
		id = "skin_marble",
		name = "Marble",
		description = "Elegant marble puzzle board",
		category = "board_skins",
		cashPrice = 150,
		previewColor = Color3.fromRGB(200, 200, 210),
		backgroundImage = "rbxassetid://79998208263835",
	},
	{
		id = "skin_felt",
		name = "Green Felt",
		description = "Classic card-table felt texture",
		category = "board_skins",
		cashPrice = 200,
		previewColor = Color3.fromRGB(40, 120, 60),
		backgroundImage = "rbxassetid://121491141036081",
	},
	{
		id = "skin_cork",
		name = "Cork Board",
		description = "Natural cork board texture",
		category = "board_skins",
		cashPrice = 350,
		previewColor = Color3.fromRGB(180, 140, 90),
		backgroundImage = "rbxassetid://119052244188021",
	},
	{
		id = "skin_brick",
		name = "Brick",
		description = "Rugged brick wall texture",
		category = "board_skins",
		cashPrice = 600,
		previewColor = Color3.fromRGB(150, 70, 50),
		backgroundImage = "rbxassetid://137276005029645",
	},
	{
		id = "skin_slate",
		name = "Slate",
		description = "Smooth premium slate texture",
		category = "board_skins",
		cashPrice = 1000,
		previewColor = Color3.fromRGB(90, 100, 110),
		backgroundImage = "rbxassetid://115212363957591",
	},
	{
		id = "skin_gold_texture",
		name = "Gold",
		description = "Luxurious gold texture",
		category = "board_skins",
		cashPrice = 2000,
		previewColor = Color3.fromRGB(200, 170, 50),
		backgroundImage = "rbxassetid://77642693440410",
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

ShopItems.SNAP_EFFECTS = {
	{
		id = "snap_sparkle",
		name = "Sparkle Burst",
		description = "Golden sparkle particles radiate outward",
		category = "snap_effects",
		cashPrice = 50,
		previewColor = Color3.fromRGB(255, 215, 60),
	},
	{
		id = "snap_candy",
		name = "Candy Pop",
		description = "Pastel square candy pieces scatter in all directions",
		category = "snap_effects",
		cashPrice = 75,
		previewColor = Color3.fromRGB(255, 180, 210),
	},
	{
		id = "snap_hearts",
		name = "Heart Pop",
		description = "Small colored hearts burst outward and float up",
		category = "snap_effects",
		cashPrice = 100,
		previewColor = Color3.fromRGB(255, 100, 140),
	},
	{
		id = "snap_frost",
		name = "Frost Burst",
		description = "Icy particles scatter and float upward",
		category = "snap_effects",
		cashPrice = 150,
		previewColor = Color3.fromRGB(180, 220, 255),
	},
	{
		id = "snap_ripple",
		name = "Ripple Wave",
		description = "A circular shockwave ring expands and fades",
		category = "snap_effects",
		cashPrice = 200,
		previewColor = Color3.fromRGB(100, 180, 255),
	},
	{
		id = "snap_toxic",
		name = "Toxic Splash",
		description = "Large neon green blobs ooze outward slowly",
		category = "snap_effects",
		cashPrice = 300,
		previewColor = Color3.fromRGB(60, 255, 60),
	},
	{
		id = "snap_fire",
		name = "Fire Blast",
		description = "Spinning embers burst out and fall like sparks",
		category = "snap_effects",
		cashPrice = 400,
		previewColor = Color3.fromRGB(255, 140, 30),
	},
	{
		id = "snap_emerald",
		name = "Emerald Flash",
		description = "A bright green ring pulses outward and fades",
		category = "snap_effects",
		cashPrice = 600,
		previewColor = Color3.fromRGB(30, 200, 100),
	},
	{
		id = "snap_lightning",
		name = "Lightning Strike",
		description = "A fast electric shockwave ring expands outward",
		category = "snap_effects",
		cashPrice = 800,
		previewColor = Color3.fromRGB(100, 180, 255),
	},
	{
		id = "snap_confetti",
		name = "Confetti Blast",
		description = "Tiny rainbow squares spin and rain down with gravity",
		category = "snap_effects",
		cashPrice = 1000,
		previewColor = Color3.fromRGB(255, 230, 50),
	},
	{
		id = "snap_shadow",
		name = "Shadow Burst",
		description = "Dark spinning fragments fall from the snap point",
		category = "snap_effects",
		cashPrice = 1500,
		previewColor = Color3.fromRGB(80, 30, 120),
	},
	{
		id = "snap_galaxy",
		name = "Galaxy Swirl",
		description = "A cosmic swirl of purple and pink particles",
		category = "snap_effects",
		cashPrice = 2500,
		previewColor = Color3.fromRGB(140, 50, 200),
	},
	{
		id = "snap_solar",
		name = "Solar Flare",
		description = "Massive fiery particles explode outward at high speed",
		category = "snap_effects",
		cashPrice = 5000,
		previewColor = Color3.fromRGB(255, 120, 20),
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
	for _, item in ShopItems.SNAP_EFFECTS do table.insert(all, item) end
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
