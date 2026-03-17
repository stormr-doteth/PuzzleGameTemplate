local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)
local MonetizationConfig = require(Shared.MonetizationConfig)
local ProgressionConfig = require(Shared.ProgressionConfig)
local ImagePicker = require(script.Parent.ImagePicker)
local PackPicker = require(script.Parent.PackPicker)
local Theme = require(Shared.Theme)

local DIFFICULTIES = {
	{ label = "Beginner (2x2 - 4 pcs)", rows = 2, cols = 2, difficultyId = "2x2" },
	{ label = "Easy (6x6 - 36 pcs)", rows = 6, cols = 6, difficultyId = "6x6" },
	{ label = "Medium (9x9 - 81 pcs)", rows = 9, cols = 9, difficultyId = "9x9" },
	{ label = "Hard (15x15 - 225 pcs)", rows = 15, cols = 15, difficultyId = "15x15" },
	{ label = "Expert (25x25 - 625 pcs)", rows = 25, cols = 25, difficultyId = "25x25" },
}

export type RoomLobbyScreenProps = {
	roomInfo: any,
	isHost: boolean,
	onLeave: () -> (),
	onConfigure: (config: any) -> (),
	onStart: () -> (),
	unlockedImages: { [string]: boolean }?,
	personalBests: { [string]: number }?,
	cash: number?,
	onUnlockImage: ((imageId: string) -> ())?,
	onUnlockImageRobux: ((imageId: string) -> ())?,
	hasExpertPass: boolean?,
	onPromptExpertPass: (() -> ())?,
}

local PLAYER_COLORS = {
	Theme.Colors.player1,
	Theme.Colors.player2,
	Theme.Colors.player3,
	Theme.Colors.player4,
}

