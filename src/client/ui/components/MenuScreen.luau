local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)
local MonetizationConfig = require(Shared.MonetizationConfig)
local ProgressionConfig = require(Shared.ProgressionConfig)
local ImagePicker = require(script.Parent.ImagePicker)

local PackPicker = require(script.Parent.PackPicker)
local DailyPuzzleCard = require(script.Parent.DailyPuzzleCard)
local Theme = require(Shared.Theme)
export type MenuScreenProps = {
	onStart: (rows: number, cols: number, imageAssetId: string, imageId: string, difficultyId: string) -> (),
	unlockedImages: { [string]: boolean }?,
	personalBests: { [string]: number }?,
	savedPuzzles: { any }?,
	onResume: ((slotIndex: number) -> ())?,
	onDeleteSave: ((slotIndex: number) -> ())?,
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
	cash: number?,
	hasExpertPass: boolean?,
	onUnlockImage: ((imageId: string) -> ())?,
	onUnlockImageRobux: ((imageId: string) -> ())?,
	onPromptExpertPass: (() -> ())?,
	dailyPuzzle: any?,
	dailyPuzzleCompleted: boolean?,
	onClaimFavoriteReward: (() -> ())?,
	hasClaimedFavoriteReward: boolean?,
}

local DIFFICULTIES = {
	{ label = "Beginner (2x2 - 4 pcs)", rows = 2, cols = 2, difficultyId = "2x2" },
	{ label = "Easy (6x6 - 36 pcs)", rows = 6, cols = 6, difficultyId = "6x6" },
	{ label = "Medium (9x9 - 81 pcs)", rows = 9, cols = 9, difficultyId = "9x9" },
	{ label = "Hard (15x15 - 225 pcs)", rows = 15, cols = 15, difficultyId = "15x15" },
	{ label = "Expert (25x25 - 625 pcs)", rows = 25, cols = 25, difficultyId = "25x25" },
}

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function getFirstUnlockedImage(unlockedImages: { [string]: boolean }?)
	local allImages = ImageCatalog.getAll()
	for _, entry in allImages do
		if entry.defaultUnlocked or (unlockedImages and unlockedImages[entry.id]) then
			return entry
		end
	end
	-- Fallback: return the very first catalog entry
	return allImages[1]
end

