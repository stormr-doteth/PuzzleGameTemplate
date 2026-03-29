local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ImageCatalog = require(Shared.ImageCatalog)
local Theme = require(Shared.Theme)

export type ResumePromptModalProps = {
	savedPuzzles: { any },
	onResume: (slotIndex: number) -> (),
	onNewPuzzle: () -> (),
}

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function ResumePromptModal(props: ResumePromptModalProps)
	local savedPuzzles = props.savedPuzzles
	if not savedPuzzles or #savedPuzzles == 0 then return nil end

	-- Show the most recent save (first in list)
	local save = savedPuzzles[1]
	local imageEntry = ImageCatalog.getById(save.imageId)
	local imageName = if imageEntry then imageEntry.name else "Puzzle"
	local thumbnailId = if imageEntry then imageEntry.thumbnailId else save.imageAssetId

	local children = {}

	children["Corner"] = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) })
	children["Stroke"] = React.createElement("UIStroke", {
		Color = Theme.Colors.border,
		Thickness = 1.5,
	})
	children["Padding"] = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	})
	children["Layout"] = React.createElement("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
	})

	-- Title
	children["Title"] = React.createElement("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "Continue Puzzle?",
		TextColor3 = Theme.Colors.textPrimary,
		TextSize = Theme.TextSize.heading,
		Font = Theme.Font.heading,
		ZIndex = 2,
	})

	-- Puzzle info row
	children["InfoRow"] = React.createElement("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Colors.bgDark,
		ZIndex = 2,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Thumbnail = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Image = thumbnailId,
			BackgroundColor3 = Theme.Colors.bgElevated,
			ZIndex = 2,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
		}),
		Details = React.createElement("Frame", {
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.new(0, 60, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),
			Name = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = imageName,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
			}),
			Info = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = save.difficultyId .. "  \u{00B7}  " .. formatTime(save.elapsedSeconds),
				TextColor3 = Theme.Colors.textMuted,
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
		}),
	})

	-- Multiple saves note
	if #savedPuzzles > 1 then
		children["SavesNote"] = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = #savedPuzzles .. " saved puzzles total",
			TextColor3 = Theme.Colors.textMuted,
			TextSize = Theme.TextSize.tiny,
			Font = Theme.Font.regular,
			ZIndex = 2,
		})
	end

	-- Continue button
	children["ContinueBtn"] = React.createElement("TextButton", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Colors.accentBlue,
		Text = "Continue",
		TextColor3 = Theme.Colors.textPrimary,
		TextSize = Theme.TextSize.button,
		Font = Theme.Font.bold,
		ZIndex = 2,
		[React.Event.Activated] = function()
			props.onResume(1)
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})

	-- New Puzzle button
	children["NewPuzzleBtn"] = React.createElement("TextButton", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.bgElevated,
		Text = "New Puzzle",
		TextColor3 = Theme.Colors.textSecondary,
		TextSize = Theme.TextSize.body,
		Font = Theme.Font.medium,
		ZIndex = 2,
		[React.Event.Activated] = function()
			props.onNewPuzzle()
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, {
		Backdrop = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = 50,
			[React.Event.Activated] = function()
				props.onNewPuzzle()
			end,
		}),
		Card = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, if #savedPuzzles > 1 then 280 else 260),
			BackgroundColor3 = Theme.Colors.bgCard,
			ZIndex = 51,
		}, children),
	})
end

return ResumePromptModal
