local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)
local ImagePicker = require(script.Parent.ImagePicker)

local DIFFICULTIES = {
	{ label = "Beginner (2x2)", rows = 2, cols = 2, difficultyId = "2x2" },
	{ label = "Easy (6x6)", rows = 6, cols = 6, difficultyId = "6x6" },
	{ label = "Medium (9x9)", rows = 9, cols = 9, difficultyId = "9x9" },
	{ label = "Hard (15x15)", rows = 15, cols = 15, difficultyId = "15x15" },
	{ label = "Expert (25x25)", rows = 25, cols = 25, difficultyId = "25x25" },
}

export type RoomLobbyScreenProps = {
	roomInfo: any,
	isHost: boolean,
	onLeave: () -> (),
	onConfigure: (config: any) -> (),
	onStart: () -> (),
	unlockedImages: { [string]: boolean }?,
	playerLevel: number?,
}

local PLAYER_COLORS = {
	Color3.fromRGB(80, 180, 230),
	Color3.fromRGB(230, 140, 80),
	Color3.fromRGB(80, 230, 140),
	Color3.fromRGB(230, 80, 180),
}

local function RoomLobbyScreen(props: RoomLobbyScreenProps)
	local roomInfo = props.roomInfo
	local selectedDifficulty, setSelectedDifficulty = React.useState(2) -- default Easy
	local selectedImageId, setSelectedImageId = React.useState(nil :: string?)
	local selectedImageAssetId, setSelectedImageAssetId = React.useState(nil :: string?)

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

	-- Player list
	local playerListChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}

	local players = roomInfo and roomInfo.players or {}
	for i, p in players do
		local color = PLAYER_COLORS[((i - 1) % #PLAYER_COLORS) + 1]
		local nameText = p.displayName
		if p.isHost then
			nameText = nameText .. " (Host)"
		end
		if p.userId == localUserId then
			nameText = nameText .. " (You)"
		end

		playerListChildren["Player_" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(35, 35, 50),
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			ColorBar = React.createElement("Frame", {
				Size = UDim2.new(0, 4, 1, -8),
				Position = UDim2.new(0, 6, 0, 4),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
			}),
			Name = React.createElement("TextLabel", {
				Position = UDim2.new(0, 18, 0, 0),
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = nameText,
				TextColor3 = Color3.fromRGB(220, 220, 240),
				TextSize = 15,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end

	-- Empty slots
	for i = #players + 1, 4 do
		playerListChildren["Empty_" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(25, 25, 35),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Label = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -20, 1, 0),
				BackgroundTransparency = 1,
				Text = "Waiting for player...",
				TextColor3 = Color3.fromRGB(80, 80, 100),
				TextSize = 13,
				Font = Enum.Font.Gotham,
			}),
		})
	end

	-- Config display for non-host
	local configDisplay = nil
	local currentConfig = roomInfo and roomInfo.config
	if not props.isHost and currentConfig then
		local imageEntry = ImageCatalog.getById(currentConfig.imageId)
		local imageName = if imageEntry then imageEntry.name else currentConfig.imageId
		configDisplay = React.createElement("Frame", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = Color3.fromRGB(35, 35, 50),
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
			}),
			ImageLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Image: " .. imageName,
				TextColor3 = Color3.fromRGB(200, 200, 220),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			DiffLabel = React.createElement("TextLabel", {
				Position = UDim2.new(0, 0, 0, 22),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Difficulty: " .. currentConfig.difficultyId,
				TextColor3 = Color3.fromRGB(200, 200, 220),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	elseif not props.isHost and not currentConfig then
		configDisplay = React.createElement("TextLabel", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "Waiting for host to select a puzzle...",
			TextColor3 = Color3.fromRGB(120, 120, 150),
			TextSize = 15,
			Font = Enum.Font.Gotham,
		})
	end

	-- Left panel: room info + players
	local leftPanel = React.createElement("Frame", {
		Size = UDim2.fromScale(0.35, 1),
		BackgroundTransparency = 1,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, 20),
			PaddingBottom = UDim.new(0, 20),
		}),
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),

		RoomTitle = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Text = "Room Lobby",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 28,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		RoomCodeFrame = React.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundColor3 = Color3.fromRGB(35, 35, 50),
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Label = React.createElement("TextLabel", {
				Position = UDim2.new(0, 12, 0, 4),
				Size = UDim2.new(1, -24, 0, 16),
				BackgroundTransparency = 1,
				Text = "ROOM CODE",
				TextColor3 = Color3.fromRGB(120, 120, 150),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Code = React.createElement("TextLabel", {
				Position = UDim2.new(0, 12, 0, 20),
				Size = UDim2.new(1, -24, 0, 28),
				BackgroundTransparency = 1,
				Text = if roomInfo then roomInfo.roomId else "------",
				TextColor3 = Color3.fromRGB(80, 200, 255),
				TextSize = 24,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		PlayersLabel = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "Players (" .. #players .. "/4)",
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		PlayerList = React.createElement("Frame", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 4 * 42),
			BackgroundTransparency = 1,
		}, playerListChildren),

		ConfigDisplay = configDisplay,

		-- Buttons
		StartButton = if props.isHost
			then React.createElement("TextButton", {
				LayoutOrder = 10,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = if currentConfig
					then Color3.fromRGB(50, 180, 80)
					else Color3.fromRGB(60, 60, 80),
				Text = "Start Puzzle",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					if currentConfig then
						props.onStart()
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			})
			else nil,

		LeaveButton = React.createElement("TextButton", {
			LayoutOrder = 11,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(140, 50, 50),
			Text = "Leave Room",
			TextColor3 = Color3.fromRGB(255, 220, 220),
			TextSize = 16,
			Font = Enum.Font.GothamMedium,
			[React.Event.Activated] = function()
				props.onLeave()
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),
	})

	-- Right panel: host sees image picker + difficulty, non-host sees nothing extra
	local rightPanel = nil
	if props.isHost then
		local diffButtons: { [string]: any } = {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}
		for i, diff in DIFFICULTIES do
			local isSelected = i == selectedDifficulty
			diffButtons["Diff_" .. i] = React.createElement("TextButton", {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = if isSelected
					then Color3.fromRGB(80, 140, 230)
					else Color3.fromRGB(50, 50, 65),
				Text = diff.label,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				[React.Event.Activated] = function()
					onSelectDifficulty(i)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			})
		end

		rightPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.65, 1),
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
			}),
			PickerLabel = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "Select Image",
				TextColor3 = Color3.fromRGB(180, 180, 200),
				TextSize = 16,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			ImagePickerFrame = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0.5, 0),
				BackgroundTransparency = 1,
			}, {
				Picker = React.createElement(ImagePicker, {
					selectedImageId = selectedImageId,
					onSelectImage = onSelectImage,
					unlockedImages = props.unlockedImages,
					playerLevel = props.playerLevel,
				}),
			}),
			DiffLabel = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "Select Difficulty",
				TextColor3 = Color3.fromRGB(180, 180, 200),
				TextSize = 16,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			DiffButtons = React.createElement("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(0.5, 0, 0, #DIFFICULTIES * 38),
				BackgroundTransparency = 1,
			}, diffButtons),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	}, {
		LeftPanel = leftPanel,
		RightPanel = rightPanel,
	})
end

return RoomLobbyScreen