local function MenuScreen(props: MenuScreenProps)
	local firstImage = getFirstUnlockedImage(props.unlockedImages)
	local selectedDifficulty, setSelectedDifficulty = React.useState(3) -- default Medium (4x4)
	local selectedImageId, setSelectedImageId = React.useState(firstImage and firstImage.id or nil :: string?)
	local selectedImageAssetId, setSelectedImageAssetId = React.useState(firstImage and firstImage.assetId or nil :: string?)
	local selectedPackId, setSelectedPackId = React.useState(nil :: string?)
	local showLeaderboards, setShowLeaderboards = React.useState(false)
	local showShop, setShowShop = React.useState(false)
	local showRobuxShop, setShowRobuxShop = React.useState(false)
	local showStats, setShowStats = React.useState(false)
	local showSavedPuzzles, setShowSavedPuzzles = React.useState(false)
	local warningText, setWarningText = React.useState("")
	local showImagePreview, setShowImagePreview = React.useState(false)

	local function onSelectImage(imageId: string, assetId: string)
		setSelectedImageId(imageId)
		setSelectedImageAssetId(assetId)
		setWarningText("")
	end

	local savedPuzzles = props.savedPuzzles
	local hasSaves = savedPuzzles and #savedPuzzles > 0

	-- === Selection Panel (right side, non-scrolling, scale-based) ===
	local selectionPanel = nil
	do
		local selectedEntry = ImageCatalog.getById(selectedImageId)
		local panelChildren: { [string]: any } = {}

		panelChildren["Layout"] = React.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.01, 0),
		})

		panelChildren["Padding"] = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
		})

		-- Compact preview row: small image + name side by side
		if selectedEntry then
			panelChildren["PreviewRow"] = React.createElement("Frame", {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.18),
				BackgroundTransparency = 1,
			}, {
				PreviewImage = React.createElement("ImageButton", {
					Size = UDim2.fromScale(0.3, 1),
					BackgroundColor3 = Theme.Colors.bgElevated,
					Image = selectedEntry.thumbnailId,
					ScaleType = Enum.ScaleType.Crop,
					[React.Event.Activated] = function()
						setShowImagePreview(true)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
						AspectType = Enum.AspectType.ScaleWithParentSize,
						DominantAxis = Enum.DominantAxis.Height,
					}),
					PreviewLabel = React.createElement("Frame", {
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.fromScale(1, 0.25),
						BackgroundColor3 = Theme.Colors.black,
						BackgroundTransparency = 0.4,
						ZIndex = 2,
					}, {
						LabelCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						LabelText = React.createElement("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "Preview",
							TextColor3 = Theme.Colors.textPrimary,
							TextSize = Theme.TextSize.tiny,
							Font = Theme.Font.bold,
							TextScaled = true,
							ZIndex = 2,
						}),
					}),
				}),
				InfoFrame = React.createElement("Frame", {
					Position = UDim2.fromScale(0.35, 0),
					Size = UDim2.fromScale(0.65, 1),
					BackgroundTransparency = 1,
				}, {
					Name = React.createElement("TextLabel", {
						Position = UDim2.fromScale(0, 0.1),
						Size = UDim2.fromScale(1, 0.5),
						BackgroundTransparency = 1,
						Text = selectedEntry.name,
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.large,
						Font = Theme.Font.bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,
					}),
					Category = React.createElement("TextLabel", {
						Position = UDim2.fromScale(0, 0.55),
						Size = UDim2.fromScale(1, 0.35),
						BackgroundTransparency = 1,
						Text = selectedEntry.category,
						TextColor3 = Theme.Colors.textMuted,
						TextSize = Theme.TextSize.label,
						Font = Theme.Font.regular,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,
					}),
				}),
			})
		end

		-- Check if the selected image is unlocked
		local isSelectedUnlocked = selectedEntry and (selectedEntry.defaultUnlocked or (props.unlockedImages and props.unlockedImages[selectedEntry.id] == true))

		if isSelectedUnlocked then
			-- "Select Difficulty" label
			panelChildren["DiffLabel"] = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.05),
				BackgroundTransparency = 1,
				Text = "Select Difficulty",
				TextColor3 = Theme.Colors.textMuted,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
			})

			-- Difficulty buttons
			local personalBests = props.personalBests
			for i, diff in DIFFICULTIES do
				local isSelected = i == selectedDifficulty
				local hasCompleted = selectedImageId and personalBests and personalBests[selectedImageId .. "_" .. diff.difficultyId] ~= nil
				local buttonText = if hasCompleted then diff.label .. " \u{2713}" else diff.label
				local textColor = if hasCompleted then Theme.Colors.warning else Theme.Colors.textPrimary
				local isExpert = diff.difficultyId == "25x25"
				local expertLocked = isExpert and not props.hasExpertPass

				local coinReward = ProgressionConfig.COIN_REWARDS_BY_DIFFICULTY[diff.difficultyId] or 0

				if expertLocked then
					panelChildren["Diff_" .. i] = React.createElement("TextButton", {
						LayoutOrder = 3 + i,
						Size = UDim2.fromScale(1, 0.09),
						BackgroundColor3 = Theme.Colors.bgElevated,
						Text = "",
						[React.Event.Activated] = function()
							if props.onPromptExpertPass then
								props.onPromptExpertPass()
							end
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						Label = React.createElement("TextLabel", {
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "\u{1F512} Expert Pass Required",
							TextColor3 = Theme.Colors.textDisabled,
							TextSize = Theme.TextSize.body,
							Font = Theme.Font.medium,
							TextScaled = true,
						}),
					})
				else
					panelChildren["Diff_" .. i] = React.createElement("TextButton", {
						LayoutOrder = 3 + i,
						Size = UDim2.fromScale(1, 0.09),
						BackgroundColor3 = if isSelected
							then Theme.Colors.accentBlue
							else Theme.Colors.bgInput,
						Text = "",
						[React.Event.Activated] = function()
							setSelectedDifficulty(i)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						Label = React.createElement("TextLabel", {
							Position = UDim2.fromScale(0.04, 0),
							Size = UDim2.fromScale(0.7, 1),
							BackgroundTransparency = 1,
							Text = buttonText,
							TextColor3 = textColor,
							TextSize = Theme.TextSize.body,
							Font = Theme.Font.medium,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextScaled = true,
						}),
						CoinReward = React.createElement("TextLabel", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(0.96, 0.5),
							Size = UDim2.fromScale(0.22, 0.7),
							BackgroundTransparency = 1,
							Text = "+$" .. coinReward,
							TextColor3 = Theme.Colors.cashGreen,
							TextSize = Theme.TextSize.small,
							Font = Theme.Font.bold,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextScaled = true,
						}),
					})
				end
			end

			-- Personal best
			local diff = DIFFICULTIES[selectedDifficulty]
			if selectedImageId and diff then
				local bestKey = selectedImageId .. "_" .. diff.difficultyId
				local bestTime = if personalBests then personalBests[bestKey] else nil

				if bestTime then
					panelChildren["PersonalBest"] = React.createElement("TextLabel", {
						LayoutOrder = 10,
						Size = UDim2.fromScale(1, 0.06),
						BackgroundTransparency = 1,
						Text = "Personal Best: " .. formatTime(bestTime),
						TextColor3 = Theme.Colors.warning,
						TextSize = Theme.TextSize.body,
						Font = Theme.Font.medium,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextScaled = true,
					})
				end
			end

			-- Start button
			panelChildren["StartButton"] = React.createElement("TextButton", {
				LayoutOrder = 11,
				Size = UDim2.fromScale(1, 0.12),
				BackgroundColor3 = Theme.Colors.success,
				Text = "Start Puzzle",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextScaled = true,
				[React.Event.Activated] = function()
					if selectedImageId and selectedImageAssetId and selectedImageAssetId ~= "" then
						local d = DIFFICULTIES[selectedDifficulty]
						props.onStart(d.rows, d.cols, selectedImageAssetId, selectedImageId, d.difficultyId)
					else
						setWarningText("Choose a puzzle first!")
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			})

			-- Warning text
			if warningText ~= "" then
				panelChildren["WarningText"] = React.createElement("TextLabel", {
					LayoutOrder = 12,
					Size = UDim2.fromScale(1, 0.06),
					BackgroundTransparency = 1,
					Text = warningText,
					TextColor3 = Theme.Colors.danger,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextScaled = true,
				})
			end
		else
			-- Locked image: show coin/Robux unlock options
			panelChildren["LockIcon"] = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.12),
				BackgroundTransparency = 1,
				Text = "\u{1F512}",
				TextSize = Theme.TextSize.title,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = true,
			})

			panelChildren["LockTitle"] = React.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0.08),
				BackgroundTransparency = 1,
				Text = "Locked Puzzle",
				TextColor3 = Theme.Colors.orange,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = true,
			})

			-- Price label
			local price = ProgressionConfig.COIN_UNLOCK_PRICE
			panelChildren["PriceLabel"] = React.createElement("TextLabel", {
				LayoutOrder = 5,
				Size = UDim2.fromScale(1, 0.08),
				BackgroundTransparency = 1,
				Text = "$" .. price,
				TextColor3 = Theme.Colors.cashGreen,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = true,
			})

			-- Unlock buttons row
			local playerCash = props.cash or 0
			local canAfford = playerCash >= price

			panelChildren["UnlockButtons"] = React.createElement("Frame", {
				LayoutOrder = 6,
				Size = UDim2.fromScale(1, 0.14),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0.02, 0),
				}),
				CoinBtn = React.createElement("TextButton", {
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.46, 0.85),
					BackgroundColor3 = if canAfford then Theme.Colors.success else Theme.Colors.bgElevated,
					Text = "Unlock ($" .. price .. ")",
					TextColor3 = if canAfford then Theme.Colors.textPrimary else Theme.Colors.textDisabled,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.bold,
					TextScaled = true,
					[React.Event.Activated] = function()
						if canAfford and selectedEntry and props.onUnlockImage then
							props.onUnlockImage(selectedEntry.id)
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.border,
					}),
					TextPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0.05, 0),
						PaddingRight = UDim.new(0.05, 0),
					}),
				}),
				RobuxBtn = React.createElement("TextButton", {
					LayoutOrder = 2,
					Size = UDim2.fromScale(0.46, 0.85),
					BackgroundColor3 = Theme.Colors.accentBlue,
					Text = "Unlock (R$" .. MonetizationConfig.DEV_PRODUCTS.UNLOCK_PUZZLE.robuxPrice .. ")",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.bold,
					TextScaled = true,
					[React.Event.Activated] = function()
						if selectedEntry and props.onUnlockImageRobux then
							props.onUnlockImageRobux(selectedEntry.id)
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.border,
					}),
					TextPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0.05, 0),
						PaddingRight = UDim.new(0.05, 0),
					}),
				}),
			})

			-- Not enough coins hint
			if not canAfford then
				panelChildren["NotEnoughHint"] = React.createElement("TextLabel", {
					LayoutOrder = 7,
					Size = UDim2.fromScale(1, 0.06),
					BackgroundTransparency = 1,
					Text = "Not enough coins",
					TextColor3 = Theme.Colors.danger,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextScaled = true,
				})
			end
		end

		selectionPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.38, 1),
			BackgroundColor3 = Theme.Colors.bgCard,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, panelChildren)
	end

	-- === Content Area (grid + panel) ===
	local topInset = GuiService:GetGuiInset().Y
	local contentArea
	if selectedPackId then
		-- Show images within the selected pack + selection panel
		contentArea = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			ImageGrid = React.createElement("Frame", {
				Size = UDim2.fromScale(0.6, 1),
				BackgroundTransparency = 1,
			}, {
				Picker = React.createElement(ImagePicker, {
					selectedImageId = selectedImageId,
					onSelectImage = onSelectImage,
					unlockedImages = props.unlockedImages,
					personalBests = props.personalBests,
					packId = selectedPackId,
					onBack = function()
						setSelectedPackId(nil)
						setSelectedImageId(nil)
						setSelectedImageAssetId(nil)
						setWarningText("")
					end,
				}),
			}),
			SelectionPanel = selectionPanel,
			ShopBtnImage = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(0.6, -8, 0, -topInset + 4),
				Size = UDim2.fromOffset(100, 36),
				BackgroundColor3 = Theme.Colors.accentBlue,
				Text = "Shop",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.bold,
				ZIndex = 10,
				[React.Event.Activated] = function()
					setShowShop(true)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 1.5,
				}),
			}),
		})
	else
		-- Show pack selector (no selection panel)
		contentArea = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			PackGrid = React.createElement(PackPicker, {
				onSelectPack = function(packId: string)
					setSelectedPackId(packId)
					setSelectedImageId(nil)
					setSelectedImageAssetId(nil)
					setWarningText("")
				end,
				unlockedImages = props.unlockedImages,
				onClaimFavoriteReward = props.onClaimFavoriteReward,
				hasClaimedFavoriteReward = props.hasClaimedFavoriteReward,
			}),
		})
	end

	-- === Assemble root ===
	local menuChildren: { [string]: any } = {}
	menuChildren["ContentArea"] = contentArea

	-- Daily Puzzle card (shown when on pack selection screen, above packs)
	if not selectedPackId and props.dailyPuzzle then
		menuChildren["DailyPuzzleCard"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -topInset + 44),
			Size = UDim2.new(0.35, 0, 0.12, 0),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, {
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(320, 80),
			}),
			Card = React.createElement(DailyPuzzleCard, {
				dailyPuzzle = props.dailyPuzzle,
				completed = props.dailyPuzzleCompleted == true,
				onStart = props.onStart,
			}),
		})
	end

	-- HUD icon buttons (left-aligned, only on pack selection screen)
	if not selectedPackId then
		menuChildren["HUDIconRow"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromScale(0.105, 0.7),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.01, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			ShopBtn = React.createElement("Frame", {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://135280767376471",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						setShowShop(true)
					end,
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.72, 0),
					Size = UDim2.new(1, 0, 0.25, 0),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			RobuxShopBtn = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://136485331602074",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						setShowRobuxShop(true)
					end,
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.72, 0),
					Size = UDim2.new(1, 0, 0.25, 0),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "R$ Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			LeaderBtn = React.createElement("Frame", {
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://87104752122465",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						setShowLeaderboards(true)
					end,
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.72, 0),
					Size = UDim2.new(1, 0, 0.25, 0),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Ranks",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			StatsBtn = React.createElement("Frame", {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://80087999124116",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						setShowStats(true)
					end,
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0.72, 0),
					Size = UDim2.new(1, 0, 0.25, 0),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Stats",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
		})

		if hasSaves then
			menuChildren["SavedPuzzlesBtn"] = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, -topInset + 4),
				Size = UDim2.fromOffset(160, 36),
				BackgroundColor3 = Theme.Colors.accentBlue,
				Text = "Saved Puzzles",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.bold,
				ZIndex = 10,
				[React.Event.Activated] = function()
					setShowSavedPuzzles(true)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 1.5,
				}),
			})
		end
	end

	menuChildren["Background"] = React.createElement("Frame", {
		Size = UDim2.fromScale(2, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.bgDark,
		ZIndex = 0,
	})

	local rootChildren: { [string]: any } = {}
	rootChildren["Menu"] = React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, menuChildren)

	-- Leaderboard overlay
	if showLeaderboards then
		local LeaderboardScreen = nil
		local ok = pcall(function()
			LeaderboardScreen = require(script.Parent.LeaderboardScreen)
		end)
		if ok and LeaderboardScreen then
			rootChildren["LeaderboardOverlay"] = React.createElement(LeaderboardScreen, {
				onClose = function()
					setShowLeaderboards(false)
				end,
			})
		else
			setShowLeaderboards(false)
		end
	end

	-- Shop overlay
	if showShop then
		local ShopScreen = nil
		local ok = pcall(function()
			ShopScreen = require(script.Parent.ShopScreen)
		end)
		if ok and ShopScreen then
			rootChildren["ShopOverlay"] = React.createElement(ShopScreen, {
				onClose = function()
					setShowShop(false)
				end,
				playerData = props.playerData,
				onEquip = props.onEquip,
			})
		else
			setShowShop(false)
		end
	end

	-- Robux Shop overlay
	if showRobuxShop then
		local RobuxShopScreen = nil
		local ok = pcall(function()
			RobuxShopScreen = require(script.Parent.RobuxShopScreen)
		end)
		if ok and RobuxShopScreen then
			rootChildren["RobuxShopOverlay"] = React.createElement(RobuxShopScreen, {
				onClose = function()
					setShowRobuxShop(false)
				end,
				playerData = props.playerData,
			})
		else
			setShowRobuxShop(false)
		end
	end

	-- Stats overlay
	if showStats then
		local StatsScreen = nil
		local ok = pcall(function()
			StatsScreen = require(script.Parent.StatsScreen)
		end)
		if ok and StatsScreen then
			rootChildren["StatsOverlay"] = React.createElement(StatsScreen, {
				onClose = function()
					setShowStats(false)
				end,
				playerData = props.playerData,
			})
		else
			setShowStats(false)
		end
	end

	-- Saved Puzzles modal overlay
	if showSavedPuzzles then
		local saveEntries: { [string]: any } = {}
		saveEntries["Layout"] = React.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.02, 0),
		})
		saveEntries["Padding"] = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
		})

		if savedPuzzles and #savedPuzzles > 0 then
			for i, save in savedPuzzles do
				local imageEntry = ImageCatalog.getById(save.imageId)
				local imageName = if imageEntry then imageEntry.name else save.imageId
				local timeStr = formatTime(save.elapsedSeconds or 0)
				local label = save.difficultyId .. " - " .. imageName .. " - " .. timeStr

				saveEntries["Save_" .. i] = React.createElement("Frame", {
					LayoutOrder = i,
					Size = UDim2.fromScale(1, 0.18),
					BackgroundColor3 = Theme.Colors.bgInput,
					BorderSizePixel = 0,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Label = React.createElement("TextLabel", {
						Position = UDim2.fromScale(0.03, 0.05),
						Size = UDim2.fromScale(0.94, 0.4),
						BackgroundTransparency = 1,
						Text = label,
						TextColor3 = Theme.Colors.textSecondary,
						TextSize = Theme.TextSize.body,
						Font = Theme.Font.medium,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					ResumeBtn = React.createElement("TextButton", {
						Position = UDim2.fromScale(0.03, 0.5),
						Size = UDim2.fromScale(0.35, 0.4),
						BackgroundColor3 = Theme.Colors.success,
						Text = "Resume",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = Theme.TextSize.body,
						Font = Theme.Font.medium,
						TextScaled = true,
						[React.Event.Activated] = function()
							if props.onResume then
								setShowSavedPuzzles(false)
								props.onResume(i)
							end
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),
					DeleteBtn = React.createElement("TextButton", {
						Position = UDim2.fromScale(0.4, 0.5),
						Size = UDim2.fromScale(0.25, 0.4),
						BackgroundColor3 = Theme.Colors.dangerDark,
						Text = "Delete",
						TextColor3 = Color3.fromRGB(255, 220, 220),
						TextSize = Theme.TextSize.body,
						Font = Theme.Font.medium,
						TextScaled = true,
						[React.Event.Activated] = function()
							if props.onDeleteSave then
								props.onDeleteSave(i)
							end
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),
				})
			end
		else
			saveEntries["Empty"] = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.12),
				BackgroundTransparency = 1,
				Text = "No saved puzzles",
				TextColor3 = Theme.Colors.textDisabled,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end

		rootChildren["SavedPuzzlesBackdrop"] = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = 10,
			[React.Event.Activated] = function()
				setShowSavedPuzzles(false)
			end,
		})
		rootChildren["SavedPuzzlesModal"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.32, 0.7),
			BackgroundColor3 = Theme.Colors.bgMedium,
			ZIndex = 11,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Title = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.04, 0.03),
				Size = UDim2.fromScale(0.7, 0.1),
				BackgroundTransparency = 1,
				Text = "Saved Puzzles",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				ZIndex = 11,
			}),
			CloseBtn = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(0.97, 0.02),
				Size = UDim2.fromScale(0.1, 0.1),
				BackgroundColor3 = Theme.Colors.border,
				Text = "X",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				TextScaled = true,
				ZIndex = 11,
				[React.Event.Activated] = function()
					setShowSavedPuzzles(false)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			SavesList = React.createElement("ScrollingFrame", {
				Position = UDim2.fromScale(0, 0.14),
				Size = UDim2.fromScale(1, 0.86),
				BackgroundTransparency = 1,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				ZIndex = 11,
			}, saveEntries),
		})
	end

	-- Image Preview modal overlay
	if showImagePreview then
		local previewEntry = ImageCatalog.getById(selectedImageId)
		if previewEntry then
			rootChildren["ImagePreviewBackdrop"] = React.createElement("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.black,
				BackgroundTransparency = Theme.Transparency.overlay,
				Text = "",
				ZIndex = Theme.ZIndex.modal,
				[React.Event.Activated] = function()
					setShowImagePreview(false)
				end,
			})
			rootChildren["ImagePreviewModal"] = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.85),
				BackgroundColor3 = Theme.Colors.bgCard,
				ZIndex = Theme.ZIndex.modal + 1,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, Theme.Radius.modal) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
				}),
				PreviewImage = React.createElement("ImageLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = previewEntry.assetId,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = Theme.ZIndex.modal + 1,
				}),
				CloseBtn = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 8, 0, -8),
					Size = UDim2.fromOffset(32, 32),
					BackgroundColor3 = Theme.Colors.closeRed,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.bold,
					ZIndex = Theme.ZIndex.modal + 2,
					[React.Event.Activated] = function()
						setShowImagePreview(false)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, rootChildren)
end

return MenuScreen
