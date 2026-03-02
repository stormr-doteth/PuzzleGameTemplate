local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzlePacks = require(Shared.PuzzlePacks)
local ImageCatalog = require(Shared.ImageCatalog)
local Theme = require(Shared.Theme)

export type PackPickerProps = {
	onSelectPack: (packId: string) -> (),
	unlockedImages: { [string]: boolean }?,
}

-- Only these 3 packs are shown on the main screen
local DISPLAY_PACKS = { "animals", "seals", "brainrots" }

local function PackPicker(props: PackPickerProps)
	local cardRow: { [string]: any } = {}

	cardRow["ListLayout"] = React.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.02, 0),
	})

	for i, packId in DISPLAY_PACKS do
		local pack = PuzzlePacks.getById(packId)
		if not pack then
			continue
		end

		local packImages = ImageCatalog.getByPackId(packId)
		local totalCount = #packImages

		-- Find first valid image for background
		local bgAssetId = ""
		for _, img in packImages do
			if img.assetId ~= "" then
				bgAssetId = img.assetId
				break
			end
		end

		local cardChildren: { [string]: any } = {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Height,
			}),

			-- Background image
			BackgroundImage = React.createElement("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = bgAssetId,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 1,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			}),

			-- Dark gradient overlay for text readability
			GradientOverlay = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.black,
				BackgroundTransparency = 0.3,
				ZIndex = 2,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
				Gradient = React.createElement("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.8),
						NumberSequenceKeypoint.new(0.6, 0.5),
						NumberSequenceKeypoint.new(1, 0.1),
					}),
					Rotation = 90,
				}),
			}),

			-- Pack name (bottom-left area)
			Name = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0.06, 0, 1, -30),
				Size = UDim2.new(0.88, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = pack.name,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				ZIndex = 3,
			}),

			-- Puzzle count subtitle
			Count = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0.06, 0, 1, -10),
				Size = UDim2.new(0.88, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = totalCount .. " puzzles",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
		}

		cardRow["Pack_" .. packId] = React.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.fromScale(0, 0.85),
			BackgroundColor3 = Theme.Colors.bgMedium,
			Text = "",
			AutoButtonColor = true,
			ClipsDescendants = true,
			[React.Event.Activated] = function()
				props.onSelectPack(packId)
			end,
		}, cardChildren)
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(0.75, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		AspectRatio = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1.6,
			DominantAxis = Enum.DominantAxis.Width,
		}),
		-- Header
		Header = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.fromScale(1, 0.15),
			BackgroundTransparency = 1,
			Text = "Select a puzzle pack!",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.title,
			Font = Theme.Font.bold,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Card row centered in the middle of the screen
		CardRow = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.95, 0.75),
			BackgroundTransparency = 1,
		}, cardRow),
	})
end

return PackPicker
