local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)

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

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%05.2f", mins, secs)
end

local function LeaderboardScreen(props: LeaderboardScreenProps)
	local selectedTab, setSelectedTab = React.useState(3) -- default 9x9
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
			Size = UDim2.new(0, 64, 0, 32),
			BackgroundColor3 = if isSelected
				then Theme.Colors.accentBlue
				else Theme.Colors.bgInput,
			Text = diff.label,
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = 16,
			TextScaled = true,
			Font = Theme.Font.medium,
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
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Text = "Loading...",
			TextColor3 = Theme.Colors.textMuted,
			TextSize = 18,
			TextScaled = true,
			Font = Theme.Font.regular,
		})
	elseif #leaderboardData == 0 then
		listChildren["Empty"] = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			Text = "No times recorded yet!",
			TextColor3 = Theme.Colors.textMuted,
			TextSize = 18,
			TextScaled = true,
			Font = Theme.Font.regular,
		})
	else
		local playerRank = nil
		for rank, entry in leaderboardData do
			local isLocalPlayer = entry.userId == localUserId
			if isLocalPlayer then
				playerRank = rank
			end

			local bgColor = if isLocalPlayer
				then Theme.Colors.accentBlue
				else Theme.Colors.bgCard

			local hasTitle = entry.title and entry.title ~= ""
			local nameColor = if entry.isVIP then Theme.Colors.gold else Theme.Colors.textSecondary

			-- Build left-side children using horizontal UIListLayout
			local leftChildren: { [string]: any } = {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
				}),
			}

			if hasTitle then
				leftChildren["Title"] = React.createElement("TextLabel", {
					LayoutOrder = 2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 24),
					BackgroundColor3 = Theme.Colors.headerGold,
					Text = entry.title,
					TextColor3 = Color3.fromRGB(40, 20, 0),
					TextSize = Theme.TextSize.tiny,
					TextScaled = true,
					Font = Theme.Font.bold,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Pad = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),
				})
			end

			leftChildren["Name"] = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = entry.displayName,
				TextColor3 = nameColor,
				TextSize = 16,
				TextScaled = true,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, {
				Flex = React.createElement("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			})

			local rowChildren: { [string]: any } = {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
				LeftContainer = React.createElement("Frame", {
					Size = UDim2.new(1, -88, 1, 0),
					BackgroundTransparency = 1,
				}, leftChildren),
				Time = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 0),
					Size = UDim2.new(0, 80, 1, 0),
					BackgroundTransparency = 1,
					Text = formatTime(entry.time),
					TextColor3 = Theme.Colors.accentCyan,
					TextSize = 16,
					TextScaled = true,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}

			listChildren["Row_" .. rank] = React.createElement("Frame", {
				LayoutOrder = rank,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = bgColor,
				BackgroundTransparency = Theme.Transparency.hudButton,
			}, rowChildren)
		end

		-- Player rank footer
		if playerRank then
			listChildren["YourRank"] = React.createElement("TextLabel", {
				LayoutOrder = #leaderboardData + 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "Your rank: #" .. playerRank,
				TextColor3 = Theme.Colors.warning,
				TextSize = 16,
				TextScaled = true,
				Font = Theme.Font.bold,
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),
			BackgroundColor3 = Theme.Colors.bgDeepest,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1.15,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(math.huge, 550),
			}),

			-- Title bar
			TitleBar = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
			}, {
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0.6, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = "Leaderboards",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = 24,
					TextScaled = true,
					Font = Theme.Font.bold,
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(30, 30),
					BackgroundColor3 = Theme.Colors.dangerDark,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = 16,
					TextScaled = true,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						props.onClose()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			-- Tab bar
			TabBar = React.createElement("Frame", {
				Position = UDim2.new(0, 0, 0, 40),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, tabChildren),

			-- Scrolling list
			LeaderboardList = React.createElement("ScrollingFrame", {
				Position = UDim2.new(0, 0, 0, 78),
				Size = UDim2.new(1, 0, 1, -78),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				BackgroundColor3 = Theme.Colors.bgDark,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
			}, listChildren),
		}),
	})
end

return LeaderboardScreen