local function RoomLobbyScreen(props: RoomLobbyScreenProps)
	local roomInfo = props.roomInfo
	local selectedDifficulty, setSelectedDifficulty = React.useState(2) -- default Easy
	local selectedImageId, setSelectedImageId = React.useState(nil :: string?)
	local selectedImageAssetId, setSelectedImageAssetId = React.useState(nil :: string?)
	local selectedPackId, setSelectedPackId = React.useState(nil :: string?)

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	local function onSelectImage(imageId: string, assetId: string)
		setSelectedImageId(imageId)
		setSelectedImageAssetId(assetId)
		-- Auto-configure when host picks image
		if props.isHost then
			local diff = DIFFICULTIES[selectedDifficulty]
			props.onConfigure({
				imageAssetId = assetId,
				imageId = imageId,
				difficultyId = diff.difficultyId,
				rows = diff.rows,
				cols = diff.cols,
			})
		end
	end

	local function onSelectDifficulty(idx: number)
		setSelectedDifficulty(idx)
		if props.isHost and selectedImageId and selectedImageAssetId then
			local diff = DIFFICULTIES[idx]
			props.onConfigure({
				imageAssetId = selectedImageAssetId,
				imageId = selectedImageId,
				difficultyId = diff.difficultyId,
				rows = diff.rows,
				cols = diff.cols,
			})
		end
	end

	local players = roomInfo and roomInfo.players or {}
	local maxPlayers = roomInfo and roomInfo.maxPlayers or 4
	local currentConfig = roomInfo and roomInfo.config

	-- === Top Bar: Title + Leave Button ===
	local topBar = React.createElement("Frame", {
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.1, 0),
		}),
		Title = React.createElement("TextLabel", {
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.4, 1),
			BackgroundTransparency = 1,
			Text = "Puzzle Table",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.heading,
			Font = Theme.Font.bold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
		}),
		PlayerCount = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.2, 0.6),
			BackgroundTransparency = 1,
			Text = "Players " .. #players .. "/" .. maxPlayers,
			TextColor3 = Theme.Colors.textMuted,
			TextSize = Theme.TextSize.label,
			Font = Theme.Font.medium,
			TextScaled = true,
		}),
		LeaveButton = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromScale(0.15, 0.7),
			BackgroundColor3 = Theme.Colors.dangerDark,
			Text = "Leave",
			TextColor3 = Color3.fromRGB(255, 220, 220),
			TextSize = Theme.TextSize.label,
			Font = Theme.Font.medium,
			TextScaled = true,
			[React.Event.Activated] = function()
				props.onLeave()
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			TextPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
			}),
		}),
	})

	-- === Player Strip: Compact horizontal player badges ===
	local playerBadgeChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.01, 0),
		}),
	}

	for i = 1, maxPlayers do
		local p = players[i]
		local color = PLAYER_COLORS[((i - 1) % #PLAYER_COLORS) + 1]

		if p then
			local nameText = p.displayName
			if p.isHost then
				nameText = nameText .. " (Host)"
			end
			if p.userId == localUserId then
				nameText = nameText .. " (You)"
			end

			playerBadgeChildren["P" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromScale(0.96 / maxPlayers, 0.8),
				BackgroundColor3 = Theme.Colors.bgCard,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				ColorBar = React.createElement("Frame", {
					Size = UDim2.new(0, 4, 0.7, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 4, 0.5, 0),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
				}),
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, 14, 0, 0),
					Size = UDim2.new(1, -18, 1, 0),
					BackgroundTransparency = 1,
					Text = nameText,
					TextColor3 = Theme.Colors.textSecondary,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),
			})
		else
			playerBadgeChildren["P" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromScale(0.96 / maxPlayers, 0.8),
				BackgroundColor3 = Theme.Colors.bgDark,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Label = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "Waiting...",
					TextColor3 = Theme.Colors.scrollbar,
					TextSize = Theme.TextSize.tiny,
					Font = Theme.Font.regular,
					TextScaled = true,
				}, {
					TextPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0.1, 0),
						PaddingRight = UDim.new(0.1, 0),
					}),
				}),
			})
		end
	end

	local playerStrip = React.createElement("Frame", {
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
		Badges = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, playerBadgeChildren),
	})

	-- === Content Area: Pack/Image picker or non-host view ===
	local contentTop = 0.22 -- after top bar (12%) + player strip (10%)
	local contentHeight = 0.78 -- remaining space

	local contentChildren: { [string]: any } = {}

	if props.isHost then
		if selectedPackId then
			-- === Selection Panel (right side, matching MenuScreen) ===
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
					PreviewImage = React.createElement("ImageLabel", {
						Size = UDim2.fromScale(0.3, 1),
						BackgroundColor3 = Theme.Colors.bgElevated,
						Image = selectedEntry.thumbnailId,
						ScaleType = Enum.ScaleType.Crop,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
						AspectRatio = React.createElement("UIAspectRatioConstraint", {
							AspectRatio = 1,
							AspectType = Enum.AspectType.ScaleWithParentSize,
							DominantAxis = Enum.DominantAxis.Height,
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

				-- Difficulty buttons with coin rewards
				local personalBests = props.personalBests
				for i, diff in DIFFICULTIES do
					local isSelected = i == selectedDifficulty
					local coinReward = ProgressionConfig.COIN_REWARDS_BY_DIFFICULTY[diff.difficultyId] or 0
					local hasCompleted = selectedImageId and personalBests and personalBests[selectedImageId .. "_" .. diff.difficultyId] ~= nil
					local buttonText = if hasCompleted then diff.label .. " \u{2713}" else diff.label
					local textColor = if hasCompleted then Theme.Colors.warning else Theme.Colors.textPrimary
					local isExpert = diff.difficultyId == "25x25"
					local expertLocked = isExpert and not props.hasExpertPass

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
								onSelectDifficulty(i)
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

				-- Start button
				panelChildren["StartButton"] = React.createElement("TextButton", {
					LayoutOrder = 11,
					Size = UDim2.fromScale(1, 0.12),
					BackgroundColor3 = if currentConfig
						then Theme.Colors.success
						else Theme.Colors.border,
					Text = "Start Puzzle",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
					TextScaled = true,
					[React.Event.Activated] = function()
						if currentConfig then
							props.onStart()
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				})
			else
				-- Locked image: show unlock options
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

				if not canAfford then
					panelChildren["CantAffordHint"] = React.createElement("TextLabel", {
						LayoutOrder = 7,
						Size = UDim2.fromScale(1, 0.06),
						BackgroundTransparency = 1,
						Text = "Not enough coins - complete puzzles to earn more!",
						TextColor3 = Theme.Colors.textMuted,
						TextSize = Theme.TextSize.small,
						Font = Theme.Font.regular,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextScaled = true,
					})
				end
			end

			local selectionPanel = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.38, 1),
				BackgroundColor3 = Theme.Colors.bgCard,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, panelChildren)

			-- Left 60% image grid + right 38% selection panel
			contentChildren["ImageGrid"] = React.createElement("Frame", {
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
					end,
				}),
			})
			contentChildren["SelectionPanel"] = selectionPanel
		else
			-- Show pack picker (full width)
			contentChildren["Picker"] = React.createElement(PackPicker, {
				onSelectPack = function(packId: string)
					setSelectedPackId(packId)
					setSelectedImageId(nil)
					setSelectedImageAssetId(nil)
				end,
				unlockedImages = props.unlockedImages,
			})
		end
	else
		-- Non-host view: show config or waiting message
		if currentConfig then
			local imageEntry = ImageCatalog.getById(currentConfig.imageId)
			local imageName = if imageEntry then imageEntry.name else currentConfig.imageId
			contentChildren["ConfigInfo"] = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.6, 0.4),
				BackgroundColor3 = Theme.Colors.bgCard,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0.05, 0),
					PaddingTop = UDim.new(0.1, 0),
				}),
				ImageLabel = React.createElement("TextLabel", {
					Size = UDim2.fromScale(0.9, 0.35),
					BackgroundTransparency = 1,
					Text = "Image: " .. imageName,
					TextColor3 = Theme.Colors.textSecondary,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),
				DiffLabel = React.createElement("TextLabel", {
					Position = UDim2.fromScale(0, 0.4),
					Size = UDim2.fromScale(0.9, 0.35),
					BackgroundTransparency = 1,
					Text = "Difficulty: " .. currentConfig.difficultyId,
					TextColor3 = Theme.Colors.textSecondary,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),
			})
		else
			contentChildren["WaitingLabel"] = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.3),
				BackgroundTransparency = 1,
				Text = "Waiting for host to select a puzzle...",
				TextColor3 = Theme.Colors.textDisabled,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.regular,
				TextScaled = true,
			})
		end
	end

	local contentArea = React.createElement("Frame", {
		Position = UDim2.fromScale(0, contentTop),
		Size = UDim2.new(1, 0, contentHeight, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, contentChildren)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Background = React.createElement("Frame", {
			Size = UDim2.fromScale(2, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = 0,
		}),
		TopBar = topBar,
		PlayerStrip = playerStrip,
		ContentArea = contentArea,
	})
end

return RoomLobbyScreen
