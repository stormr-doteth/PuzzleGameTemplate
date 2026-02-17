local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)

export type ImagePickerProps = {
	selectedImageId: string?,
	onSelectImage: (imageId: string, assetId: string) -> (),
	unlockedImages: { [string]: boolean }?,
	playerLevel: number?,
	personalBests: { [string]: number }?,
}

local DIFFICULTY_IDS = { "2x2", "6x6", "9x9", "15x15", "25x25" }

local function ImagePicker(props: ImagePickerProps)
	local allImages = ImageCatalog.getAll()
	local unlockedImages = props.unlockedImages
	local playerLevel = props.playerLevel or 1

	local children: { [string]: any } = {}

	children["GridLayout"] = React.createElement("UIGridLayout", {
		CellSize = UDim2.new(0, 90, 0, 90),
		CellPadding = UDim2.new(0, 8, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	children["Padding"] = React.createElement("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	})

	for i, entry in allImages do
		local isSelected = entry.id == props.selectedImageId
		local isUnlocked = entry.defaultUnlocked

		if unlockedImages then
			isUnlocked = entry.defaultUnlocked or (unlockedImages[entry.id] == true)
		end

		local imageChildren: { [string]: any } = {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}

		if isSelected then
			imageChildren["Highlight"] = React.createElement("UIStroke", {
				Color = Color3.fromRGB(80, 200, 255),
				Thickness = 3,
			})
		end

		-- Star badge for completed images
		if isUnlocked and props.personalBests then
			local completedCount = 0
			for _, diffId in DIFFICULTY_IDS do
				local bestKey = entry.id .. "_" .. diffId
				if props.personalBests[bestKey] then
					completedCount += 1
				end
			end
			if completedCount > 0 then
				imageChildren["StarBadge"] = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -4, 1, -4),
					Size = UDim2.fromOffset(28, 16),
					BackgroundColor3 = Color3.fromRGB(255, 180, 30),
					ZIndex = 8,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Label = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "\u{2605}" .. completedCount,
						TextColor3 = Color3.fromRGB(40, 20, 0),
						TextSize = 11,
						Font = Enum.Font.GothamBold,
						ZIndex = 9,
					}),
				})
			end
		end

		-- Lock overlay for locked images
		if not isUnlocked then
			imageChildren["LockOverlay"] = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.35,
				ZIndex = 6,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				LockIcon = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(32, 32),
					BackgroundTransparency = 1,
					Text = "\u{1F512}",
					TextSize = 24,
					ZIndex = 7,
				}),
			})
		end

		children["Image_" .. i] = React.createElement("ImageButton", {
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(50, 50, 60),
			Image = entry.thumbnailId,
			ImageTransparency = if isUnlocked then 0 else 0.6,
			ScaleType = Enum.ScaleType.Crop,
			[React.Event.Activated] = function()
				props.onSelectImage(entry.id, entry.assetId)
			end,
		}, imageChildren)
	end

	-- Calculate canvas height: rows * (90 + 8 padding) + top/bottom padding
	local numColumns = 4
	local numRows = math.ceil(#allImages / numColumns)
	local canvasHeight = numRows * 98 + 24

	return React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, canvasHeight),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, children)
end

return ImagePicker
