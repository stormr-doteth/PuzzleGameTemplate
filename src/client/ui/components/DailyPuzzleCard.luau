local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)
local DailyPuzzleConfig = require(Shared.DailyPuzzleConfig)

export type DailyPuzzleCardProps = {
	dailyPuzzle: {
		imageId: string,
		imageAssetId: string,
		imageName: string,
		thumbnailId: string,
		difficultyId: string,
		rows: number,
		cols: number,
		dateString: string,
	}?,
	completed: boolean,
	onStart: (rows: number, cols: number, imageAssetId: string, imageId: string, difficultyId: string) -> (),
}

local function DailyPuzzleCard(props: DailyPuzzleCardProps)
	local puzzle = props.dailyPuzzle
	if not puzzle then
		return nil
	end

	local isCompleted = props.completed

	return React.createElement("TextButton", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundColor3 = Theme.Colors.bgCard,
		Text = "",
		AutoButtonColor = not isCompleted,
		[React.Event.Activated] = function()
			if not isCompleted then
				props.onStart(puzzle.rows, puzzle.cols, puzzle.imageAssetId, puzzle.imageId, puzzle.difficultyId)
			end
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.md }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.gold,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),

		-- Thumbnail
		Thumbnail = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Theme.Colors.bgElevated,
			Image = puzzle.thumbnailId,
			ScaleType = Enum.ScaleType.Crop,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		}),

		-- Info section
		Info = React.createElement("Frame", {
			Position = UDim2.fromOffset(76, 0),
			Size = UDim2.new(1, -140, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			Title = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Daily Puzzle",
				TextColor3 = Theme.Colors.gold,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Name = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = puzzle.imageName .. " (" .. puzzle.difficultyId .. ")",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Bonus = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = "BONUS: +$" .. DailyPuzzleConfig.BONUS_CASH,
				TextColor3 = Theme.Colors.cashGreen,
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),

		-- Status badge (right side)
		Status = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(56, 56),
			BackgroundTransparency = 1,
		}, {
			StatusLabel = React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = if isCompleted then "\u{2705}" else "\u{27A1}",
				TextSize = 28,
				TextScaled = true,
			}),
		}),
	})
end

return DailyPuzzleCard
