local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local ProgressionConfig = require(Shared.ProgressionConfig)

export type XPBarProps = {
	level: number,
	xp: number,
	cash: number,
}

local function XPBar(props: XPBarProps)
	local progressXP, neededXP = ProgressionConfig.getLevelProgress(props.xp)
	local fillFraction = if neededXP > 0 then math.clamp(progressXP / neededXP, 0, 1) else 0

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(0.5, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 0.2,
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

		-- Level label (left)
		LevelLabel = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0.15, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "Lv." .. props.level,
			TextColor3 = Color3.fromRGB(255, 220, 80),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 201,
		}, {
			TextConstraint = React.createElement("UITextSizeConstraint", { MaxTextSize = 16 }),
		}),

		-- XP Bar (center)
		BarBackground = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0, 12),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			ZIndex = 201,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Fill = React.createElement("Frame", {
				Size = UDim2.new(fillFraction, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(80, 200, 255),
				ZIndex = 202,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			XPText = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = progressXP .. "/" .. neededXP .. " XP",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 10,
				Font = Enum.Font.GothamMedium,
				ZIndex = 203,
			}),
		}),

		-- Cash label (right)
		CashLabel = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "$" .. props.cash,
			TextColor3 = Color3.fromRGB(120, 255, 120),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 201,
		}, {
			TextConstraint = React.createElement("UITextSizeConstraint", { MaxTextSize = 16 }),
		}),
	})
end

return XPBar
