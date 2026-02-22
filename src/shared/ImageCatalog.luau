export type ImageEntry = {
	id: string,
	assetId: string,
	name: string,
	thumbnailId: string,
	category: string,
	defaultUnlocked: boolean,
	unlockLevel: number?,
}

local IMAGES: { ImageEntry } = {
	{
		id = "sunset_mountains",
		assetId = "rbxassetid://129720055698342",
		name = "Sunset Mountains",
		thumbnailId = "rbxassetid://129720055698342",
		category = "Nature",
		defaultUnlocked = true,
	},
	{
		id = "ocean_waves",
		assetId = "rbxassetid://87562993721412",
		name = "Ocean Waves",
		thumbnailId = "rbxassetid://87562993721412",
		category = "Nature",
		defaultUnlocked = true,
	},
	{
		id = "forest_path",
		assetId = "rbxassetid://100081078259498",
		name = "Forest Path",
		thumbnailId = "rbxassetid://100081078259498",
		category = "Nature",
		defaultUnlocked = true,
	},
	{
		id = "city_skyline",
		assetId = "rbxassetid://108408685486498",
		name = "City Skyline",
		thumbnailId = "rbxassetid://108408685486498",
		category = "Urban",
		defaultUnlocked = false,
		unlockLevel = 3,
	},
	{
		id = "space_nebula",
		assetId = "rbxassetid://127494809663498",
		name = "Space Nebula",
		thumbnailId = "rbxassetid://127494809663498",
		category = "Space",
		defaultUnlocked = false,
		unlockLevel = 5,
	},
	{
		id = "tropical_beach",
		assetId = "rbxassetid://135021200052498",
		name = "Tropical Beach",
		thumbnailId = "rbxassetid://135021200052498",
		category = "Nature",
		defaultUnlocked = false,
		unlockLevel = 8,
	},
	{
		id = "northern_lights",
		assetId = "rbxassetid://106848498378498",
		name = "Northern Lights",
		thumbnailId = "rbxassetid://106848498378498",
		category = "Nature",
		defaultUnlocked = false,
		unlockLevel = 12,
	},
	{
		id = "abstract_art",
		assetId = "rbxassetid://139907825498498",
		name = "Abstract Art",
		thumbnailId = "rbxassetid://139907825498498",
		category = "Art",
		defaultUnlocked = false,
		unlockLevel = 18,
	},
	-- Placeholder entries (fill in real asset IDs later)
	{
		id = "coral_reef",
		assetId = "",
		name = "Coral Reef",
		thumbnailId = "",
		category = "Nature",
		defaultUnlocked = true,
	},
	{
		id = "golden_retriever",
		assetId = "",
		name = "Golden Retriever",
		thumbnailId = "",
		category = "Animals",
		defaultUnlocked = true,
	},
	{
		id = "sushi_platter",
		assetId = "",
		name = "Sushi Platter",
		thumbnailId = "",
		category = "Food",
		defaultUnlocked = true,
	},
	{
		id = "autumn_leaves",
		assetId = "",
		name = "Autumn Leaves",
		thumbnailId = "",
		category = "Nature",
		defaultUnlocked = false,
		unlockLevel = 2,
	},
	{
		id = "tokyo_street",
		assetId = "",
		name = "Tokyo Street",
		thumbnailId = "",
		category = "Urban",
		defaultUnlocked = false,
		unlockLevel = 3,
	},
	{
		id = "kitten_nap",
		assetId = "",
		name = "Kitten Nap",
		thumbnailId = "",
		category = "Animals",
		defaultUnlocked = false,
		unlockLevel = 4,
	},
	{
		id = "mars_surface",
		assetId = "",
		name = "Mars Surface",
		thumbnailId = "",
		category = "Space",
		defaultUnlocked = false,
		unlockLevel = 5,
	},
	{
		id = "watercolor_flowers",
		assetId = "",
		name = "Watercolor Flowers",
		thumbnailId = "",
		category = "Art",
		defaultUnlocked = false,
		unlockLevel = 6,
	},
	{
		id = "pizza_slice",
		assetId = "",
		name = "Pizza Slice",
		thumbnailId = "",
		category = "Food",
		defaultUnlocked = false,
		unlockLevel = 7,
	},
	{
		id = "rainy_window",
		assetId = "",
		name = "Rainy Window",
		thumbnailId = "",
		category = "Urban",
		defaultUnlocked = false,
		unlockLevel = 8,
	},
	{
		id = "parrot_portrait",
		assetId = "",
		name = "Parrot Portrait",
		thumbnailId = "",
		category = "Animals",
		defaultUnlocked = false,
		unlockLevel = 9,
	},
	{
		id = "galaxy_spiral",
		assetId = "",
		name = "Galaxy Spiral",
		thumbnailId = "",
		category = "Space",
		defaultUnlocked = false,
		unlockLevel = 10,
	},
	{
		id = "cherry_blossom",
		assetId = "",
		name = "Cherry Blossom",
		thumbnailId = "",
		category = "Nature",
		defaultUnlocked = false,
		unlockLevel = 11,
	},
	{
		id = "oil_painting",
		assetId = "",
		name = "Oil Painting",
		thumbnailId = "",
		category = "Art",
		defaultUnlocked = false,
		unlockLevel = 12,
	},
	{
		id = "ice_cream_sundae",
		assetId = "",
		name = "Ice Cream Sundae",
		thumbnailId = "",
		category = "Food",
		defaultUnlocked = false,
		unlockLevel = 13,
	},
	{
		id = "london_bridge",
		assetId = "",
		name = "London Bridge",
		thumbnailId = "",
		category = "Urban",
		defaultUnlocked = false,
		unlockLevel = 14,
	},
	{
		id = "wolf_howl",
		assetId = "",
		name = "Wolf Howl",
		thumbnailId = "",
		category = "Animals",
		defaultUnlocked = false,
		unlockLevel = 15,
	},
	{
		id = "saturn_rings",
		assetId = "",
		name = "Saturn Rings",
		thumbnailId = "",
		category = "Space",
		defaultUnlocked = false,
		unlockLevel = 16,
	},
	{
		id = "snowy_cabin",
		assetId = "",
		name = "Snowy Cabin",
		thumbnailId = "",
		category = "Nature",
		defaultUnlocked = false,
		unlockLevel = 17,
	},
	{
		id = "pixel_art",
		assetId = "",
		name = "Pixel Art",
		thumbnailId = "",
		category = "Art",
		defaultUnlocked = false,
		unlockLevel = 19,
	},
	{
		id = "pancake_stack",
		assetId = "",
		name = "Pancake Stack",
		thumbnailId = "",
		category = "Food",
		defaultUnlocked = false,
		unlockLevel = 20,
	},
	{
		id = "neon_alley",
		assetId = "",
		name = "Neon Alley",
		thumbnailId = "",
		category = "Urban",
		defaultUnlocked = false,
		unlockLevel = 22,
	},
	{
		id = "earth_from_space",
		assetId = "",
		name = "Earth from Space",
		thumbnailId = "",
		category = "Space",
		defaultUnlocked = false,
		unlockLevel = 25,
	},
}

local ImageCatalog = {}

function ImageCatalog.getAll(): { ImageEntry }
	return IMAGES
end

function ImageCatalog.getById(id: string): ImageEntry?
	for _, entry in IMAGES do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function ImageCatalog.getDefaultUnlocked(): { ImageEntry }
	local result = {}
	for _, entry in IMAGES do
		if entry.defaultUnlocked then
			table.insert(result, entry)
		end
	end
	return result
end

return ImageCatalog
