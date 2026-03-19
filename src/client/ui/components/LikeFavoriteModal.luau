local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)

export type LikeFavoriteModalProps = {
	onConfirm: () -> (),
	onClose: () -> (),
	errorMessage: string?,
	isChecking: boolean?,
}

local function LikeFavoriteModal(props: LikeFavoriteModalProps)
	local modalChildren: { [string]: any } = {}

	modalChildren["Layout"] = React.createElement("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	})
	modalChildren["Padding"] = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 20),
		PaddingBottom = UDim.new(0, 20),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	})

	modalChildren["Title"] = React.createElement("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "Like & Favorite to Unlock!",
		TextColor3 = Theme.Colors.gold,
		TextSize = Theme.TextSize.heading,
		Font = Theme.Font.heading,
	}, {
		TextStroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.black,
		}),
	})

	modalChildren["Subtitle"] = React.createElement("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Text = "Help us grow! Like \u{1F44D} and Favorite \u{2B50} the game, then tap below to claim your FREE puzzle pack!",
		TextColor3 = Theme.Colors.textSecondary,
		TextSize = Theme.TextSize.body,
		Font = Theme.Font.regular,
		TextWrapped = true,
	})

	-- Show error message if not favorited
	if props.errorMessage and props.errorMessage ~= "" then
		modalChildren["Error"] = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Text = props.errorMessage,
			TextColor3 = Theme.Colors.danger,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.bold,
			TextWrapped = true,
		})
	end

	local btnText = if props.isChecking then "Checking..." else "Claim Free Pack!"

	modalChildren["ConfirmBtn"] = React.createElement("TextButton", {
		LayoutOrder = 4,
		Size = UDim2.new(0.7, 0, 0, 48),
		BackgroundColor3 = Theme.Colors.success,
		Text = btnText,
		TextColor3 = Theme.Colors.textPrimary,
		TextSize = Theme.TextSize.large,
		Font = Theme.Font.bold,
		AutoButtonColor = not props.isChecking,
		[React.Event.Activated] = if not props.isChecking then props.onConfirm else nil,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.successLight,
		}),
	})

	modalChildren["CloseBtn"] = React.createElement("TextButton", {
		LayoutOrder = 5,
		Size = UDim2.new(0.4, 0, 0, 32),
		BackgroundColor3 = Theme.Colors.bgElevated,
		Text = "Maybe Later",
		TextColor3 = Theme.Colors.textSecondary,
		TextSize = Theme.TextSize.body,
		Font = Theme.Font.medium,
		[React.Event.Activated] = props.onClose,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.ZIndex.modal,
	}, {
		Backdrop = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = Theme.ZIndex.modal,
			[React.Event.Activated] = props.onClose,
		}),
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(420, 300),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = Theme.ZIndex.modal + 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = Theme.ZIndex.modal + 1,
			}, modalChildren),
		}),
	})
end

return LikeFavoriteModal
