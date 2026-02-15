local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

export type MenuScreenProps = {
	onStart: (rows: number, cols: number) -> (),
}

local DIFFICULTIES = {
	{ label = "Easy (3x3)", rows = 3, cols = 3 },
	{ label = "Medium (4x4)", rows = 4, cols = 4 },
	{ label = "Hard (5x5)", rows = 5, cols = 5 },
}

local function MenuScreen(props: MenuScreenProps)
	local selectedDifficulty, setSelectedDifficulty = React.useState(2) -- default Medium

	local children: { [string]: any } = {}

	children["Title"] = React.createElement("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Text = "Jigsaw Puzzle",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 48,
		Font = Enum.Font.GothamBold,
	})

	children["Spacer1"] = React.createElement("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
	})

	children["DifficultyLabel"] = React.createElement("TextLabel", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "Select Difficulty",
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextSize = 22,
		Font = Enum.Font.Gotham,
	})

	for i, diff in DIFFICULTIES do
		local isSelected = i == selectedDifficulty
		children["Diff_" .. i] = React.createElement("TextButton", {
			LayoutOrder = 3 + i,
			Size = UDim2.new(0, 220, 0, 44),
			BackgroundColor3 = if isSelected
				then Color3.fromRGB(80, 140, 230)
				else Color3.fromRGB(60, 60, 70),
			BackgroundTransparency = 0,
			Text = diff.label,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Font = Enum.Font.GothamMedium,
			[React.Event.Activated] = function()
				setSelectedDifficulty(i)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	end

	children["Spacer2"] = React.createElement("Frame", {
		LayoutOrder = 8,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
	})

	children["StartButton"] = React.createElement("TextButton", {
		LayoutOrder = 9,
		Size = UDim2.new(0, 240, 0, 56),
		BackgroundColor3 = Color3.fromRGB(50, 180, 80),
		Text = "Start Puzzle",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 26,
		Font = Enum.Font.GothamBold,
		[React.Event.Activated] = function()
			local diff = DIFFICULTIES[selectedDifficulty]
			props.onStart(diff.rows, diff.cols)
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})

	children["Layout"] = React.createElement("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0,
	}, children)
end

return MenuScreen
