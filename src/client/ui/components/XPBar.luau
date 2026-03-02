local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)

export type XPBarProps = {
	cash: number,
}

local function XPBar(props: XPBarProps)
	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(0.5, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.bgHud,
		BackgroundTransparency = Theme.Transparency.subtle,
		ZIndex = 200,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(400, 36),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),

		-- Cash label (centered)
		CashLabel = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "$" .. props.cash,
			TextColor3 = Theme.Colors.cashGreen,
			TextScaled = true,
			Font = Theme.Font.bold,
			ZIndex = 201,
		}, {
			TextConstraint = React.createElement("UITextSizeConstraint", { MaxTextSize = 16 }),
		}),
	})
end

return XPBar
