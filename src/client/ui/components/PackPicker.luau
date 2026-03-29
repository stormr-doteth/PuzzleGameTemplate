local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzlePacks = require(Shared.PuzzlePacks)
local ImageCatalog = require(Shared.ImageCatalog)
local FavoriteRewardConfig = require(Shared.FavoriteRewardConfig)
local Theme = require(Shared.Theme)

export type PackPickerProps = {
	onSelectPack: (packId: string) -> (),
	unlockedImages: { [string]: boolean }?,
	onClaimFavoriteReward: (() -> ())?,
	hasClaimedFavoriteReward: boolean?,
}

-- Only these 4 packs are shown on the main screen
local DISPLAY_PACKS = { "landscapes", "animals", "seals", "brainrots" }

local function PackPicker(props: PackPickerProps)
	local topRowCards: { [string]: any } = {}
	local bottomRowCards: { [string]: any } = {}

	topRowCards["ListLayout"] = React.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.015, 0),
	})

	bottomRowCards["ListLayout"] = React.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.015, 0),
	})

	for i, packId in DISPLAY_PACKS do
		local pack = PuzzlePacks.getById(packId)
		if not pack then
			continue
		end

		local packImages = ImageCatalog.getByPackId(packId)
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
						NumberSequenceKeypoint.new(0, 0.3),
						NumberSequenceKeypoint.new(1, 0.3),
					}),
					Rotation = 90,
				}),
			}),

			-- Pack name (top-center, large)
			Name = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.5),
				BackgroundTransparency = 1,
				Text = pack.name,
				TextColor3 = Theme.Colors.textPrimary,
				Font = Theme.Font.heading,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextScaled = true,
				ZIndex = 3,
			}, {
				TextStroke = React.createElement("UIStroke", {
					Color = Theme.Colors.black,
					Thickness = 2,
				}),
			}),

			-- Card border stroke
			Stroke = React.createElement("UIStroke", {
				Color = Theme.Colors.border,
				Thickness = 2,
			}),
		}

		local card = React.createElement("TextButton", {
			LayoutOrder = if i <= 3 then i else i - 3,
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Colors.bgMedium,
			Text = "",
			AutoButtonColor = true,
			ClipsDescendants = true,
			[React.Event.Activated] = function()
				props.onSelectPack(packId)
			end,
		}, cardChildren)

		if i <= 3 then
			topRowCards["Pack_" .. packId] = card
		else
			bottomRowCards["Pack_" .. packId] = card
		end
	end

	-- Favorite reward card ("Like to Unlock" free space pack)
	do
		local rewardPackId = FavoriteRewardConfig.REWARD_PACK_ID
		local rewardPack = PuzzlePacks.getById(rewardPackId)
		local claimed = props.hasClaimedFavoriteReward == true

		if rewardPack then
			local packImages = ImageCatalog.getByPackId(rewardPackId)
			local bgAssetId = ""
			for _, img in packImages do
				if img.assetId ~= "" then
					bgAssetId = img.assetId
					break
				end
			end

			local favoriteCardChildren: { [string]: any } = {
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

				-- Dark gradient overlay
				GradientOverlay = React.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.black,
					BackgroundTransparency = 0.3,
					ZIndex = 2,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
					Gradient = React.createElement("UIGradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.3),
							NumberSequenceKeypoint.new(1, 0.3),
						}),
						Rotation = 90,
					}),
				}),

				-- Pack name (center)
				Name = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.3),
					BackgroundTransparency = 1,
					Text = rewardPack.name,
					TextColor3 = Theme.Colors.textPrimary,
					Font = Theme.Font.heading,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextScaled = true,
					ZIndex = 3,
				}, {
					TextStroke = React.createElement("UIStroke", {
						Color = Theme.Colors.black,
						Thickness = 2,
					}),
				}),
			}

			if claimed then
				-- Claimed: normal style with green checkmark badge
				favoriteCardChildren["Stroke"] = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 2,
				})

				favoriteCardChildren["Badge"] = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.04),
					Size = UDim2.fromScale(0.5, 0.14),
					BackgroundColor3 = Theme.Colors.success,
					ZIndex = 4,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Label = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "\u{2713} Unlocked",
						TextColor3 = Theme.Colors.textPrimary,
						Font = Theme.Font.bold,
						TextScaled = true,
						ZIndex = 4,
					}),
				})
			else
				-- Unclaimed: gold border, FREE badge, "Favorite to Unlock!" subtitle
				favoriteCardChildren["Stroke"] = React.createElement("UIStroke", {
					Color = Theme.Colors.gold,
					Thickness = 3,
				})

				favoriteCardChildren["Badge"] = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.04),
					Size = UDim2.fromScale(0.45, 0.14),
					BackgroundColor3 = Theme.Colors.gold,
					ZIndex = 4,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Label = React.createElement("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "\u{1F512} LOCKED",
						TextColor3 = Theme.Colors.textPrimary,
						Font = Theme.Font.bold,
						TextScaled = true,
						ZIndex = 4,
					}),
				})

				favoriteCardChildren["Subtitle"] = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.fromScale(0.5, 0.92),
					Size = UDim2.fromScale(0.9, 0.15),
					BackgroundTransparency = 1,
					Text = "Like & Favorite to unlock!",
					TextColor3 = Theme.Colors.gold,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextScaled = true,
					ZIndex = 3,
				}, {
					TextStroke = React.createElement("UIStroke", {
						Color = Theme.Colors.black,
						Thickness = 2,
					}),
				})
			end

			bottomRowCards["Pack_favorite"] = React.createElement("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Colors.bgMedium,
				Text = "",
				AutoButtonColor = true,
				ClipsDescendants = true,
				[React.Event.Activated] = function()
					if claimed then
						props.onSelectPack(rewardPackId)
					else
						if props.onClaimFavoriteReward then
							props.onClaimFavoriteReward()
						end
					end
				end,
			}, favoriteCardChildren)
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(0.95, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.06, 0),
		}),
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0.01, 0),
		}),

		-- Header
		Header = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.08),
			BackgroundTransparency = 1,
			Text = "Select a puzzle pack!",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.title,
			Font = Theme.Font.heading,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Top row: 3 cards (landscapes, animals, seals)
		TopRow = React.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.95, 0.44),
			BackgroundTransparency = 1,
		}, topRowCards),

		-- Bottom row: 2 cards (brainrots, favorite)
		BottomRow = React.createElement("Frame", {
			LayoutOrder = 3,
			Size = UDim2.fromScale(0.95, 0.44),
			BackgroundTransparency = 1,
		}, bottomRowCards),
	})
end

return PackPicker
