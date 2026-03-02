local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)
local TitleConfig = require(Shared.TitleConfig)

export type StatsScreenProps = {
	onClose: () -> (),
	playerData: any?,
}

local DIFFICULTY_IDS = { "2x2", "6x6", "9x9", "15x15", "25x25" }

local function formatPlayTime(totalSeconds: number): string
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = math.floor(totalSeconds % 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm %ds", minutes, seconds)
	end
end

local function StatsScreen(props: StatsScreenProps)
	local playerData = props.playerData

	local totalPuzzles = if playerData then (playerData.totalPuzzlesCompleted or 0) else 0
	local totalPieces = if playerData then (playerData.totalPiecesPlaced or 0) else 0
	local totalTime = if playerData then (playerData.totalPlayTime or 0) else 0
	local byDifficulty = if playerData then (playerData.puzzlesCompletedByDifficulty or {}) else {}
	local titleName = TitleConfig.getTitleFromCompletions(byDifficulty)

	-- Build summary cards
	local summaryData = {
		{ label = "Puzzles Solved", value = tostring(totalPuzzles) },
		{ label = "Pieces Placed", value = tostring(totalPieces) },
		{ label = "Play Time", value = formatPlayTime(totalTime) },
	}

	local summaryCards: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}

	for i, stat in summaryData do
		summaryCards["Card_" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(0, 90, 0, 70),
			BackgroundColor3 = Theme.Colors.bgElevated,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Value = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.new(1, -8, 0, 28),
				BackgroundTransparency = 1,
				Text = stat.value,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
			}),
			Label = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -8, 0, 18),
				BackgroundTransparency = 1,
				Text = stat.label,
				TextColor3 = Theme.Colors.textMuted,
				TextSize = Theme.TextSize.tiny,
				Font = Theme.Font.medium,
			}),
		})
	end

	-- Build per-difficulty rows
	local diffRows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Header = React.createElement("TextLabel", {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = "Completions by Difficulty",
			TextColor3 = Theme.Colors.textSecondary,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.bold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}

	for i, diffId in DIFFICULTY_IDS do
		local count = byDifficulty[diffId] or 0
		diffRows["Diff_" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Colors.bgElevated,
			BackgroundTransparency = Theme.Transparency.hudButton,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			DiffLabel = React.createElement("TextLabel", {
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0.5, -12, 1, 0),
				BackgroundTransparency = 1,
				Text = diffId,
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CountLabel = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.new(0.5, -12, 1, 0),
				BackgroundTransparency = 1,
				Text = tostring(count) .. " completed",
				TextColor3 = if count > 0 then Theme.Colors.accentCyan else Theme.Colors.textDisabled,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.black,
		BackgroundTransparency = Theme.Transparency.overlay,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.45, 0.55),
			BackgroundColor3 = Theme.Colors.bgDeepest,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MinSize = Vector2.new(300, 380),
			}),

			-- Title bar
			TitleBar = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundTransparency = 1,
			}, {
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0, 200, 0, 40),
					BackgroundTransparency = 1,
					Text = "Stats",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.title,
					Font = Theme.Font.bold,
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.fromOffset(36, 36),
					BackgroundColor3 = Theme.Colors.dangerDark,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						props.onClose()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			-- Content
			Content = React.createElement("ScrollingFrame", {
				Position = UDim2.new(0, 16, 0, 56),
				Size = UDim2.new(1, -32, 1, -72),
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				Layout = React.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 16),
				}),

				-- Rank label
				RankLabel = React.createElement("TextLabel", {
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
					Text = "Rank: " .. titleName,
					TextColor3 = Theme.Colors.headerGold,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
				}),

				-- Summary row
				SummaryRow = React.createElement("Frame", {
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 78),
					BackgroundTransparency = 1,
				}, summaryCards),

				-- Per-difficulty breakdown
				DifficultySection = React.createElement("Frame", {
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, diffRows),
			}),
		}),
	})
end

return StatsScreen
