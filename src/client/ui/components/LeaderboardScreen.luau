local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

export type LeaderboardScreenProps = {
	onClose: () -> (),
}

local DIFFICULTIES = {
	{ label = "2x2", id = "2x2" },
	{ label = "6x6", id = "6x6" },
	{ label = "9x9", id = "9x9" },
	{ label = "15x15", id = "15x15" },
	{ label = "25x25", id = "25x25" },
}

local BADGE_LABELS = {
	badge_puzzle_master = "PM",
	badge_speedrunner = "SR",
	badge_collector = "CO",
	badge_champion = "CH",
}

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%05.2f", mins, secs)
end

local function LeaderboardScreen(props: LeaderboardScreenProps)
	local selectedTab, setSelectedTab = React.useState(3) -- default 4x4
	local leaderboardData, setLeaderboardData = React.useState({} :: { any })
	local isLoading, setIsLoading = React.useState(false)
	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	-- Fetch leaderboard data when tab changes
	React.useEffect(function()
		setIsLoading(true)
		setLeaderboardData({})

		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setIsLoading(false)
				return
			end
			local getLeaderboard = remotes:FindFirstChild("GetLeaderboard")
			if not getLeaderboard or not getLeaderboard:IsA("RemoteFunction") then
				setIsLoading(false)
				return
			end

			local difficultyId = DIFFICULTIES[selectedTab].id
			local ok, data = pcall(function()
				return getLeaderboard:InvokeServer(difficultyId)
			end)

			if ok and data then
				setLeaderboardData(data)
			end
			setIsLoading(false)
		end)
	end, { selectedTab } :: { any })

	-- Build tab bar
	local tabChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}

	for i, diff in DIFFICULTIES do
		local isSelected = i == selectedTab
		tabChildren["Tab_" .. i] = React.createElement("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(0, 56, 0, 32),
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(80, 140, 230)
				else Color3.fromRGB(50, 50, 60),
			Text = diff.label,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			[React.Event.Activated] = function()
				setSelectedTab(i)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
		})
	end

	-- Build leaderboard rows
	local listChildren: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
		}),
	}

	if isLoading then
		listChildren["Loading"] = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "Loading...",
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextSize = 18,
			Font = Enum.Font.Gotham,
		})
	elseif #leaderboardData == 0 then
		listChildren["Empty"] = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "No times recorded yet!",
			TextColor3 = Color3.fromRGB(150, 150, 170),
			TextSize = 18,
			Font = Enum.Font.Gotham,
		})
	else
		local playerRank = nil
		for rank, entry in leaderboardData do
			local isLocalPlayer = entry.userId == localUserId
			if isLocalPlayer then
				playerRank = rank
			end

			local bgColor = if isLocalPlayer
				then Color3.fromRGB(60, 80, 120)
				else Color3.fromRGB(35, 35, 45)

			local rankColor = Color3.fromRGB(180, 180, 200)
			if rank == 1 then rankColor = Color3.fromRGB(255, 215, 0) end
			if rank == 2 then rankColor = Color3.fromRGB(200, 200, 210) end
			if rank == 3 then rankColor = Color3.fromRGB(205, 127, 50) end

			local badgeLabel = if entry.badge and entry.badge ~= "" then BADGE_LABELS[entry.badge] or "" else ""
			local hasBadge = badgeLabel ~= ""
			local nameXOffset = if hasBadge then 76 else 44

			local rowChildren: { [string]: any } = {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
				Rank = React.createElement("TextLabel", {
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(0, 30, 1, 0),
					BackgroundTransparency = 1,
					Text = "#" .. rank,
					TextColor3 = rankColor,
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Name = React.createElement("TextLabel", {
					Position = UDim2.new(0, nameXOffset, 0, 0),
					Size = UDim2.new(1, -(nameXOffset + 86), 1, 0),
					BackgroundTransparency = 1,
					Text = entry.displayName,
					TextColor3 = Color3.fromRGB(220, 220, 230),
					TextSize = 14,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Time = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 0),
					Size = UDim2.new(0, 80, 1, 0),
					BackgroundTransparency = 1,
					Text = formatTime(entry.time),
					TextColor3 = Color3.fromRGB(80, 200, 255),
					TextSize = 14,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}

			if hasBadge then
				rowChildren["Badge"] = React.createElement("TextLabel", {
					Position = UDim2.new(0, 42, 0, 4),
					Size = UDim2.fromOffset(28, 24),
					BackgroundColor3 = Color3.fromRGB(255, 180, 50),
					Text = badgeLabel,
					TextColor3 = Color3.fromRGB(40, 20, 0),
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
				})
			end

			listChildren["Row_" .. rank] = React.createElement("Frame", {
				LayoutOrder = rank,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = bgColor,
				BackgroundTransparency = 0.3,
			}, rowChildren)
		end

		-- Player rank footer
		if playerRank then
			listChildren["YourRank"] = React.createElement("TextLabel", {
				LayoutOrder = #leaderboardData + 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Text = "Your rank: #" .. playerRank,
				TextColor3 = Color3.fromRGB(255, 220, 80),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.6),
			BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = Vector2.new(320, 400),
			}),

			-- Title bar
			TitleBar = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
		}, {
			Title = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 300, 0, 40),
				BackgroundTransparency = 1,
				Text = "Leaderboards",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 32,
				Font = Enum.Font.GothamBold,
			}),
			CloseButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				BackgroundColor3 = Color3.fromRGB(200, 60, 60),
				Text = "X",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					props.onClose()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}),

		-- Tab bar
		TabBar = React.createElement("Frame", {
			Position = UDim2.new(0, 0, 0, 50),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
		}, tabChildren),

		-- Scrolling list
		LeaderboardList = React.createElement("ScrollingFrame", {
			Position = UDim2.new(0, 16, 0, 96),
			Size = UDim2.new(1, -32, 1, -112),
			CanvasSize = UDim2.new(0, 0, 0, math.max(#leaderboardData * 34 + 40, 50)),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120),
			BackgroundColor3 = Color3.fromRGB(25, 25, 35),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}, listChildren),
		}),
	})
end

return LeaderboardScreen
