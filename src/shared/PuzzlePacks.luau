export type PuzzlePack = {
	id: string,
	name: string,
	description: string,
	iconAssetId: string, -- large icon shown in pack selector
	sortOrder: number,
}

local PACKS: { PuzzlePack } = {
	{
		id = "landscapes",
		name = "Landscapes",
		description = "Scenic vistas and natural beauty",
		iconAssetId = "", -- TODO: replace with uploaded icon
		sortOrder = 1,
	},
	{
		id = "brain",
		name = "Brain Teasers",
		description = "Abstract and mind-bending visuals",
		iconAssetId = "",
		sortOrder = 2,
	},
	{
		id = "rot",
		name = "Rot",
		description = "Dark and decayed aesthetics",
		iconAssetId = "",
		sortOrder = 3,
	},
	{
		id = "animals",
		name = "Animals",
		description = "Furry, feathered, and finned friends",
		iconAssetId = "",
		sortOrder = 4,
	},
	{
		id = "space",
		name = "Space",
		description = "Stars, planets, and galaxies",
		iconAssetId = "",
		sortOrder = 5,
	},
	{
		id = "urban",
		name = "Urban",
		description = "City streets and architecture",
		iconAssetId = "",
		sortOrder = 6,
	},
	{
		id = "food",
		name = "Food",
		description = "Delicious dishes and treats",
		iconAssetId = "",
		sortOrder = 7,
	},
	{
		id = "art",
		name = "Art",
		description = "Paintings, pixels, and masterpieces",
		iconAssetId = "",
		sortOrder = 8,
	},
	{
		id = "brainrots",
		name = "Brainrots",
		description = "Terminally online puzzle vibes",
		iconAssetId = "",
		sortOrder = 9,
	},
	{
		id = "seals",
		name = "Seals",
		description = "Adorable seal photos from around the world",
		iconAssetId = "",
		sortOrder = 10,
	},
}

local PuzzlePacks = {}

function PuzzlePacks.getAll(): { PuzzlePack }
	local sorted = table.clone(PACKS)
	table.sort(sorted, function(a, b)
		return a.sortOrder < b.sortOrder
	end)
	return sorted
end

function PuzzlePacks.getById(id: string): PuzzlePack?
	for _, pack in PACKS do
		if pack.id == id then
			return pack
		end
	end
	return nil
end

return PuzzlePacks
