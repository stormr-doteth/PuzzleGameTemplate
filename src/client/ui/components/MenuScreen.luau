local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)
local ImagePicker = require(script.Parent.ImagePicker)

export type MenuScreenProps = {
	onStart: (rows: number, cols: number, imageAssetId: string, imageId: string, difficultyId: string) -> (),
	unlockedImages: { [string]: boolean }?,
	playerLevel: number?,
	personalBests: { [string]: number }?,
	savedPuzzles: { any }?,
	onResume: ((slotIndex: number) -> ())?,
	onDeleteSave: ((slotIndex: number) -> ())?,
	playerData: any?,
	onEquip: ((itemId: string, category: string) -> ())?,
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
	local showLeaderboards, setShowLeaderboards = React.useState(false)
	local showShop, setShowShop = React.useState(false)
	local showStats, setShowStats = React.useState(false)

	local function onSelectImage(imageId: string, assetId: string)
		setSelectedImageId(imageId)
		setSelectedImageAssetId(assetId)
	end

	-- === Top Bar ===
	local topBar = React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
		Title = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0, 250, 1, 0),
			BackgroundTransparency = 1,
			Text = "Jigsaw Puzzle",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 32,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		NavButtons = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
			LeaderboardsBtn = React.createElement("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.new(0, 130, 0, 36),
				BackgroundColor3 = Color3.fromRGB(55, 55, 75),
				Text = "Leaderboards",
				TextColor3 = Color3.fromRGB(200, 200, 220),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				[React.Event.Activated] = function()
					setShowLeaderboards(true)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			ShopBtn = React.createElement("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(0, 80, 0, 36),
				BackgroundColor3 = Color3.fromRGB(55, 55, 75),
				Text = "Shop",
				TextColor3 = Color3.fromRGB(200, 200, 220),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				[React.Event.Activated] = function()
					setShowShop(true)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
			StatsBtn = React.createElement("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.new(0, 80, 0, 36),
				BackgroundColor3 = Color3.fromRGB(55, 55, 75),
				Text = "Stats",
				TextColor3 = Color3.fromRGB(200, 200, 220),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				[React.Event.Activated] = function()
					setShowStats(true)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),
	})

	-- === Saved Puzzles Banner ===
	local savedPuzzles = props.savedPuzzles
	local savedBanner = nil
	if savedPuzzles and #savedPuzzles > 0 then
		local saveCards: { [string]: any } = {}
		saveCards["Layout"] = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		})
		saveCards["Padding"] = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		})
		saveCards["SavedLabel"] = React.createElement("TextLabel", {
			LayoutOrder = 0,
			Size = UDim2.new(0, 110, 0, 20),
			BackgroundTransparency = 1,
			Text = "Saved Puzzles:",
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		for i, save in savedPuzzles do
			local imageEntry = ImageCatalog.getById(save.imageId)
			local imageName = if imageEntry then imageEntry.name else save.imageId
			local timeStr = formatTime(save.elapsedSeconds or 0)
			local label = save.difficultyId .. " " .. imageName .. " " .. timeStr

			saveCards["Save_" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(0, 260, 0, 46),
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Label = React.createElement("TextLabel", {
					Position = UDim2.new(0, 10, 0, 3),
					Size = UDim2.new(1, -20, 0, 18),
					BackgroundTransparency = 1,
					Text = label,
					TextColor3 = Color3.fromRGB(210, 210, 230),
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				ResumeBtn = React.createElement("TextButton", {
					Position = UDim2.new(0, 10, 0, 23),
					Size = UDim2.fromOffset(80, 20),
					BackgroundColor3 = Color3.fromRGB(50, 180, 80),
					Text = "Resume",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					[React.Event.Activated] = function()
						if props.onResume then
							props.onResume(i)
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
				DeleteBtn = React.createElement("TextButton", {
					Position = UDim2.new(0, 96, 0, 23),
					Size = UDim2.fromOffset(60, 20),
					BackgroundColor3 = Color3.fromRGB(140, 50, 50),
					Text = "Delete",
					TextColor3 = Color3.fromRGB(255, 220, 220),
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
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

		savedBanner = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 60),
			CanvasSize = UDim2.new(0, #savedPuzzles * 270 + 150, 0, 0),
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
			BackgroundColor3 = Color3.fromRGB(30, 30, 42),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			LayoutOrder = 2,
		}, saveCards)
	end

	-- === Selection Panel (right side) ===
	local selectionPanel = nil
	do
		local selectedEntry = ImageCatalog.getById(selectedImageId)
		local panelChildren: { [string]: any } = {}

		panelChildren["Layout"] = React.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		})

		panelChildren["Padding"] = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		})

		-- Large preview image
		if selectedEntry then
			panelChildren["Preview"] = React.createElement("ImageLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 220),
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
				Image = selectedEntry.thumbnailId,
				ScaleType = Enum.ScaleType.Crop,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			})

			-- Image name + category
			panelChildren["ImageInfo"] = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
			}, {
				Name = React.createElement("TextLabel", {
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					Text = selectedEntry.name,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Category = React.createElement("TextLabel", {
					Position = UDim2.fromOffset(0, 22),
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = selectedEntry.category,
					TextColor3 = Color3.fromRGB(160, 160, 180),
					TextSize = 14,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			})
		end

		-- Check if the selected image is unlocked
		local isSelectedUnlocked = selectedEntry and (selectedEntry.defaultUnlocked or (props.unlockedImages and props.unlockedImages[selectedEntry.id] == true))

		if isSelectedUnlocked then
			-- "Select Difficulty" label
			panelChildren["DiffLabel"] = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "Select Difficulty",
				TextColor3 = Color3.fromRGB(180, 180, 200),
				TextSize = 16,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			-- Difficulty buttons
			local personalBests = props.personalBests
			for i, diff in DIFFICULTIES do
				local isSelected = i == selectedDifficulty
				local hasCompleted = selectedImageId and personalBests and personalBests[selectedImageId .. "_" .. diff.difficultyId] ~= nil
				local buttonText = if hasCompleted then diff.label .. " \u{2713}" else diff.label
				local textColor = if hasCompleted then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 255, 255)
				panelChildren["Diff_" .. i] = React.createElement("TextButton", {
					LayoutOrder = 3 + i,
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundColor3 = if isSelected
						then Color3.fromRGB(80, 140, 230)
						else Color3.fromRGB(50, 50, 65),
					Text = buttonText,
					TextColor3 = textColor,
					TextSize = 15,
					Font = Enum.Font.GothamMedium,
					[React.Event.Activated] = function()
						setSelectedDifficulty(i)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				})
			end

			-- Personal best
			local diff = DIFFICULTIES[selectedDifficulty]
			if selectedImageId and diff then
				local bestKey = selectedImageId .. "_" .. diff.difficultyId
				local bestTime = if personalBests then personalBests[bestKey] else nil

				if bestTime then
					panelChildren["PersonalBest"] = React.createElement("TextLabel", {
						LayoutOrder = 10,
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Text = "Personal Best: " .. formatTime(bestTime),
						TextColor3 = Color3.fromRGB(255, 220, 80),
						TextSize = 15,
						Font = Enum.Font.GothamMedium,
						TextXAlignment = Enum.TextXAlignment.Center,
					})
				end
			end

			-- Start button
			panelChildren["StartButton"] = React.createElement("TextButton", {
				LayoutOrder = 11,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = Color3.fromRGB(50, 180, 80),
				Text = "Start Puzzle",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if selectedImageId and selectedImageAssetId then
						local d = DIFFICULTIES[selectedDifficulty]
						props.onStart(d.rows, d.cols, selectedImageAssetId, selectedImageId, d.difficultyId)
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			})
		else
			-- Locked image: show unlock requirements
			local unlockLevel = selectedEntry and selectedEntry.unlockLevel or 0
			local playerLevel = props.playerLevel or 1

			panelChildren["LockIcon"] = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				Text = "\u{1F512}",
				TextSize = 32,
				TextXAlignment = Enum.TextXAlignment.Center,
			})

			panelChildren["LockTitle"] = React.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = "Locked Puzzle",
				TextColor3 = Color3.fromRGB(255, 180, 80),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			})

			panelChildren["UnlockRequirement"] = React.createElement("Frame", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundColor3 = Color3.fromRGB(45, 45, 60),
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -20, 1, -10),
					BackgroundTransparency = 1,
					Text = "Reach Level " .. unlockLevel .. " to unlock this puzzle",
					TextColor3 = Color3.fromRGB(200, 200, 220),
					TextSize = 15,
					Font = Enum.Font.GothamMedium,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
			})

			panelChildren["ProgressLabel"] = React.createElement("TextLabel", {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				Text = "Your Level: " .. playerLevel .. " / " .. unlockLevel,
				TextColor3 = Color3.fromRGB(160, 160, 180),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Center,
			})

			-- Progress bar
			local progress = math.clamp(playerLevel / math.max(unlockLevel, 1), 0, 1)
			panelChildren["ProgressBar"] = React.createElement("Frame", {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Fill = React.createElement("Frame", {
					Size = UDim2.fromScale(progress, 1),
					BackgroundColor3 = Color3.fromRGB(80, 140, 230),
					BorderSizePixel = 0,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			})

			panelChildren["Hint"] = React.createElement("TextLabel", {
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				Text = "Complete puzzles to earn XP and level up!",
				TextColor3 = Color3.fromRGB(140, 140, 160),
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end

		selectionPanel = React.createElement("ScrollingFrame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.38, 1),
			BackgroundColor3 = Color3.fromRGB(35, 35, 50),
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromScale(0, 0),
		}, panelChildren)
	end

	-- === Content Area (grid + panel) ===
	local gridWidth = UDim2.fromScale(0.6, 1)

	local contentArea = React.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, if savedBanner then -110 else -50),
		Position = UDim2.new(0, 0, 0, if savedBanner then 110 else 50),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, {
		ImageGrid = React.createElement("Frame", {
			Size = gridWidth,
			BackgroundTransparency = 1,
		}, {
			Picker = React.createElement(ImagePicker, {
				selectedImageId = selectedImageId,
				onSelectImage = onSelectImage,
				unlockedImages = props.unlockedImages,
				playerLevel = props.playerLevel,
				personalBests = props.personalBests,
			}),
		}),
		SelectionPanel = selectionPanel,
	})

	-- === Assemble root ===
	local menuChildren: { [string]: any } = {}
	menuChildren["TopBar"] = topBar
	if savedBanner then
		menuChildren["SavedBanner"] = savedBanner
	end
	menuChildren["ContentArea"] = contentArea

	local rootChildren: { [string]: any } = {}
	rootChildren["Menu"] = React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0,
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

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, rootChildren)
end

return MenuScreen
