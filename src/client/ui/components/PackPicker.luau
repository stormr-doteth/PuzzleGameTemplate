local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzlePacks = require(Shared.PuzzlePacks)
local ImageCatalog = require(Shared.ImageCatalog)

export type PackPickerProps = {
	onSelectPack: (packId: string) -> (),
	unlockedImages: { [string]: boolean }?,
}

-- Colors for pack cards when no icon is set
local PACK_COLORS = {
	landscapes = Color3.fromRGB(60, 140, 80),
	brain = Color3.fromRGB(160, 80, 180),
	rot = Color3.fromRGB(100, 70, 50),
	animals = Color3.fromRGB(200, 140, 60),
	space = Color3.fromRGB(40, 50, 120),
	urban = Color3.fromRGB(100, 100, 120),
	food = Color3.fromRGB(200, 80, 60),
	art = Color3.fromRGB(180, 60, 120),
}

-- Emoji-style text icons as fallback when no iconAssetId is set
local PACK_ICONS = {
	landscapes = "\u{1F3DE}",
	brain = "\u{1F9E0}",
	rot = "\u{1F480}",
	animals = "\u{1F43E}",
	space = "\u{1F680}",
	urban = "\u{1F3D9}",
	food = "\u{1F354}",
	art = "\u{1F3A8}",
}

local function PackPicker(props: PackPickerProps)
	local allPacks = PuzzlePacks.getAll()
	local children: { [string]: any } = {}

	children["GridLayout"] = React.createElement("UIGridLayout", {
		CellSize = UDim2.new(0, 160, 0, 180),
		CellPadding = UDim2.new(0, 16, 0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	children["Padding"] = React.createElement("UIPadding", {
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
	})

	for i, pack in allPacks do
		local packImages = ImageCatalog.getByPackId(pack.id)
		local totalCount = #packImages
		local unlockedCount = 0
		for _, img in packImages do
			local isUnlocked = img.defaultUnlocked
			if props.unlockedImages then
				isUnlocked = img.defaultUnlocked or (props.unlockedImages[img.id] == true)
			end
			if isUnlocked then
				unlockedCount += 1
			end
		end

		local bgColor = PACK_COLORS[pack.id] or Color3.fromRGB(60, 60, 80)
		local iconText = PACK_ICONS[pack.id] or "\u{2753}"
		local hasIcon = pack.iconAssetId ~= ""

		local cardChildren: { [string]: any } = {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
		}

		-- Pack icon (image or emoji fallback)
		if hasIcon then
			cardChildren["Icon"] = React.createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(80, 80),
				BackgroundTransparency = 1,
				Image = pack.iconAssetId,
				ScaleType = Enum.ScaleType.Fit,
			})
		else
			cardChildren["IconText"] = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				Size = UDim2.fromOffset(80, 80),
				BackgroundTransparency = 1,
				Text = iconText,
				TextSize = 48,
			})
		end

		-- Pack name
		cardChildren["Name"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.new(1, -16, 0, 24),
			BackgroundTransparency = 1,
			Text = pack.name,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 17,
			Font = Enum.Font.GothamBold,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		-- Puzzle count
		cardChildren["Count"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 126),
			Size = UDim2.new(1, -16, 0, 18),
			BackgroundTransparency = 1,
			Text = unlockedCount .. " / " .. totalCount .. " puzzles",
			TextColor3 = Color3.fromRGB(200, 200, 220),
			TextSize = 13,
			Font = Enum.Font.Gotham,
		})

		-- Progress bar
		local progress = if totalCount > 0 then unlockedCount / totalCount else 0
		cardChildren["ProgressBar"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 150),
			Size = UDim2.new(1, -24, 0, 6),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
			Fill = React.createElement("Frame", {
				Size = UDim2.fromScale(progress, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
			}),
		})

		-- Skip rendering packs with no images
		if totalCount > 0 then
			children["Pack_" .. i] = React.createElement("TextButton", {
				LayoutOrder = pack.sortOrder,
				BackgroundColor3 = bgColor,
				Text = "",
				AutoButtonColor = true,
				[React.Event.Activated] = function()
					props.onSelectPack(pack.id)
				end,
			}, cardChildren)
		end
	end

	return React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, children)
end

return PackPicker
